// File: ios/Runner/AppDelegate.swift
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Registra il plugin audio trimmer
    if let registrar = self.registrar(forPlugin: "AudioTrimmerPlugin") {
      AudioTrimmerPlugin.register(with: registrar)
    }

    // Registra il plugin audio engine (AVAudioEngine nativo)
    if let registrar = self.registrar(forPlugin: "AudioEnginePlugin") {
      AudioEnginePlugin.register(with: registrar)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
