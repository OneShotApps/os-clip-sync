import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var shareChannel: FlutterMethodChannel?
  private var pendingShare: [String: Any]?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    NSApp.servicesProvider = self
    NSUpdateDynamicServices()
  }

  func setShareChannel(_ channel: FlutterMethodChannel) {
    shareChannel = channel
  }

  func takePendingShare() -> [String: Any]? {
    defer { pendingShare = nil }
    return pendingShare
  }

  private func deliver(_ values: [String: Any]) {
    if let shareChannel {
      shareChannel.invokeMethod("received", arguments: values)
    } else {
      pendingShare = values
    }
    NSApp.activate(ignoringOtherApps: true)
    NSApp.windows.first?.makeKeyAndOrderFront(nil)
  }

  private func pngData(from pasteboard: NSPasteboard) -> Data? {
    if let png = pasteboard.data(forType: .png) {
      return png
    }
    if let tiff = pasteboard.data(forType: .tiff),
       let representation = NSBitmapImageRep(data: tiff) {
      return representation.representation(using: .png, properties: [:])
    }
    if let fileUrl = pasteboard.string(forType: .fileURL),
       let url = URL(string: fileUrl),
       let image = NSImage(contentsOf: url),
       let tiff = image.tiffRepresentation,
       let representation = NSBitmapImageRep(data: tiff) {
      return representation.representation(using: .png, properties: [:])
    }
    return nil
  }

  /// macOS Services entry point for text and photos explicitly shared to Clip Sync.
  @objc func shareToClipSync(
    _ pasteboard: NSPasteboard,
    userData: String?,
    error: AutoreleasingUnsafeMutablePointer<NSString?>
  ) {
    if let text = pasteboard.string(forType: .string), !text.isEmpty {
      deliver(["text": text])
      return
    }
    if let imageData = pngData(from: pasteboard) {
      deliver([
        "imageBytes": FlutterStandardTypedData(bytes: imageData),
        "mimeType": "image/png",
      ])
      return
    }
    error.pointee = "Clip Sync accepts shared text, PNG, JPEG, and WebP photos."
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
