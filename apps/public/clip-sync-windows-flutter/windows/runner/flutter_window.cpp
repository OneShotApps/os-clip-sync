#include "flutter_window.h"

#include <filesystem>
#include <fstream>
#include <iterator>
#include <optional>
#include <string>
#include <vector>

#include <winrt/Windows.Storage.h>

#include "flutter/generated_plugin_registrant.h"

namespace {

std::vector<uint8_t> ReadBytes(const std::filesystem::path& path) {
  std::ifstream input(path, std::ios::binary);
  return std::vector<uint8_t>(std::istreambuf_iterator<char>(input), {});
}

std::string ReadText(const std::filesystem::path& path) {
  const auto bytes = ReadBytes(path);
  return std::string(bytes.begin(), bytes.end());
}

std::optional<flutter::EncodableMap> TakePendingShare() {
  try {
    const auto local_folder =
        winrt::Windows::Storage::ApplicationData::Current().LocalFolder().Path();
    const std::filesystem::path folder(local_folder.c_str());
    const auto kind_path = folder / L"pending-kind.txt";
    if (!std::filesystem::exists(kind_path)) {
      return std::nullopt;
    }

    const auto kind = ReadText(kind_path);
    flutter::EncodableMap values;
    if (kind == "text") {
      const auto text_path = folder / L"pending-text.txt";
      if (!std::filesystem::exists(text_path)) {
        return std::nullopt;
      }
      values[flutter::EncodableValue("text")] =
          flutter::EncodableValue(ReadText(text_path));
      std::filesystem::remove(text_path);
    } else if (kind == "image") {
      const auto image_path = folder / L"pending-image.bin";
      const auto mime_path = folder / L"pending-image-mime.txt";
      if (!std::filesystem::exists(image_path) ||
          !std::filesystem::exists(mime_path)) {
        return std::nullopt;
      }
      values[flutter::EncodableValue("imageBytes")] =
          flutter::EncodableValue(ReadBytes(image_path));
      values[flutter::EncodableValue("mimeType")] =
          flutter::EncodableValue(ReadText(mime_path));
      std::filesystem::remove(image_path);
      std::filesystem::remove(mime_path);
    } else {
      return std::nullopt;
    }
    std::filesystem::remove(kind_path);
    return values;
  } catch (const winrt::hresult_error&) {
    // Unpackaged debug runs do not have an ApplicationData package folder.
    return std::nullopt;
  }
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  share_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "app.oneshot.clipsync/share",
          &flutter::StandardMethodCodec::GetInstance());
  share_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() != "takePending") {
          result->NotImplemented();
          return;
        }
        const auto pending = TakePendingShare();
        if (!pending) {
          result->Success();
          return;
        }
        result->Success(flutter::EncodableValue(*pending));
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    share_channel_.reset();
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
