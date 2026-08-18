import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    let shareChannel = FlutterMethodChannel(
      name: "app.oneshot.clipsync/share",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    if let appDelegate = NSApp.delegate as? AppDelegate {
      appDelegate.setShareChannel(shareChannel)
      shareChannel.setMethodCallHandler { call, result in
        if call.method == "takePending" {
          result(appDelegate.takePendingShare())
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    super.awakeFromNib()
  }
}
