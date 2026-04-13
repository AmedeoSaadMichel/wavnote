// File: ios/Runner/SwiftLogPlugin.swift
// Plugin che espone i log di swift-log a Flutter via FlutterEventChannel.
// Flusso: swift-log Logger → FlutterLogHandler → EventChannel → Dart Stream

import Flutter
import Foundation
// NOTA: importa il modulo swift-log dopo averlo aggiunto via SPM in Xcode:
//   File → Add Package Dependencies → https://github.com/apple/swift-log
import Logging

// MARK: - FlutterLogHandler

/// LogHandler di swift-log che invia ogni log all'EventSink di Flutter.
/// Thread-safe: l'invio avviene sempre sul main thread per rispettare
/// il contratto di FlutterEventChannel.
struct FlutterLogHandler: LogHandler {

    // LogHandler richiede questa proprietà mutabile.
    var logLevel: Logger.Level = .trace
    var metadata: Logger.Metadata = [:]

    private let label: String
    /// Closure fornita da EventChannel quando Flutter inizia ad ascoltare.
    /// È nil finché nessun listener Dart è attivo.
    private weak var plugin: SwiftLogPlugin?

    init(label: String, plugin: SwiftLogPlugin) {
        self.label = label
        self.plugin = plugin
    }

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        var payload: [String: Any] = [
            "level":    level.rawValue,
            "message":  "\(message)",
            "label":    label,
            "source":   source,
            "file":     (file as NSString).lastPathComponent,
            "function": function,
            "line":     line,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
        ]
        if let meta = metadata, !meta.isEmpty {
            payload["metadata"] = meta.mapValues { "\($0)" }
        }
        // Invia sempre sul main thread — requisito di FlutterEventChannel.
        DispatchQueue.main.async { [plugin, payload] in
            plugin?.send(payload)
        }
    }
}

// MARK: - SwiftLogPlugin

/// Plugin Flutter che:
///  1. Registra un EventChannel (`com.wavnote/swift_logs`).
///  2. Bootstrappa LoggingSystem con FlutterLogHandler.
///  3. Propaga ogni log a Flutter finché il listener Dart è attivo.
public class SwiftLogPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    static let channelName = "com.wavnote/swift_logs"

    /// EventSink attivo (non-nil solo mentre Flutter ascolta lo stream).
    private var eventSink: FlutterEventSink?
    /// Coda thread-safe per accesso all'eventSink.
    private let sinkLock = NSLock()
    /// Impedisce di fare il bootstrap più di una volta.
    private static var bootstrapped = false

    // MARK: FlutterPlugin

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterEventChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        let instance = SwiftLogPlugin()
        channel.setStreamHandler(instance)
        // Bootstrap una sola volta nell'intero ciclo di vita dell'app.
        if !bootstrapped {
            bootstrapped = true
            LoggingSystem.bootstrap { label in
                FlutterLogHandler(label: label, plugin: instance)
            }
        }
    }

    // MARK: FlutterStreamHandler

    /// Flutter ha iniziato ad ascoltare: salva il sink.
    public func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        sinkLock.lock()
        eventSink = events
        sinkLock.unlock()
        // Log di conferma visibile immediatamente nel Dart stream.
        let welcome: [String: Any] = [
            "level": "info",
            "message": "SwiftLogPlugin: EventChannel attivo, log stream avviato.",
            "label": "SwiftLogPlugin",
            "source": "SwiftLogPlugin",
            "file": "SwiftLogPlugin.swift",
            "function": "onListen",
            "line": 0,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
        ]
        events(welcome)
        return nil
    }

    /// Flutter ha smesso di ascoltare: azzera il sink.
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sinkLock.lock()
        eventSink = nil
        sinkLock.unlock()
        return nil
    }

    // MARK: Internal

    /// Inviato da FlutterLogHandler — già sul main thread.
    func send(_ payload: [String: Any]) {
        sinkLock.lock()
        let sink = eventSink
        sinkLock.unlock()
        sink?(payload)
    }
}
