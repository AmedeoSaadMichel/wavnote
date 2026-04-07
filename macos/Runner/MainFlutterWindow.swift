import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Registra i plugin nativi audio
    let trimmerRegistrar = flutterViewController.registrar(forPlugin: "AudioTrimmerPlugin")
    AudioTrimmerPlugin.register(with: trimmerRegistrar)

    let engineRegistrar = flutterViewController.registrar(forPlugin: "AudioEnginePlugin")
    AudioEnginePlugin.register(with: engineRegistrar)

    super.awakeFromNib()
  }
}
