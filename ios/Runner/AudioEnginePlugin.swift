// File: ios/Runner/AudioEnginePlugin.swift
// AVAudioEngine recorder con playback simultaneo, interruption handling,
// validazione formato, voice processing e session configurabile.

import Flutter
import AVFoundation
import Logging

// Event Channel per notificare Dart del completamento del playback
class PlaybackStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private let logger = Logger(label: "com.wavnote.audio_engine.stream_handler")

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
    private var eventSink: FlutterEventSink?

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
}

// Estensione per aggiungere un logger condiviso
extension AudioEnginePlugin {
    private static var sharedLogger: Logger = {
        var logger = Logger(label: "com.wavnote.audio_engine_static")
        return logger
    }()

    var logger: Logger {
        return AudioEnginePlugin.sharedLogger
    }
}


public class AudioEnginePlugin: NSObject, FlutterPlugin {
    
    private let playbackStreamHandler = PlaybackStreamHandler()
    private let clockStreamHandler = ClockStreamHandler()

    // MARK: - Clock state (recording)
    /// Frame scritti nei segmenti già chiusi (accumulati attraverso pause/resume).
    private var framesInPreviousSegments: Int64 = 0
    /// Frame scritti nel segmento corrente (resettato a ogni nuovo file).
    private var framesWrittenThisSegment: Int64 = 0
    /// Sample rate del file WAV di output (impostato a startRecording).
    private var outputSampleRate: Double = 44100
    /// Timestamp dell'ultimo tick di clock emesso (CACurrentMediaTime). Throttle a 100ms.
    private var lastClockEmitTime: CFTimeInterval = 0

    // MARK: - Clock state (playback)
    /// Timer nativo che emette playback tick ogni 100ms.
    private var playbackClockTimer: DispatchSourceTimer?

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFile: AVAudioFile?
    private var playbackEngine: AVAudioEngine?
    private var audioPlayer: AVAudioPlayerNode?
    private var audioFileForPlayback: AVAudioFile?

    private var isRecording = false
    private var isPaused = false
    private var isPlaying = false
    private var isPlaybackPaused = false
    /// Flag impostata dal callback nativo quando l'audio fisicamente finisce.
    /// Solo il timer può leggere questa flag e gestire il completamento.
    private var playbackFinished = false
    /// Incrementato ad ogni nuova sessione di playback (startPlayback o seekTo).
    /// I completion handler confrontano la propria generazione con quella corrente:
    /// se diversa, il handler è orfano (da un vecchio segmento) e va ignorato.
    private var playbackGeneration: Int = 0

    private var recordingFilePath: String?
    private var recordingSettings: [String: Any]?
    /// Segmenti finalizzati (sempre WAV internamente).
    private var recordingSegments: [String] = []
    /// Formato interno di registrazione (sempre "wav" — Approccio 1).
    private var recordingFormat: String = "wav"
    /// Formato finale richiesto dall'utente: "m4a" | "wav" | "flac"
    private var requestedFormat: String = "m4a"
    /// Path finale con l'estensione del formato richiesto dall'utente.
    private var requestedOutputPath: String?
    /// Settings per il formato finale (M4A/FLAC) — usati solo alla conversione.
    private var requestedFormatSettings: [String: Any]?
    private var playbackTempPath: String?
    private var currentAmplitude: Float = 0.0
    /// Frame di inizio del segmento schedulato (usato per calcolare la posizione di playback corretta dopo seekTo).
    private var seekOffsetFrames: Int64 = 0

    /// Categoria e opzioni audio session configurabili da Flutter.
    private var sessionCategory: AVAudioSession.Category = .playAndRecord
    private var sessionOptions: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .allowBluetooth]
    /// Voice processing (echo cancellation + noise suppression).
    private var voiceProcessingEnabled = false
    /// Sample rate massimo supportato.
    private static let maxSampleRate = 48000

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.wavnote/audio_engine",
            binaryMessenger: registrar.messenger()
        )
        let instance = AudioEnginePlugin()
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
                startRecording(path: path, sampleRate: sampleRate, bitRate: bitRate, format: format, result: result)
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

    private func initialize(result: @escaping FlutterResult) {
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
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(self.sessionCategory, mode: .default, options: self.sessionOptions)
                try session.setActive(true)

                self.logger.debug("🔧 [NATIVE] initialize: session configurata — category=\(session.category.rawValue)")
                self.logger.debug("🔧 [NATIVE]   isInputAvailable=\(session.isInputAvailable) availableInputs=\(session.availableInputs?.count ?? 0)")

                self.audioEngine = AVAudioEngine()
                self.inputNode = self.audioEngine?.inputNode
                self.audioPlayer = AVAudioPlayerNode()
                self.registerInterruptionObserver()

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

    // MARK: - Recording

    private func startRecording(path: String, sampleRate: Int, bitRate: Int, format: String, result: @escaping FlutterResult) {
        // Cap sample rate a 48kHz (come fa il package record)
        let cappedSampleRate = min(sampleRate, AudioEnginePlugin.maxSampleRate)
        self.logger.debug("🎙️ [NATIVE] startRecording — path=\(path) format=\(format) sr=\(cappedSampleRate) br=\(bitRate)")
        guard audioEngine != nil, inputNode != nil else {
            self.logger.error("🎙️ [NATIVE] startRecording ERROR: motore non inizializzato")
            result(FlutterError(code: "NOT_INITIALIZED", message: "AudioEngine not initialized", details: nil))
            return
        }
        let input = inputNode!
        do {
            // Riconfigura la sessione audio prima di ogni registrazione
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(sessionCategory, mode: .default, options: sessionOptions)
            try session.setActive(true)
            self.logger.debug("🎙️ [NATIVE] startRecording: AVAudioSession riconfigurata")
            let fileURL = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            // Approccio 1: salva il formato richiesto dall'utente, registra sempre in WAV
            requestedFormat = format
            requestedOutputPath = path
            recordingFormat = "wav"

            // Validazione: verifica che il formato finale sia supportato
            if format != "wav" {
                let finalSettings = buildRecordingSettings(format: format, sampleRate: cappedSampleRate, bitRate: bitRate)
                if !validateRecordingSettings(finalSettings, format: format) {
                    result(FlutterError(code: "FORMAT_ERROR",
                        message: "Audio format '\(format)' with sampleRate \(cappedSampleRate) is not supported on this device",
                        details: nil))
                    return
                }
                requestedFormatSettings = finalSettings
            } else {
                requestedFormatSettings = nil
            }

            // Internamente registra sempre in WAV PCM 16-bit lossless
            let wavSettings = buildRecordingSettings(format: "wav", sampleRate: cappedSampleRate, bitRate: bitRate)
            recordingSettings = wavSettings
            recordingSegments = []
            framesInPreviousSegments = 0
            framesWrittenThisSegment = 0
            lastClockEmitTime = 0

            // Cambia estensione a .wav per il file interno
            let wavURL = fileURL.deletingPathExtension().appendingPathExtension("wav")
            let wavPath = wavURL.path
            self.logger.debug("🎙️ [NATIVE] startRecording: interno WAV → \(wavPath) (formato finale: \(format))")

            audioFile = try AVAudioFile(forWriting: wavURL, settings: wavSettings)
            recordingFilePath = wavPath

            let rawFormat = input.outputFormat(forBus: 0)
            self.logger.debug("🎙️ [NATIVE] startRecording: rawFormat — sampleRate=\(rawFormat.sampleRate) channels=\(rawFormat.channelCount)")

            // Sul simulatore senza permesso macOS il formato ha 0 canali / 0 Hz.
            let inputFormat: AVAudioFormat
            if rawFormat.channelCount == 0 || rawFormat.sampleRate == 0 {
                self.logger.debug("🎙️ [NATIVE] startRecording: formato invalido, ricreo engine...")
                audioEngine?.stop()
                audioEngine = AVAudioEngine()
                inputNode = audioEngine?.inputNode
                guard let _ = audioEngine, let newInput = inputNode else {
                    result(FlutterError(code: "ENGINE_ERROR", message: "Failed to recreate audio engine", details: nil))
                    return
                }
                let retryFormat = newInput.outputFormat(forBus: 0)
                self.logger.debug("🎙️ [NATIVE] startRecording: retryFormat — sampleRate=\(retryFormat.sampleRate) channels=\(retryFormat.channelCount)")
                if retryFormat.channelCount == 0 || retryFormat.sampleRate == 0 {
                    self.logger.error("🎙️ [NATIVE] startRecording ERROR: microfono non accessibile")
                    result(FlutterError(code: "NO_MIC_ACCESS",
                        message: "Microphone not accessible. On Simulator: grant mic permission to Simulator.app in macOS System Settings",
                        details: nil))
                    return
                }
                inputFormat = retryFormat
            } else {
                inputFormat = rawFormat
            }

            let outputFormat = audioFile!.processingFormat
            outputSampleRate = outputFormat.sampleRate
            var converter: AVAudioConverter? = nil
            if !inputFormat.isEqual(outputFormat) {
                self.logger.debug("🎙️ [NATIVE] startRecording: converter — \(inputFormat.sampleRate)Hz → \(outputFormat.sampleRate)Hz")
                converter = AVAudioConverter(from: inputFormat, to: outputFormat)
                if converter == nil {
                    self.logger.error("🎙️ [NATIVE] startRecording ERROR: impossibile creare AVAudioConverter")
                    result(FlutterError(code: "FORMAT_ERROR", message: "Cannot create audio format converter", details: nil))
                    return
                }
            }

            var bufferCount = 0
            let tapInput = inputNode!

            // FIX: Rimuove esplicitamente qualsiasi tap precedente per evitare il crash 'nullptr == Tap()'
            tapInput.removeTap(onBus: 0)

            tapInput.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
                guard let self = self, self.audioFile != nil else { return }

                bufferCount += 1
                let shouldLog = bufferCount % 100 == 1

                if shouldLog {
                    self.logger.trace("🎙️ [NATIVE] tap buffer #\(bufferCount) — frames=\(buffer.frameLength)")
                }

                var writtenOutputFrames: Int64 = 0
                do {
                    if let converter = converter {
                        let pcmBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: buffer.frameCapacity)
                        var error: NSError? = nil
                        converter.convert(to: pcmBuffer!, error: &error) { _, outStatus in
                            outStatus.pointee = .haveData
                            return buffer
                        }
                        if let err = error {
                            self.logger.error("🎙️ [NATIVE] converter ERROR: \(err)")
                        } else if let pcmBuffer = pcmBuffer {
                            try self.audioFile?.write(from: pcmBuffer)
                            writtenOutputFrames = Int64(pcmBuffer.frameLength)
                        }
                    } else {
                        try self.audioFile?.write(from: buffer)
                        writtenOutputFrames = Int64(buffer.frameLength)
                    }
                } catch {
                    self.logger.error("🎙️ [NATIVE] tap write ERROR: \(error)")
                }

                self.framesWrittenThisSegment += writtenOutputFrames

                // Calcola amplitude
                if let ch = buffer.floatChannelData?[0] {
                    let n = Int(buffer.frameLength)
                    var sq: Float = 0
                    for i in 0..<n { sq += ch[i] * ch[i] }
                    let amp = min(sqrt(sq / Float(max(n, 1))) * 10.0, 1.0)
                    self.currentAmplitude = amp
                    if shouldLog { self.logger.trace("🎙️ [NATIVE]   amplitude=\(amp)") }
                }

                // Clock tick — throttle a 100ms, chiamato su main thread per Flutter EventChannel
                let now = CACurrentMediaTime()
                if now - self.lastClockEmitTime >= 0.1 {
                    self.lastClockEmitTime = now
                    let totalFrames = self.framesInPreviousSegments + self.framesWrittenThisSegment
                    let positionMs = Int(Double(totalFrames) / self.outputSampleRate * 1000)
                    let amp = self.currentAmplitude
                    DispatchQueue.main.async { [weak self] in
                        self?.clockStreamHandler.sendRecordingTick(
                            positionMs: positionMs,
                            amplitude: Double(amp)
                        )
                    }
                }
            }
            // Voice processing (echo cancellation + noise suppression)
            if voiceProcessingEnabled {
                if #available(iOS 13.0, *) {
                    try tapInput.setVoiceProcessingEnabled(true)
                    self.logger.debug("🎙️ [NATIVE] voice processing abilitato")
                }
            }

            try audioEngine!.start()
            isRecording = true
            isPaused = false
            self.logger.info("🎙️ [NATIVE] startRecording: OK — engine running")
            result(true)
        } catch {
            self.logger.error("🎙️ [NATIVE] startRecording ERROR: \(error)")
            result(FlutterError(code: "RECORD_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func pauseRecording(result: @escaping FlutterResult) {
        self.logger.debug("⏸️ [NATIVE] pauseRecording — isRecording=\(isRecording) isPaused=\(isPaused)")
        guard isRecording, !isPaused else {
            self.logger.error("⏸️ [NATIVE] pauseRecording ERROR: stato invalido")
            result(FlutterError(code: "INVALID_STATE", message: "Not recording or already paused", details: nil))
            return
        }
        // Log frames scritti PRIMA di chiudere il file
        if let file = audioFile {
            let sr = file.processingFormat.sampleRate
            let frames = file.length
            self.logger.debug("⏸️ [NATIVE] pauseRecording: PRIMA chiusura — frames=\(frames) (\(Double(frames)/sr)s ≈ \(Int((Double(frames)/sr)*10)) bars@100ms)")
        }
        audioEngine?.pause()
        if let path = recordingFilePath {
            framesInPreviousSegments += framesWrittenThisSegment
            framesWrittenThisSegment = 0
            audioFile = nil   // ARC chiude il file → header WAV aggiornato
            recordingSegments.append(path)
            // Riapri in lettura per verificare che il file sia stato chiuso correttamente
            if let readFile = try? AVAudioFile(forReading: URL(fileURLWithPath: path)) {
                let sr = readFile.processingFormat.sampleRate
                let frames = readFile.length
                self.logger.debug("⏸️ [NATIVE] pauseRecording: DOPO chiusura — frames=\(frames) (\(Double(frames)/sr)s ≈ \(Int((Double(frames)/sr)*10)) bars@100ms) segmenti=\(recordingSegments.count)")
            }
            if let attrs = try? FileManager.default.attributesOfItem(atPath: path) {
                self.logger.debug("⏸️ [NATIVE] pauseRecording: size=\(attrs[.size] ?? 0) bytes")
            }
        }
        isPaused = true
        currentAmplitude = 0.0
        result(true)
    }

    private func resumeRecording(result: @escaping FlutterResult) {
        self.logger.debug("▶️ [NATIVE] resumeRecording — isRecording=\(isRecording) isPaused=\(isPaused) segmenti=\(recordingSegments.count)")
        guard isRecording, isPaused else {
            self.logger.error("▶️ [NATIVE] resumeRecording ERROR: stato invalido")
            result(FlutterError(code: "INVALID_STATE", message: "Not paused", details: nil))
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(sessionCategory, mode: .default, options: sessionOptions)
            try session.setActive(true)
            self.logger.debug("▶️ [NATIVE] resumeRecording: AVAudioSession riconfigurata")
            guard let settings = recordingSettings, let first = recordingSegments.first else {
                self.logger.error("▶️ [NATIVE] resumeRecording ERROR: nessun settings o segmento")
                result(FlutterError(code: "RESUME_ERROR", message: "No recording settings available", details: nil))
                return
            }
            let baseURL = URL(fileURLWithPath: first)
            let contPath = baseURL.deletingPathExtension().path + "_cnt\(recordingSegments.count)." + baseURL.pathExtension
            self.logger.debug("▶️ [NATIVE] resumeRecording: nuovo file → \(contPath)")
            audioFile = try AVAudioFile(forWriting: URL(fileURLWithPath: contPath), settings: settings)
            recordingFilePath = contPath
            framesWrittenThisSegment = 0
            lastClockEmitTime = 0
            try audioEngine?.start()
            isPaused = false
            self.logger.info("▶️ [NATIVE] resumeRecording: OK — engine riavviato")
            result(true)
        } catch {
            self.logger.error("▶️ [NATIVE] resumeRecording ERROR: \(error)")
            result(FlutterError(code: "RESUME_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func stopRecording(raw: Bool = false, result: @escaping FlutterResult) {
        self.logger.debug("⏹️ [NATIVE] stopRecording — raw=\(raw) isRecording=\(isRecording) isPaused=\(isPaused) segmenti=\(recordingSegments.count)")
        guard isRecording else {
            self.logger.error("⏹️ [NATIVE] stopRecording ERROR: non in registrazione")
            result(FlutterError(code: "INVALID_STATE", message: "Not recording", details: nil))
            return
        }
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        if let path = recordingFilePath, audioFile != nil {
            audioFile = nil
            recordingSegments.append(path)
            self.logger.debug("⏹️ [NATIVE] stopRecording: segmento finale → \(path)")
        } else {
            audioFile = nil
            self.logger.debug("⏹️ [NATIVE] stopRecording: audioFile già nil (era in pausa)")
        }
        recordingFilePath = nil
        isRecording = false
        isPaused = false
        currentAmplitude = 0.0
        framesInPreviousSegments = 0
        framesWrittenThisSegment = 0
        self.logger.debug("⏹️ [NATIVE] stopRecording: \(recordingSegments.count) segmenti da processare")

        guard !recordingSegments.isEmpty else {
            recordingSettings = nil
            result(FlutterError(code: "NO_DATA", message: "No recording data", details: nil))
            return
        }

        // Approccio 1: tutti i segmenti sono WAV — concatena con PCM buffer copy
        let wavSettings = recordingSettings ?? [:]
        let finalFormat = requestedFormat
        let finalOutputPath = requestedOutputPath ?? recordingSegments[0]
        let all = recordingSegments
        recordingSegments = []
        recordingSettings = nil

        // Fase 1: se un solo segmento, usa direttamente; altrimenti concatena
        let singleSegment = all.count == 1

        let afterWAVReady: (String) -> Void = { [weak self] wavPath in
            guard let self = self else { return }

            // raw=true: restituisci il WAV grezzo senza conversione (per seek-and-resume)
            if raw {
                self.logger.debug("⏹️ [NATIVE] stopRecording: raw mode — restituisco WAV: \(wavPath)")
                self.finishWithFile(wavPath, outputPath: wavPath, segments: all, result: result)
                return
            }

            // Fase 2: converti WAV → formato finale se necessario
            if finalFormat == "wav" {
                self.finishWithFile(wavPath, outputPath: finalOutputPath, segments: all, result: result)
            } else {
                self.logger.debug("⏹️ [NATIVE] stopRecording: conversione WAV → \(finalFormat)")
                self.convertWAVToFormat(wavPath: wavPath, outputPath: finalOutputPath,
                    format: finalFormat, settings: self.requestedFormatSettings) { error in
                    if let error = error {
                        self.logger.error("⏹️ [NATIVE] stopRecording: conversione FALLITA — \(error)")
                        self.finishWithFile(wavPath, outputPath: wavPath, segments: all, result: result)
                    } else {
                        self.logger.debug("⏹️ [NATIVE] stopRecording: conversione OK → \(finalOutputPath)")
                        try? FileManager.default.removeItem(atPath: wavPath)
                        self.finishWithFile(finalOutputPath, outputPath: finalOutputPath, segments: all, result: result)
                    }
                }
            }
        }

        if singleSegment {
            afterWAVReady(all[0])
        } else {
            let tempConcatPath = all[0] + ".concat.tmp"
            concatenatePCMFiles(all, into: tempConcatPath, settings: wavSettings) { error in
                if let error = error {
                    try? FileManager.default.removeItem(atPath: tempConcatPath)
                    result(FlutterError(code: "CONCAT_ERROR", message: error.localizedDescription, details: nil))
                    return
                }
                // Sposta il concat al posto del primo segmento
                let concatWavPath = all[0]
                do {
                    let fm = FileManager.default
                    if fm.fileExists(atPath: concatWavPath) { try fm.removeItem(atPath: concatWavPath) }
                    try fm.moveItem(atPath: tempConcatPath, toPath: concatWavPath)
                    for i in 1..<all.count { try? fm.removeItem(atPath: all[i]) }
                } catch {
                    result(FlutterError(code: "FILE_ERROR", message: error.localizedDescription, details: nil))
                    return
                }
                afterWAVReady(concatWavPath)
            }
        }
    }

    /// Helper per restituire il risultato finale di stopRecording.
    private func finishWithFile(_ path: String, outputPath: String, segments: [String], result: @escaping FlutterResult) {
        // Se path != outputPath e dobbiamo spostare
        if path != outputPath {
            do {
                let fm = FileManager.default
                if fm.fileExists(atPath: outputPath) { try fm.removeItem(atPath: outputPath) }
                try fm.moveItem(atPath: path, toPath: outputPath)
            } catch {
                self.logger.error("⏹️ [NATIVE] finishWithFile: move ERROR — \(error)")
            }
        }
        let dur = durationOf(path: outputPath)
        requestedFormatSettings = nil
        requestedOutputPath = nil
        self.logger.info("⏹️ [NATIVE] stopRecording: COMPLETATO — path=\(outputPath) dur=\(dur * 1000)ms")
        result(["path": outputPath, "duration": dur * 1000])
    }

    private func cancelRecording(result: @escaping FlutterResult) {
        self.logger.error("❌ [NATIVE] cancelRecording")
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioFile = nil
        audioPlayer?.stop()
        playbackEngine?.stop()
        playbackEngine = nil
        audioFileForPlayback = nil
        isPlaying = false
        for path in recordingSegments { try? FileManager.default.removeItem(atPath: path) }
        if let path = recordingFilePath { try? FileManager.default.removeItem(atPath: path) }
        if let tmp = playbackTempPath { try? FileManager.default.removeItem(atPath: tmp); playbackTempPath = nil }
        recordingSegments = []
        recordingSettings = nil
        recordingFormat = "wav"
        requestedFormat = "m4a"
        requestedOutputPath = nil
        requestedFormatSettings = nil
        isRecording = false
        isPaused = false
        recordingFilePath = nil
        framesInPreviousSegments = 0
        framesWrittenThisSegment = 0
        result(true)
    }

    // MARK: - Standalone Format Conversion

    /// Converte un file WAV al formato richiesto (standalone, chiamabile da Flutter).
    /// Usato dal BLoC dopo seek-and-resume per la conversione finale unica.
    private func convertAudio(wavPath: String, outputPath: String, format: String, result: @escaping FlutterResult) {
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

    // MARK: - Playback

    private func startPlayback(path: String, position: Int?, result: @escaping FlutterResult) {
        self.logger.debug("▶️ [NATIVE] startPlayback — isRecording=\(isRecording) isPaused=\(isPaused) path=\(path)")
        
        // Se Flutter ci passa un path temporaneo generato dal trimmer (es. "preview"), lo usiamo!
        // Altrimenti, se siamo in registrazione/pausa normale, usiamo startPlaybackFromSegments o exportForPlayback.
        let isPreviewPath = path.contains("_preview_")
        
        if isPreviewPath {
            startPlaybackInternal(path: path, position: position, result: result)
        } else if isRecording && !isPaused {
            exportForPlayback(sourcePath: path) { [weak self] tempPath, error in
                guard let self = self else { return }
                if let error = error {
                    result(FlutterError(code: "EXPORT_ERROR", message: error.localizedDescription, details: nil))
                    return
                }
                guard let tempPath = tempPath else {
                    result(FlutterError(code: "EXPORT_ERROR", message: "Export returned nil path", details: nil))
                    return
                }
                self.playbackTempPath = tempPath
                self.startPlaybackInternal(path: tempPath, position: position, result: result)
            }
        } else if isRecording && isPaused {
            startPlaybackFromSegments(position: position, result: result)
        } else {
            startPlaybackInternal(path: path, position: position, result: result)
        }
    }

    private func startPlaybackFromSegments(position: Int?, result: @escaping FlutterResult) {
        guard !recordingSegments.isEmpty else {
            result(FlutterError(code: "NO_SEGMENTS", message: "No recording segments available", details: nil))
            return
        }
        if recordingSegments.count == 1 {
            startPlaybackInternal(path: recordingSegments[0], position: position, result: result)
        } else {
            let tempPath = NSTemporaryDirectory() + "wavnote_pb_\(Int(Date().timeIntervalSince1970 * 1000)).wav"
            let savedSettings = recordingSettings ?? [:]
            let segs = recordingSegments
            concatenatePCMFiles(segs, into: tempPath, settings: savedSettings) { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    self.logger.error("▶️ [NATIVE] startPlaybackFromSegments CONCAT ERROR: \(error)")
                    self.startPlaybackInternal(path: self.recordingSegments[0], position: position, result: result)
                } else {
                    self.playbackTempPath = tempPath
                    self.startPlaybackInternal(path: tempPath, position: position, result: result)
                }
            }
        }
    }

    /// Esporta il file WAV corrente per il playback durante la registrazione attiva.
    /// Con Approccio 1 il file sorgente è sempre WAV — usiamo Passthrough (nessuna ri-codifica).
    private func exportForPlayback(sourcePath: String, completion: @escaping (String?, Error?) -> Void) {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wavnote_exp_\(Int(Date().timeIntervalSince1970 * 1000)).wav")
        let asset = AVURLAsset(url: URL(fileURLWithPath: sourcePath))
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            completion(nil, NSError(domain: "WavNote", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Cannot create export session"]))
            return
        }
        session.outputURL = tempURL
        session.outputFileType = .wav
        session.timeRange = CMTimeRange(start: .zero,
            duration: CMTimeMakeWithSeconds(86400, preferredTimescale: 44100))
        session.exportAsynchronously {
            if session.status == .completed {
                completion(tempURL.path, nil)
            } else {
                let msg = session.error?.localizedDescription ?? "Export failed"
                completion(nil, NSError(domain: "WavNote", code: -2,
                    userInfo: [NSLocalizedDescriptionKey: msg]))
            }
        }
    }

    private func startPlaybackInternal(path: String, position: Int?, result: @escaping FlutterResult) {
        self.logger.debug("🔊 [NATIVE] startPlaybackInternal — path=\(path)")
        do {
            if playbackEngine != nil {
                audioPlayer?.stop()
                playbackEngine?.stop()
                playbackEngine = nil
            }
            audioFileForPlayback = try AVAudioFile(forReading: URL(fileURLWithPath: path))
            guard let file = audioFileForPlayback else {
                result(FlutterError(code: "FILE_ERROR", message: "Could not open audio file", details: nil))
                return
            }
            let sr = file.processingFormat.sampleRate
            self.logger.debug("🔊 [NATIVE] startPlaybackInternal: file.length=\(file.length) (\(Double(file.length)/sr)s ≈ \(Int((Double(file.length)/sr)*10)) bars@100ms)")
            audioPlayer = AVAudioPlayerNode()
            playbackEngine = AVAudioEngine()
            guard let player = audioPlayer, let engine = playbackEngine else {
                result(FlutterError(code: "ENGINE_ERROR", message: "Could not create playback engine", details: nil))
                return
            }
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)
            playbackGeneration += 1
            let gen = playbackGeneration
            try engine.start()
            
            // Reset della flag di completamento prima di iniziare il playback
            self.playbackFinished = false
            
            if let pos = position, pos > 0 {
                let rawFramePosition = AVAudioFramePosition(Double(pos) / 1000.0 * sr)
                let framePosition = min(rawFramePosition, file.length > 0 ? file.length - 1 : 0)
                let frameCount = max(1, AVAudioFrameCount(file.length - framePosition))
                
                if frameCount < 4410 {
                    self.logger.debug("🔊 [NATIVE] startPlaybackInternal: fine file raggiunta (frameCount=\(frameCount)), emulo completamento")
                    self.isPlaying = false
                    result(true)
                    return
                }
                
                seekOffsetFrames = Int64(framePosition)
                player.scheduleSegment(file, startingFrame: framePosition, frameCount: frameCount, at: nil) { [weak self] in
                    DispatchQueue.main.async {
                        guard let self = self, self.playbackEngine != nil else { return }
                        guard self.playbackGeneration == gen else { return }
                        
                        // Il callback nativo segnala solo al timer che il playback è finito.
                        // Solo il timer può gestire il completamento effettivo.
                        self.logger.debug("🔊 [NATIVE] Playback (segment) completion callback: signaling finished")
                        self.playbackFinished = true
                    }
                }
            } else {
                seekOffsetFrames = 0
                player.scheduleFile(file, at: nil) { [weak self] in
                    DispatchQueue.main.async {
                        guard let self = self, self.playbackEngine != nil else { return }
                        guard self.playbackGeneration == gen else { return }
                        
                        // Il callback nativo segnala solo al timer che il playback è finito.
                        // Solo il timer può gestire il completamento effettivo.
                        self.logger.debug("🔊 [NATIVE] Playback (full file) completion callback: signaling finished")
                        self.playbackFinished = true
                    }
                }
            }
            
            // Forza il pre-buffering per evitare I/O starvation e interruzione anticipata
            player.prepare(withFrameCount: 8192)
            player.play()
            startPlaybackClock()

            isPlaying = true
            isPlaybackPaused = false
            self.logger.info("🔊 [NATIVE] startPlaybackInternal: OK")
            result(true)
        } catch {
            self.logger.error("🔊 [NATIVE] startPlaybackInternal ERROR: \(error)")
            result(FlutterError(code: "PLAYBACK_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func stopPlayback(result: @escaping FlutterResult) {
        self.logger.debug("⏹️ [NATIVE] stopPlayback")
        stopPlaybackClock()
        audioPlayer?.stop()
        playbackEngine?.stop()
        playbackEngine = nil
        audioFileForPlayback = nil
        isPlaying = false
        isPlaybackPaused = false
        if let tmp = playbackTempPath {
            try? FileManager.default.removeItem(atPath: tmp)
            playbackTempPath = nil
        }
        result(true)
    }

    private func pausePlayback(result: @escaping FlutterResult) {
        self.logger.debug("⏸️ [NATIVE] pausePlayback")
        audioPlayer?.pause()
        isPlaying = false
        result(true)
    }

    private func resumePlayback(result: @escaping FlutterResult) {
        self.logger.debug("▶️ [NATIVE] resumePlayback")
        audioPlayer?.play()
        isPlaying = true
        result(true)
    }

    private func seekTo(position: Int, result: @escaping FlutterResult) {
        guard let player = audioPlayer, let file = audioFileForPlayback else {
            result(FlutterError(code: "NOT_PLAYING", message: "No active playback", details: nil))
            return
        }
        let sampleRate = file.processingFormat.sampleRate
        let rawFramePosition = AVAudioFramePosition(Double(position) / 1000.0 * sampleRate)
        guard rawFramePosition >= 0 else {
            result(FlutterError(code: "INVALID_POSITION", message: "Position out of range", details: nil))
            return
        }
        let framePosition = min(rawFramePosition, file.length > 0 ? file.length - 1 : 0)
        let frameCount = max(1, AVAudioFrameCount(file.length - framePosition))
        
        // Se mancano pochissimi frame (es. <0.1s a 44.1kHz), restituiamo subito fine playback
        // perché scheduleSegment con valori esigui può causare hang in AVAudioEngine
        if frameCount < 4410 {
            self.logger.debug("🔊 [NATIVE] seekTo: fine file raggiunta (frameCount=\(frameCount)), emulo completamento")
            self.isPlaying = false
            result(true)
            return
        }

        self.logger.debug("🔊 [NATIVE] seekTo: file.length=\(file.length) (\(Double(file.length)/sampleRate)s) framePos=\(framePosition) frameCount=\(frameCount) → suonerà \(Double(frameCount)/sampleRate)s")
        playbackGeneration += 1
        let gen = playbackGeneration
        seekOffsetFrames = Int64(framePosition)
        
        // Reset della flag di completamento prima di iniziare il playback
        self.playbackFinished = false
        
        player.stop()
        
        player.scheduleSegment(file, startingFrame: framePosition, frameCount: frameCount, at: nil) { [weak self] in
            DispatchQueue.main.async {
                guard let self = self, self.playbackEngine != nil else { return }
                guard self.playbackGeneration == gen else { return }
                
                // Il callback nativo segnala solo al timer che il playback è finito.
                // Solo il timer può gestire il completamento effettivo.
                self.logger.debug("🔊 [NATIVE] Playback (seek) completion callback: signaling finished")
                self.playbackFinished = true
            }
        }
        
        // Forza il pre-buffering prima del play per evitare starvation e interruzione anticipata
        player.prepare(withFrameCount: 8192)
        player.play()
        
        isPlaying = true
        isPlaybackPaused = false
        result(true)
    }

    private func getPlaybackPosition(result: @escaping FlutterResult) {
        guard let p = audioPlayer, let f = audioFileForPlayback else { result(0); return }
        let sampleRate = f.processingFormat.sampleRate
        let renderedFrames: Int64
        if let nodeTime = p.lastRenderTime, let playerTime = p.playerTime(forNodeTime: nodeTime) {
            renderedFrames = max(0, Int64(playerTime.sampleTime))
        } else {
            renderedFrames = 0
        }
        let totalFrames = seekOffsetFrames + renderedFrames
        result(Int(Double(totalFrames) / sampleRate * 1000))
    }

    private func getPlaybackDuration(result: @escaping FlutterResult) {
        guard let player = audioPlayer, let file = audioFileForPlayback else {
            result(0)
            return
        }
        let durationMs = Int((Double(file.length) / file.processingFormat.sampleRate) * 1000)
        result(durationMs)
    }

    private func getAudioDuration(path: String, result: @escaping FlutterResult) {
        let url = URL(fileURLWithPath: path)
        do {
            let file = try AVAudioFile(forReading: url)
            let durationMs = Int((Double(file.length) / file.processingFormat.sampleRate) * 1000)
            result(durationMs)
        } catch {
            self.logger.error("❌ [NATIVE] getAudioDuration ERROR: \(error)")
            result(0)
        }
    }

    private var lastReportedFrames: Int64 = 0
    private var stalledTicks: Int = 0

    // MARK: - Playback Clock

    /// Avvia il DispatchSourceTimer che emette playback tick ogni 100ms.
    /// La posizione è calcolata da lastRenderTime (sample-accurate).
    /// Il timer è l'unica autorità per la posizione e il completamento del playback.
    private func startPlaybackClock() {
        stopPlaybackClock()
        self.lastReportedFrames = 0
        self.stalledTicks = 0
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + .milliseconds(100), repeating: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            guard let self = self,
                  self.isPlaying,
                  !self.isPlaybackPaused,
                  let file = self.audioFileForPlayback else { return }
            let sampleRate = file.processingFormat.sampleRate
            let renderedFrames: Int64
            if let nodeTime = self.audioPlayer?.lastRenderTime,
               let playerTime = self.audioPlayer?.playerTime(forNodeTime: nodeTime) {
                renderedFrames = max(0, Int64(playerTime.sampleTime))
            } else {
                renderedFrames = 0
            }
            let totalFrames = self.seekOffsetFrames + renderedFrames
            let positionMs = Int(Double(totalFrames) / sampleRate * 1000)
            let durationMs = Int(Double(file.length) / sampleRate * 1000)
            
            if totalFrames == self.lastReportedFrames {
                self.stalledTicks += 1
            } else {
                self.stalledTicks = 0
            }
            self.lastReportedFrames = totalFrames
            
            // Il timer è l'unica autorità per il completamento del playback.
            // Attendiamo che il player frame arrivi alla fine, oppure che il callback
            // sia scattato E il playerNode si sia fermato (stalledTicks > 2).
            // Questo impedisce al timer di forzare la fine prematuramente causando salti UI,
            // poiché il callback di scheduleFile scatta prima che l'audio sia fisicamente uscito.
            let marginFrames = Int64(sampleRate * 0.1) // 100ms margin
            if totalFrames >= file.length - marginFrames || (self.playbackFinished && self.stalledTicks > 2) {
                // Non forziamo più l'ultimo tick alla durata totale per evitare il salto visivo nella UI.
                // Inviamo l'ultima posizione reale nota. La UI (Dart) si preoccuperà di gestire la fine.
                self.clockStreamHandler.sendPlaybackTick(positionMs: positionMs, durationMs: durationMs)
                // Segnala il completamento
                self.logger.info("🔊 [NATIVE] Playback completed via clock (position reached end or stalled after callback) at \(positionMs)ms")
                self.isPlaying = false
                self.stopPlaybackClock()
                self.playbackStreamHandler.sendPlaybackComplete()
                return
            }
            
            self.clockStreamHandler.sendPlaybackTick(positionMs: positionMs, durationMs: durationMs)
        }
        timer.resume()
        playbackClockTimer = timer
    }

    private func stopPlaybackClock() {
        playbackClockTimer?.cancel()
        playbackClockTimer = nil
    }

    // MARK: - Helpers

    /// Concatenazione PCM lossless per segmenti WAV (Approccio 1).
    private func concatenatePCMFiles(_ paths: [String], into outputPath: String, settings: [String: Any], completion: @escaping (Error?) -> Void) {
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

    private func durationOf(path: String) -> Double {
        guard let f = try? AVAudioFile(forReading: URL(fileURLWithPath: path)) else { return 0 }
        return Double(f.length) / f.fileFormat.sampleRate
    }

    // MARK: - WAV → Format Conversion (Approccio 1)

    /// Converte un file WAV al formato finale richiesto dall'utente.
    /// - M4A: AVAssetExportSession con preset AppleM4A (singolo passaggio AAC)
    /// - FLAC: AVAudioConverter PCM → FLAC buffer-by-buffer
    private func convertWAVToFormat(wavPath: String, outputPath: String, format: String, settings: [String: Any]?, completion: @escaping (Error?) -> Void) {
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
    private func convertWAVToM4A(wavPath: String, outputPath: String, completion: @escaping (Error?) -> Void) {
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
    private func convertWAVToFLAC(wavPath: String, outputPath: String, settings: [String: Any], completion: @escaping (Error?) -> Void) {
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
    private func buildRecordingSettings(format: String, sampleRate: Int, bitRate: Int) -> [String: Any] {
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
    private func validateRecordingSettings(_ settings: [String: Any], format: String) -> Bool {
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
    private func registerInterruptionObserver() {
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
                try? AVAudioSession.sharedInstance().setActive(true)
            }
            // Non fa auto-resume della registrazione: l'utente decide quando riprendere.

        @unknown default:
            self.logger.debug("🔔 [NATIVE] Interruzione tipo sconosciuto: \(typeValue)")
        }
    }

    // MARK: - Audio Session Configuration

    private func setAudioSessionCategory(category: String, options: [String], result: @escaping FlutterResult) {
        sessionCategory = parseCategory(category)
        sessionOptions = parseOptions(options)
        self.logger.debug("🔧 [NATIVE] setAudioSessionCategory: \(sessionCategory.rawValue) options=\(sessionOptions.rawValue)")
        do {
            try AVAudioSession.sharedInstance().setCategory(sessionCategory, mode: .default, options: sessionOptions)
            result(true)
        } catch {
            self.logger.error("🔧 [NATIVE] setAudioSessionCategory ERROR: \(error)")
            result(FlutterError(code: "SESSION_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func parseCategory(_ cat: String) -> AVAudioSession.Category {
        let map: [String: AVAudioSession.Category] = [
            "playAndRecord": .playAndRecord, "record": .record, "playback": .playback,
            "ambient": .ambient, "soloAmbient": .soloAmbient, "multiRoute": .multiRoute
        ]
        return map[cat] ?? .playAndRecord
    }

    private func parseOptions(_ opts: [String]) -> AVAudioSession.CategoryOptions {
        let map: [String: AVAudioSession.CategoryOptions] = [
            "defaultToSpeaker": .defaultToSpeaker, "allowBluetooth": .allowBluetooth,
            "allowBluetoothA2DP": .allowBluetoothA2DP, "mixWithOthers": .mixWithOthers,
            "duckOthers": .duckOthers, "allowAirPlay": .allowAirPlay
        ]
        return opts.reduce(into: AVAudioSession.CategoryOptions()) { r, o in if let v = map[o] { r.insert(v) } }
    }

    // MARK: - Voice Processing

    private func setVoiceProcessing(enabled: Bool, result: @escaping FlutterResult) {
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
