// File: ios/Runner/SwiftLogPlugin.swift
// Plugin che espone i log di swift-log a Flutter via FlutterEventChannel.
// Flusso: swift-log Logger → FlutterLogHandler → EventChannel → Dart Stream
//
// NON usa il protocollo FlutterPlugin / registrar(forPlugin:) perché il registrar
// creato da AppDelegate usa un messenger secondario che non coincide con quello
// del FlutterViewController principale. Si usa invece setup(messenger:) con il
// binaryMessenger diretto del controller — l'unico messenger sicuro.

import Flutter
import Foundation
import Logging

// MARK: - FlutterLogHandler

/// LogHandler di swift-log che invia ogni log all'EventSink di Flutter.
/// Thread-safe: l'invio avviene sempre sul main thread per rispettare
/// il contratto di FlutterEventChannel.
struct FlutterLogHandler: LogHandler {

    var logLevel: Logger.Level = .trace
    var metadata: Logger.Metadata = [:]

    private let label: String
    // Riferimento debole: il plugin è già trattenuto staticamente in SwiftLogPlugin.
    private weak var plugin: SwiftLogPlugin?

    init(label: String, plugin: SwiftLogPlugin) {
        self.label = label
        self.plugin = plugin
    }

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    func log(event: Logging.LogEvent) {
        var payload: [String: Any] = [
            "level":     event.level.rawValue,
            "message":   "\(event.message)",
            "label":     label,
            "source":    event.source,
            "file":      (event.file as NSString).lastPathComponent,
            "function":  event.function,
            "line":      event.line,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
        ]
        if let meta = event.metadata, !meta.isEmpty {
            payload["metadata"] = meta.mapValues { "\($0)" }
        }
        DispatchQueue.main.async { [plugin, payload] in
            plugin?.send(payload)
        }
    }
}

// MARK: - SwiftLogPlugin

public class SwiftLogPlugin: NSObject, FlutterStreamHandler {

    static let channelName = "com.wavnote/swift_logs"

    // Riferimenti statici: mantengono vivi istanza e canale per tutta la vita dell'app.
    private static var _instance: SwiftLogPlugin?
    private static var _channel: FlutterEventChannel?
    private static var _bootstrapped = false

    private var eventSink: FlutterEventSink?
    private let sinkLock = NSLock()

    // MARK: - Setup

    /// Da chiamare in AppDelegate con il binaryMessenger del FlutterViewController.
    /// Idempotente: chiamate successive vengono ignorate.
    public static func setup(messenger: FlutterBinaryMessenger) {
        guard _instance == nil else { return }

        let instance = SwiftLogPlugin()
        _instance = instance

        let channel = FlutterEventChannel(name: channelName, binaryMessenger: messenger)
        _channel = channel
        channel.setStreamHandler(instance)

        if !_bootstrapped {
            _bootstrapped = true
            LoggingSystem.bootstrap { label in
                FlutterLogHandler(label: label, plugin: instance)
            }
        }
    }

    // MARK: - FlutterStreamHandler

    public func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        sinkLock.lock()
        eventSink = events
        sinkLock.unlock()

        let welcome: [String: Any] = [
            "level":     "info",
            "message":   "SwiftLogPlugin: EventChannel attivo.",
            "label":     "SwiftLogPlugin",
            "source":    "SwiftLogPlugin",
            "file":      "SwiftLogPlugin.swift",
            "function":  "onListen",
            "line":      0,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
        ]
        events(welcome)
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sinkLock.lock()
        eventSink = nil
        sinkLock.unlock()
        return nil
    }

    // MARK: - Internal

    func send(_ payload: [String: Any]) {
        sinkLock.lock()
        let sink = eventSink
        sinkLock.unlock()
        sink?(payload)
    }
}
