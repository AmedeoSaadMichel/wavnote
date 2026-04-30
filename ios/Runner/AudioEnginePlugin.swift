// File: ios/Runner/AudioEnginePlugin.swift
// AVAudioEngine recorder con playback simultaneo, interruption handling,
// validazione formato, voice processing e session configurabile.

import Flutter
import AVFoundation
import Logging
import UIKit

// Event Channel per notificare Dart del completamento del playback
class PlaybackStreamHandler: NSObject, FlutterStreamHandler {
    var eventSink: FlutterEventSink?
    let logger = Logger(label: "com.wavnote.audio_engine.stream_handler")

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    func sendPlaybackComplete() {
        logger.info("🔊 [NATIVE] -> Flutter: sendPlaybackComplete")
        eventSink?(["event": "playbackCompleted"])
    }
}

// Event Channel per i tick di clock (recording + playback position)
class ClockStreamHandler: NSObject, FlutterStreamHandler {
    var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    /// Emette un tick di durata registrazione (da installTap, throttled a 100ms).
    func sendRecordingTick(positionMs: Int, amplitude: Double) {
        eventSink?(["type": "recordingTick", "positionMs": positionMs, "amplitude": amplitude])
    }

    /// Emette un tick di posizione playback (da DispatchSourceTimer, 100ms).
    func sendPlaybackTick(positionMs: Int, durationMs: Int) {
        eventSink?(["type": "playbackTick", "positionMs": positionMs, "durationMs": durationMs])
    }

    /// Inoltra a Flutter i comandi provenienti dalla Live Activity interattiva.
    func sendLiveActivityControl(action: String) {
        eventSink?(["type": "liveActivityControl", "action": action])
    }
}

// Estensione per aggiungere un logger condiviso
extension AudioEnginePlugin {
    static var sharedLogger: Logger = {
        var logger = Logger(label: "com.wavnote.audio_engine_static")
        return logger
    }()

    var logger: Logger {
        return AudioEnginePlugin.sharedLogger
    }
}


public class AudioEnginePlugin: NSObject, FlutterPlugin {
    static var activeInstance: AudioEnginePlugin?
    
    let playbackStreamHandler = PlaybackStreamHandler()
    let clockStreamHandler = ClockStreamHandler()

    // MARK: - Clock state (recording)
    /// Frame scritti nei segmenti già chiusi (accumulati attraverso pause/resume).
    var framesInPreviousSegments: Int64 = 0
    /// Frame scritti nel segmento corrente (resettato a ogni nuovo file).
    var framesWrittenThisSegment: Int64 = 0
    /// Sample rate del file WAV di output (impostato a startRecording).
    var outputSampleRate: Double = 44100
    /// Timestamp dell'ultimo tick di clock emesso (CACurrentMediaTime). Throttle a 100ms.
    var lastClockEmitTime: CFTimeInterval = 0
    /// Timestamp ultimo update Live Activity. Throttle separato per non inviare update troppo frequenti ad ActivityKit.
    var lastLiveActivityUpdateTime: CFTimeInterval = 0
    /// Offset visuale solo per Live Activity, usato da overdub/seek-and-resume.
    /// Non entra nel conteggio dei frame salvati sul file.
    var liveActivityElapsedOffsetMs: Int = 0

    // MARK: - Clock state (playback)
    /// Timer nativo che emette playback tick ogni 100ms.
    var playbackClockTimer: DispatchSourceTimer?
    var lastReportedFrames: Int64 = 0
    var stalledTicks: Int = 0

    var audioEngine: AVAudioEngine?
    var inputNode: AVAudioInputNode?
    var audioFile: AVAudioFile?
    var playbackEngine: AVAudioEngine?
    var audioPlayer: AVAudioPlayerNode?
    var audioFileForPlayback: AVAudioFile?

    var isRecording = false
    var isPaused = false
    var isPlaying = false
    var isPlaybackPaused = false
    /// Flag impostata dal callback nativo quando l'audio fisicamente finisce.
    /// Solo il timer può leggere questa flag e gestire il completamento.
    var playbackFinished = false
    /// Incrementato ad ogni nuova sessione di playback (startPlayback o seekTo).
    /// I completion handler confrontano la propria generazione con quella corrente:
    /// se diversa, il handler è orfano (da un vecchio segmento) e va ignorato.
    var playbackGeneration: Int = 0

    var recordingFilePath: String?
    var recordingSettings: [String: Any]?
    /// Segmenti finalizzati (sempre WAV internamente).
    var recordingSegments: [String] = []
    /// Formato interno di registrazione (sempre "wav" — Approccio 1).
    var recordingFormat: String = "wav"
    /// Formato finale richiesto dall'utente: "m4a" | "wav" | "flac"
    var requestedFormat: String = "m4a"
    /// Path finale con l'estensione del formato richiesto dall'utente.
    var requestedOutputPath: String?
    /// Settings per il formato finale (M4A/FLAC) — usati solo alla conversione.
    var requestedFormatSettings: [String: Any]?
    var playbackTempPath: String?
    var currentAmplitude: Float = 0.0
    /// Frame di inizio del segmento schedulato (usato per calcolare la posizione di playback corretta dopo seekTo).
    var seekOffsetFrames: Int64 = 0

    /// Categoria e opzioni audio session configurabili da Flutter.
    var sessionCategory: AVAudioSession.Category = .playAndRecord
    var sessionOptions: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .allowBluetooth]
    /// Voice processing (echo cancellation + noise suppression).
    var voiceProcessingEnabled = false
    /// Sample rate massimo supportato.
    static let maxSampleRate = 48000

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.wavnote/audio_engine",
            binaryMessenger: registrar.messenger()
        )
        let instance = AudioEnginePlugin()
        AudioEnginePlugin.activeInstance = instance
        registrar.addMethodCallDelegate(instance, channel: channel)

        let playbackEventChannel = FlutterEventChannel(
            name: "com.wavnote/audio_engine/playback_events",
            binaryMessenger: registrar.messenger()
        )
        playbackEventChannel.setStreamHandler(instance.playbackStreamHandler)

        let clockEventChannel = FlutterEventChannel(
            name: "com.wavnote/audio_engine/clock_events",
            binaryMessenger: registrar.messenger()
        )
        clockEventChannel.setStreamHandler(instance.clockStreamHandler)
    }

    func sendLiveActivityControl(action: String) {
        clockStreamHandler.sendLiveActivityControl(action: action)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            initialize(result: result)
        case "startRecording":
            if let args = call.arguments as? [String: Any],
               let path = args["path"] as? String,
               let sampleRate = args["sampleRate"] as? Int,
               let bitRate = args["bitRate"] as? Int {
                let format = args["format"] as? String ?? "m4a"
                let initialElapsedMs = args["initialElapsedMs"] as? Int ?? 0
                startRecording(
                    path: path,
                    sampleRate: sampleRate,
                    bitRate: bitRate,
                    format: format,
                    initialElapsedMs: initialElapsedMs,
                    result: result
                )
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing path or audio settings", details: nil))
            }
        case "pauseRecording":
            pauseRecording(result: result)
        case "resumeRecording":
            resumeRecording(result: result)
        case "stopRecording":
            let raw = (call.arguments as? [String: Any])?["raw"] as? Bool ?? false
            stopRecording(raw: raw, result: result)
        case "convertAudio":
            if let args = call.arguments as? [String: Any],
               let wavPath = args["wavPath"] as? String,
               let outputPath = args["outputPath"] as? String,
               let format = args["format"] as? String {
                convertAudio(wavPath: wavPath, outputPath: outputPath, format: format, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing wavPath, outputPath or format", details: nil))
            }
        case "cancelRecording":
            cancelRecording(result: result)
        case "startPlayback":
            if let args = call.arguments as? [String: Any],
               let path = args["path"] as? String {
                let position = args["position"] as? Int
                startPlayback(path: path, position: position, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing path", details: nil))
            }
        case "stopPlayback":
            stopPlayback(result: result)
        case "pausePlayback":
            pausePlayback(result: result)
        case "resumePlayback":
            resumePlayback(result: result)
        case "seekTo":
            if let args = call.arguments as? [String: Any],
               let position = args["position"] as? Int {
                seekTo(position: position, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing position", details: nil))
            }
        case "getPlaybackPosition":
            getPlaybackPosition(result: result)
        case "getPlaybackDuration":
            getPlaybackDuration(result: result)
        case "getAudioDuration":
            if let args = call.arguments as? [String: Any],
               let path = args["path"] as? String {
                getAudioDuration(path: path, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing path", details: nil))
            }
        case "getAmplitude":
            result(currentAmplitude)
        case "getRecordingStatus":
            getRecordingStatus(result: result)
        case "isRecording":
            result(isRecording)
        case "isPaused":
            result(isPaused)
        case "isPlaying":
            result(isPlaying && (audioPlayer?.isPlaying ?? false))
        case "setAudioSessionCategory":
            if let args = call.arguments as? [String: Any],
               let category = args["category"] as? String {
                let options = args["options"] as? [String] ?? []
                setAudioSessionCategory(category: category, options: options, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing category", details: nil))
            }
        case "setVoiceProcessing":
            if let args = call.arguments as? [String: Any],
               let enabled = args["enabled"] as? Bool {
                setVoiceProcessing(enabled: enabled, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing enabled", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Initialize

    func initialize(result: @escaping FlutterResult) {
        self.logger.debug("🔧 [NATIVE] initialize — isRecording=\(isRecording) isPaused=\(isPaused)")
        if isRecording || isPaused {
            self.logger.debug("🔧 [NATIVE] initialize: motore già attivo, skip")
            result(true)
            return
        }

        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            guard let self = self else { return }
            self.logger.debug("🔧 [NATIVE] requestRecordPermission: granted=\(granted)")

            guard granted else {
                self.logger.error("🔧 [NATIVE] initialize ERROR: permesso microfono negato")
                result(FlutterError(code: "PERMISSION_DENIED",
                    message: "Microphone permission denied", details: nil))
                return
            }
            do {
                let session = try self.configureAudioSession()

                self.logger.debug("🔧 [NATIVE] initialize: session configurata — category=\(session.category.rawValue)")
                self.logger.debug("🔧 [NATIVE]   isInputAvailable=\(session.isInputAvailable) availableInputs=\(session.availableInputs?.count ?? 0)")

                self.audioEngine = AVAudioEngine()
                self.inputNode = self.audioEngine?.inputNode
                self.audioPlayer = AVAudioPlayerNode()
                self.registerInterruptionObserver()
                self.registerAppLifecycleObservers()

                if let input = self.inputNode {
                    let format = input.outputFormat(forBus: 0)
                    self.logger.debug("🔧 [NATIVE]   inputNode sampleRate=\(format.sampleRate) ch=\(format.channelCount)")
                } else {
                    self.logger.warning("🔧 [NATIVE]   ⚠️ inputNode è nil!")
                }

                self.logger.info("🔧 [NATIVE] initialize: OK")
                result(true)
            } catch {
                self.logger.error("🔧 [NATIVE] initialize ERROR: \(error)")
                result(FlutterError(code: "INIT_ERROR", message: error.localizedDescription, details: nil))
            }
        }
    }

    // MARK: - Standalone Format Conversion

    /// Converte un file WAV al formato richiesto (standalone, chiamabile da Flutter).
    /// Usato dal BLoC dopo seek-and-resume per la conversione finale unica.
    func convertAudio(wavPath: String, outputPath: String, format: String, result: @escaping FlutterResult) {
        self.logger.debug("🔄 [NATIVE] convertAudio — \(wavPath) → \(outputPath) formato=\(format)")

        if format == "wav" {
            // Nessuna conversione, sposta/copia se necessario
            if wavPath != outputPath {
                do {
                    let fm = FileManager.default
                    if fm.fileExists(atPath: outputPath) { try fm.removeItem(atPath: outputPath) }
                    try fm.copyItem(atPath: wavPath, toPath: outputPath)
                } catch {
                    result(FlutterError(code: "FILE_ERROR", message: error.localizedDescription, details: nil))
                    return
                }
            }
            let dur = durationOf(path: outputPath)
            result(["path": outputPath, "duration": dur * 1000])
            return
        }

        // Costruisci settings per il formato target
        // Usa sample rate e bit depth dal WAV sorgente
        guard let wavFile = try? AVAudioFile(forReading: URL(fileURLWithPath: wavPath)) else {
            result(FlutterError(code: "FILE_ERROR", message: "Cannot read WAV file", details: nil))
            return
        }
        let sampleRate = Int(wavFile.fileFormat.sampleRate)
        let settings = buildRecordingSettings(format: format, sampleRate: sampleRate, bitRate: 128000)

        convertWAVToFormat(wavPath: wavPath, outputPath: outputPath, format: format, settings: settings) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                result(FlutterError(code: "CONVERT_ERROR", message: error.localizedDescription, details: nil))
            } else {
                let dur = self.durationOf(path: outputPath)
                self.logger.info("🔄 [NATIVE] convertAudio: OK — \(outputPath) dur=\(dur * 1000)ms")
                result(["path": outputPath, "duration": dur * 1000])
            }
        }
    }

    // MARK: - Helpers

    /// Concatenazione PCM lossless per segmenti WAV (Approccio 1).
    func concatenatePCMFiles(_ paths: [String], into outputPath: String, settings: [String: Any], completion: @escaping (Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let outFile = try AVAudioFile(forWriting: URL(fileURLWithPath: outputPath), settings: settings)
                let chunkFrames: AVAudioFrameCount = 65536
                for path in paths {
                    guard let inFile = try? AVAudioFile(forReading: URL(fileURLWithPath: path)),
                          let buffer = AVAudioPCMBuffer(pcmFormat: inFile.processingFormat, frameCapacity: chunkFrames) else { continue }
                    var remaining = inFile.length
                    while remaining > 0 {
                        let toRead = min(chunkFrames, AVAudioFrameCount(remaining))
                        buffer.frameLength = toRead
                        try inFile.read(into: buffer, frameCount: toRead)
                        if inFile.processingFormat.isEqual(outFile.processingFormat) {
                            try outFile.write(from: buffer)
                        } else {
                            guard let conv = AVAudioConverter(from: inFile.processingFormat, to: outFile.processingFormat),
                                  let convBuf = AVAudioPCMBuffer(pcmFormat: outFile.processingFormat, frameCapacity: toRead) else { break }
                            var inputDone = false
                            var convError: NSError? = nil
                            conv.convert(to: convBuf, error: &convError) { _, status in
                                if !inputDone { inputDone = true; status.pointee = .haveData; return buffer }
                                status.pointee = .endOfStream; return nil
                            }
                            if convError == nil { try outFile.write(from: convBuf) }
                        }
                        remaining -= Int64(toRead)
                    }
                }
                DispatchQueue.main.async { completion(nil) }
            } catch {
                DispatchQueue.main.async { completion(error) }
            }
        }
    }

    func durationOf(path: String) -> Double {
        guard let f = try? AVAudioFile(forReading: URL(fileURLWithPath: path)) else { return 0 }
        return Double(f.length) / f.fileFormat.sampleRate
    }

    // MARK: - WAV → Format Conversion (Approccio 1)

    /// Converte un file WAV al formato finale richiesto dall'utente.
    /// - M4A: AVAssetExportSession con preset AppleM4A (singolo passaggio AAC)
    /// - FLAC: AVAudioConverter PCM → FLAC buffer-by-buffer
    func convertWAVToFormat(wavPath: String, outputPath: String, format: String, settings: [String: Any]?, completion: @escaping (Error?) -> Void) {
        switch format {
        case "m4a":
            convertWAVToM4A(wavPath: wavPath, outputPath: outputPath, completion: completion)
        case "flac":
            convertWAVToFLAC(wavPath: wavPath, outputPath: outputPath, settings: settings ?? [:], completion: completion)
        default:
            // Formato sconosciuto — restituisci il WAV così com'è
            self.logger.warning("⚠️ [NATIVE] convertWAVToFormat: formato sconosciuto '\(format)', skip conversione")
            completion(nil)
        }
    }

    /// WAV → M4A tramite AVAssetExportSession (singolo passaggio AAC).
    func convertWAVToM4A(wavPath: String, outputPath: String, completion: @escaping (Error?) -> Void) {
        let asset = AVURLAsset(url: URL(fileURLWithPath: wavPath))
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            completion(NSError(domain: "WavNote", code: -10,
                userInfo: [NSLocalizedDescriptionKey: "Cannot create M4A export session"]))
            return
        }
        let outputURL = URL(fileURLWithPath: outputPath)
        // Rimuovi file esistente se presente
        try? FileManager.default.removeItem(at: outputURL)
        session.outputURL = outputURL
        session.outputFileType = .m4a
        session.exportAsynchronously {
            if session.status == .completed {
                self.logger.info("✅ [NATIVE] WAV → M4A completato: \(outputPath)")
                completion(nil)
            } else {
                let msg = session.error?.localizedDescription ?? "M4A export failed"
                self.logger.error("❌ [NATIVE] WAV → M4A FALLITO: \(msg)")
                completion(session.error ?? NSError(domain: "WavNote", code: -11,
                    userInfo: [NSLocalizedDescriptionKey: msg]))
            }
        }
    }

    /// WAV → FLAC tramite AVAudioConverter buffer-by-buffer.
    func convertWAVToFLAC(wavPath: String, outputPath: String, settings: [String: Any], completion: @escaping (Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let inFile = try AVAudioFile(forReading: URL(fileURLWithPath: wavPath))
                let outputURL = URL(fileURLWithPath: outputPath)
                try? FileManager.default.removeItem(at: outputURL)
                let outFile = try AVAudioFile(forWriting: outputURL, settings: settings)

                guard let converter = AVAudioConverter(from: inFile.processingFormat, to: outFile.processingFormat) else {
                    DispatchQueue.main.async {
                        completion(NSError(domain: "WavNote", code: -12,
                            userInfo: [NSLocalizedDescriptionKey: "Cannot create FLAC converter"]))
                    }
                    return
                }

                let chunkFrames: AVAudioFrameCount = 65536
                guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: inFile.processingFormat, frameCapacity: chunkFrames),
                      let outputBuffer = AVAudioPCMBuffer(pcmFormat: outFile.processingFormat, frameCapacity: chunkFrames) else {
                    DispatchQueue.main.async {
                        completion(NSError(domain: "WavNote", code: -13,
                            userInfo: [NSLocalizedDescriptionKey: "Cannot create FLAC conversion buffers"]))
                    }
                    return
                }

                var remaining = inFile.length
                while remaining > 0 {
                    let toRead = min(chunkFrames, AVAudioFrameCount(remaining))
                    try inFile.read(into: inputBuffer, frameCount: toRead)

                    var convError: NSError? = nil
                    var inputDone = false
                    converter.convert(to: outputBuffer, error: &convError) { _, status in
                        if !inputDone { inputDone = true; status.pointee = .haveData; return inputBuffer }
                        status.pointee = .endOfStream; return nil
                    }
                    if let err = convError {
                        DispatchQueue.main.async { completion(err) }
                        return
                    }
                    try outFile.write(from: outputBuffer)
                    remaining -= Int64(toRead)
                }

                self.logger.info("✅ [NATIVE] WAV → FLAC completato: \(outputPath)")
                DispatchQueue.main.async { completion(nil) }
            } catch {
                self.logger.error("❌ [NATIVE] WAV → FLAC FALLITO: \(error)")
                DispatchQueue.main.async { completion(error) }
            }
        }
    }

    // MARK: - Format Validation

    /// Costruisce i settings di registrazione per il formato richiesto.
    func buildRecordingSettings(format: String, sampleRate: Int, bitRate: Int) -> [String: Any] {
        switch format {
        case "wav":
            return [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: Double(sampleRate),
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: NSNumber(value: false),
                AVLinearPCMIsFloatKey: NSNumber(value: false)
            ]
        case "flac":
            return [
                AVFormatIDKey: kAudioFormatFLAC,
                AVSampleRateKey: Double(sampleRate),
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16
            ]
        default: // "m4a"
            return [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: Double(sampleRate),
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                AVEncoderBitRateKey: bitRate
            ]
        }
    }

    /// Verifica che i settings siano supportati creando un converter di test.
    func validateRecordingSettings(_ settings: [String: Any], format: String) -> Bool {
        guard let sampleRate = settings[AVSampleRateKey] as? Double else { return false }
        let channels = settings[AVNumberOfChannelsKey] as? Int ?? 1
        // PCM (WAV) è sempre supportato
        if format == "wav" { return true }
        // Per AAC e FLAC: verifica che il converter sia creabile
        guard let inputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: AVAudioChannelCount(channels),
            interleaved: true
        ) else { return false }
        guard let outputFormat = AVAudioFormat(settings: settings) else { return false }
        return AVAudioConverter(from: inputFormat, to: outputFormat) != nil
    }

    // MARK: - Audio Interruption Handling

    /// Registra l'observer per le interruzioni audio (telefonate, Siri, ecc.).
    func registerInterruptionObserver() {
        NotificationCenter.default.removeObserver(self,
            name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self,
            selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance())
        self.logger.debug("🔔 [NATIVE] Interruption observer registrato")
    }

    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            self.logger.info("🔔 [NATIVE] Interruzione INIZIATA — isRecording=\(isRecording) isPaused=\(isPaused)")
            if isRecording && !isPaused {
                // Pausa automatica: chiudi il file corrente come in pauseRecording
                audioEngine?.pause()
                if let path = recordingFilePath {
                    framesInPreviousSegments += framesWrittenThisSegment
                    framesWrittenThisSegment = 0
                    audioFile = nil
                    recordingSegments.append(path)
                    self.logger.info("🔔 [NATIVE] Auto-pausa per interruzione: file chiuso → \(path)")
                }
                isPaused = true
                currentAmplitude = 0.0
            }
            if isPlaying {
                audioPlayer?.pause()
                isPlaying = false
                isPlaybackPaused = true
                self.logger.info("🔔 [NATIVE] Playback pausato per interruzione")
            }

        case .ended:
            self.logger.info("🔔 [NATIVE] Interruzione TERMINATA")
            let shouldResume = (info[AVAudioSessionInterruptionOptionKey] as? UInt)
                .map { AVAudioSession.InterruptionOptions(rawValue: $0).contains(.shouldResume) } ?? false
            if shouldResume {
                self.logger.info("🔔 [NATIVE] Sistema suggerisce resume — riattivo session")
                try? configureAudioSession()
            }
            // Non fa auto-resume della registrazione: l'utente decide quando riprendere.

        @unknown default:
            self.logger.debug("🔔 [NATIVE] Interruzione tipo sconosciuto: \(typeValue)")
        }
    }

    // MARK: - Audio Session Configuration

    @discardableResult
    func configureAudioSession(preferredSampleRate: Int? = nil) throws -> AVAudioSession {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(sessionCategory, mode: .default, options: sessionOptions)
        if let preferredSampleRate {
            try session.setPreferredSampleRate(Double(preferredSampleRate))
        }
        try session.setActive(true)
        return session
    }

    func setAudioSessionCategory(category: String, options: [String], result: @escaping FlutterResult) {
        sessionCategory = parseCategory(category)
        sessionOptions = parseOptions(options)
        self.logger.debug("🔧 [NATIVE] setAudioSessionCategory: \(sessionCategory.rawValue) options=\(sessionOptions.rawValue)")
        do {
            _ = try configureAudioSession()
            result(true)
        } catch {
            self.logger.error("🔧 [NATIVE] setAudioSessionCategory ERROR: \(error)")
            result(FlutterError(code: "SESSION_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    func parseCategory(_ cat: String) -> AVAudioSession.Category {
        let map: [String: AVAudioSession.Category] = [
            "playAndRecord": .playAndRecord, "record": .record, "playback": .playback,
            "ambient": .ambient, "soloAmbient": .soloAmbient, "multiRoute": .multiRoute
        ]
        return map[cat] ?? .playAndRecord
    }

    func parseOptions(_ opts: [String]) -> AVAudioSession.CategoryOptions {
        let map: [String: AVAudioSession.CategoryOptions] = [
            "defaultToSpeaker": .defaultToSpeaker, "allowBluetooth": .allowBluetooth,
            "allowBluetoothA2DP": .allowBluetoothA2DP, "mixWithOthers": .mixWithOthers,
            "duckOthers": .duckOthers, "allowAirPlay": .allowAirPlay
        ]
        return opts.reduce(into: AVAudioSession.CategoryOptions()) { r, o in if let v = map[o] { r.insert(v) } }
    }

    // MARK: - App Lifecycle Handling

    func registerAppLifecycleObservers() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        self.logger.debug("🔔 [NATIVE] App lifecycle observer registrato")
    }

    @objc private func handleDidEnterBackground(_ notification: Notification) {
        let engineRunning = audioEngine?.isRunning ?? false
        self.logger.info("🌙 [NATIVE] App in background — isRecording=\(isRecording) isPaused=\(isPaused) engineRunning=\(engineRunning) frames=\(framesWrittenThisSegment)")
        if isRecording && !isPaused {
            return
        }
        if isPaused {
            do {
                try configureAudioSession(preferredSampleRate: Int(outputSampleRate))
            } catch {
                self.logger.error("🌙 [NATIVE] Background session configure ERROR: \(error)")
            }
        }
    }

    @objc private func handleWillEnterForeground(_ notification: Notification) {
        let engineRunning = audioEngine?.isRunning ?? false
        self.logger.info("☀️ [NATIVE] App in foreground — isRecording=\(isRecording) isPaused=\(isPaused) engineRunning=\(engineRunning) frames=\(framesWrittenThisSegment)")
        if isRecording && !isPaused {
            guard !engineRunning else { return }
            do {
                try audioEngine?.start()
                lastClockEmitTime = 0
                lastLiveActivityUpdateTime = 0
                self.logger.info("☀️ [NATIVE] Foreground recovery: audioEngine riavviato")
            } catch {
                self.logger.error("☀️ [NATIVE] Foreground recovery start ERROR: \(error)")
                do {
                    try configureAudioSession(preferredSampleRate: Int(outputSampleRate))
                    try audioEngine?.start()
                    lastClockEmitTime = 0
                    lastLiveActivityUpdateTime = 0
                    self.logger.info("☀️ [NATIVE] Foreground recovery: sessione riconfigurata e audioEngine riavviato")
                } catch {
                    self.logger.error("☀️ [NATIVE] Foreground recovery fallback ERROR: \(error)")
                }
            }
            return
        }
        if isPaused {
            do {
                try configureAudioSession(preferredSampleRate: Int(outputSampleRate))
            } catch {
                self.logger.error("☀️ [NATIVE] Foreground paused session configure ERROR: \(error)")
            }
        }
    }

    // MARK: - Voice Processing

    func setVoiceProcessing(enabled: Bool, result: @escaping FlutterResult) {
        voiceProcessingEnabled = enabled
        self.logger.debug("🎤 [NATIVE] Voice processing: \(enabled ? "ON" : "OFF")")
        if let input = inputNode, isRecording {
            guard #available(iOS 13.0, *) else {
                result(FlutterError(code: "VP_UNSUPPORTED", message: "Requires iOS 13+", details: nil)); return
            }
            do { try input.setVoiceProcessingEnabled(enabled); result(true) }
            catch { result(FlutterError(code: "VP_ERROR", message: error.localizedDescription, details: nil)) }
            return
        }
        result(true)
    }
}
