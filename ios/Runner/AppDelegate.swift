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

    // super.application crea il FlutterViewController e avvia il motore Flutter.
    // Deve essere chiamato PRIMA di accedere a window.rootViewController.
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    // A questo punto window.rootViewController è il FlutterViewController.
    // Usiamo il suo binaryMessenger — l'unico che corrisponde al canale Dart.
    if let controller = window?.rootViewController as? FlutterViewController {
      SwiftLogPlugin.setup(messenger: controller.binaryMessenger)
    }

    return result
  }
}
