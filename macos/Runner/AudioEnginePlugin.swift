// File: macos/Runner/AudioEnginePlugin.swift
// AVAudioEngine recorder con playback simultaneo per macOS.
// Adattamento del plugin iOS — senza AVAudioSession (macOS non lo usa).

import Cocoa
import FlutterMacOS
import AVFoundation
import Logging

// Event Channel per notificare Dart del completamento del playback.
class PlaybackStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    func sendPlaybackComplete() {
        eventSink?(["event": "playbackCompleted"])
    }
}

// Event Channel per i tick di clock recording/playback su macOS.
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

    func sendRecordingTick(positionMs: Int, amplitude: Double) {
        eventSink?(["type": "recordingTick", "positionMs": positionMs, "amplitude": amplitude])
    }

    func sendPlaybackTick(positionMs: Int, durationMs: Int) {
        eventSink?(["type": "playbackTick", "positionMs": positionMs, "durationMs": durationMs])
    }
}

public class AudioEnginePlugin: NSObject, FlutterPlugin {

    let logger = Logger(label: "com.wavnote.macos.audio_engine")
    let playbackStreamHandler = PlaybackStreamHandler()
    let clockStreamHandler = ClockStreamHandler()

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var recordingPCMConverter: RecordingPCMConverter?
    private var audioFile: AVAudioFile?
    var playbackEngine: AVAudioEngine?
    var audioPlayer: AVAudioPlayerNode?
    var audioFileForPlayback: AVAudioFile?

    var isRecording = false
    var isPaused = false
    var isPlaying = false
    var isPlaybackPaused = false
    /// Incrementato ad ogni nuova sessione di playback (startPlayback o seekTo).
    /// I completion handler confrontano la propria generazione con quella corrente:
    /// se diversa, il handler è orfano (da un vecchio segmento) e va ignorato.
    var playbackGeneration: Int = 0

    private var recordingFilePath: String?
    var recordingSettings: [String: Any]?
    var recordingSegments: [String] = []
    private var recordingFormat: String = "wav"
    private var requestedFormat: String = "m4a"
    private var requestedOutputPath: String?
    private var requestedFormatSettings: [String: Any]?
    var playbackTempPath: String?
    private var currentAmplitude: Float = 0.0
    /// Frame di inizio del segmento schedulato (usato per calcolare la posizione di playback corretta dopo seekTo).
    var seekOffsetFrames: Int64 = 0

    private var voiceProcessingEnabled = false
    private static let maxSampleRate = 48000
    private var lastClockEmitTime: CFTimeInterval = 0
    var playbackClockTimer: DispatchSourceTimer?

    /// Frame scritti nei segmenti già chiusi (accumulati attraverso pause/resume).
    private var framesInPreviousSegments: Int64 = 0
    /// Frame scritti nel segmento corrente (resettato a ogni nuovo file).
    private var framesWrittenThisSegment: Int64 = 0
    /// Sample rate del file WAV di output (impostato a startRecording).
    private var outputSampleRate: Double = 44100

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.wavnote/audio_engine",
            binaryMessenger: registrar.messenger
        )
        let instance = AudioEnginePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        let playbackEventChannel = FlutterEventChannel(
            name: "com.wavnote/audio_engine/playback_events",
            binaryMessenger: registrar.messenger
        )
        playbackEventChannel.setStreamHandler(instance.playbackStreamHandler)

        let clockEventChannel = FlutterEventChannel(
            name: "com.wavnote/audio_engine/clock_events",
            binaryMessenger: registrar.messenger
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
                result(Int(durationOf(path: path) * 1000))
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
            // macOS non ha AVAudioSession — no-op
            result(true)
        case "setVoiceProcessing":
            if let args = call.arguments as? [String: Any],
               let enabled = args["enabled"] as? Bool {
                setVoiceProcessing(enabled: enabled, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing enabled", details: nil))
            }
        case "checkMicPermission":
            checkMicPermission(result: result)
        case "requestMicPermission":
            requestMicPermission(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Initialize

    private func initialize(result: @escaping FlutterResult) {
        self.logger.debug("🔧 [NATIVE-macOS] initialize — isRecording=\(isRecording) isPaused=\(isPaused)")
        if isRecording || isPaused {
            self.logger.debug("🔧 [NATIVE-macOS] initialize: motore già attivo, skip")
            result(true)
            return
        }

        // macOS: verifica permesso microfono
        if #available(macOS 10.14, *) {
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            self.logger.debug("🔧 [NATIVE-macOS] mic authStatus=\(status.rawValue)")

            switch status {
            case .authorized:
                // Già autorizzato — procedi direttamente
                setupEngine(result: result)
            case .notDetermined:
                // Prima volta — chiedi permesso su background thread
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    AVCaptureDevice.requestAccess(for: .audio) { granted in
                        DispatchQueue.main.async {
                            guard let self = self else { return }
                            self.logger.debug("🔧 [NATIVE-macOS] requestAccess: granted=\(granted)")
                            if granted {
                                self.setupEngine(result: result)
                            } else {
                                result(FlutterError(code: "PERMISSION_DENIED",
                                    message: "Microphone permission denied", details: nil))
                            }
                        }
                    }
                }
            default:
                // Denied o restricted
                result(FlutterError(code: "PERMISSION_DENIED",
                    message: "Microphone permission denied. Grant access in System Settings → Privacy & Security → Microphone",
                    details: nil))
            }
        } else {
            setupEngine(result: result)
        }
    }

    private func setupEngine(result: @escaping FlutterResult) {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode
        audioPlayer = AVAudioPlayerNode()

        if let input = inputNode {
            let format = input.outputFormat(forBus: 0)
            self.logger.debug("🔧 [NATIVE-macOS] inputNode sampleRate=\(format.sampleRate) ch=\(format.channelCount)")
        } else {
            self.logger.warning("🔧 [NATIVE-macOS] ⚠️ inputNode è nil!")
        }

        self.logger.info("🔧 [NATIVE-macOS] initialize: OK")
        result(true)
    }

    // MARK: - Recording

    private func startRecording(path: String, sampleRate: Int, bitRate: Int, format: String, result: @escaping FlutterResult) {
        let cappedSampleRate = min(sampleRate, AudioEnginePlugin.maxSampleRate)
        self.logger.debug("🎙️ [NATIVE-macOS] startRecording — path=\(path) format=\(format) sr=\(cappedSampleRate)")
        guard audioEngine != nil, inputNode != nil else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "AudioEngine not initialized", details: nil))
            return
        }
        let input = inputNode!
        do {
            let fileURL = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            // Approccio 1: registra sempre in WAV internamente
            requestedFormat = format
            requestedOutputPath = path
            recordingFormat = "wav"

            if format != "wav" {
                let finalSettings = buildRecordingSettings(format: format, sampleRate: cappedSampleRate, bitRate: bitRate)
                if !validateRecordingSettings(finalSettings, format: format) {
                    result(FlutterError(code: "FORMAT_ERROR",
                        message: "Audio format '\(format)' with sampleRate \(cappedSampleRate) is not supported",
                        details: nil))
                    return
                }
                requestedFormatSettings = finalSettings
            } else {
                requestedFormatSettings = nil
            }

            let wavSettings = buildRecordingSettings(format: "wav", sampleRate: cappedSampleRate, bitRate: bitRate)
            recordingSettings = wavSettings
            recordingSegments = []
            framesInPreviousSegments = 0
            framesWrittenThisSegment = 0
            lastClockEmitTime = 0

            let wavURL = fileURL.deletingPathExtension().appendingPathExtension("wav")
            let wavPath = wavURL.path
            self.logger.debug("🎙️ [NATIVE-macOS] startRecording: interno WAV → \(wavPath) (formato finale: \(format))")

            audioFile = try AVAudioFile(forWriting: wavURL, settings: wavSettings)
            recordingFilePath = wavPath

            let rawFormat = input.outputFormat(forBus: 0)
            self.logger.debug("🎙️ [NATIVE-macOS] rawFormat — sampleRate=\(rawFormat.sampleRate) ch=\(rawFormat.channelCount)")

            let inputFormat: AVAudioFormat
            if rawFormat.channelCount == 0 || rawFormat.sampleRate == 0 {
                self.logger.debug("🎙️ [NATIVE-macOS] formato invalido, ricreo engine...")
                audioEngine?.stop()
                audioEngine = AVAudioEngine()
                inputNode = audioEngine?.inputNode
                guard let newInput = inputNode else {
                    result(FlutterError(code: "ENGINE_ERROR", message: "Failed to recreate audio engine", details: nil))
                    return
                }
                let retryFormat = newInput.outputFormat(forBus: 0)
                if retryFormat.channelCount == 0 || retryFormat.sampleRate == 0 {
                    result(FlutterError(code: "NO_MIC_ACCESS",
                        message: "Microphone not accessible. Grant mic permission in System Settings → Privacy & Security → Microphone",
                        details: nil))
                    return
                }
                inputFormat = retryFormat
            } else {
                inputFormat = rawFormat
            }

            let outputFormat = audioFile!.processingFormat
            outputSampleRate = outputFormat.sampleRate
            logger.debug("Registrazione PCM: input=\(inputFormat.sampleRate) Hz, output=\(outputFormat.sampleRate) Hz")
            recordingPCMConverter = inputFormat.isEqual(outputFormat)
                ? nil : try RecordingPCMConverter(from: inputFormat, to: outputFormat)

            var bufferCount = 0
            let tapInput = inputNode!

            // FIX: Rimuove esplicitamente qualsiasi tap precedente per evitare il crash 'nullptr == Tap()'
            tapInput.removeTap(onBus: 0)

            tapInput.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
                guard let self = self, self.audioFile != nil else { return }
                bufferCount += 1
                let shouldLog = bufferCount % 100 == 1
                if shouldLog {
                    self.logger.trace("🎙️ [NATIVE-macOS] tap buffer #\(bufferCount) — frames=\(buffer.frameLength)")
                }
                var writtenOutputFrames: Int64 = 0
                do {
                    guard let file = self.audioFile else { return }
                    if let converter = self.recordingPCMConverter {
                        writtenOutputFrames = try converter.convert(buffer) { output in
                            try file.write(from: output)
                        }
                    } else {
                        try file.write(from: buffer)
                        writtenOutputFrames = Int64(buffer.frameLength)
                    }
                } catch {
                    self.logger.error("🎙️ [NATIVE-macOS] tap write ERROR: \(error)")
                }
                self.framesWrittenThisSegment += writtenOutputFrames
                if let ch = buffer.floatChannelData?[0] {
                    let n = Int(buffer.frameLength)
                    var sq: Float = 0
                    for i in 0..<n { sq += ch[i] * ch[i] }
                    let amp = min(sqrt(sq / Float(max(n, 1))) * 10.0, 1.0)
                    self.currentAmplitude = amp

                    let now = CFAbsoluteTimeGetCurrent()
                    if now - self.lastClockEmitTime >= 0.1 {
                        self.lastClockEmitTime = now
                        let totalFrames = self.framesInPreviousSegments + self.framesWrittenThisSegment
                        let positionMs = Int(Double(totalFrames) / self.outputSampleRate * 1000)
                        self.clockStreamHandler.sendRecordingTick(
                            positionMs: positionMs,
                            amplitude: Double(amp)
                        )
                    }
                }
            }

            if voiceProcessingEnabled {
                if #available(macOS 10.14, *) {
                    try tapInput.setVoiceProcessingEnabled(true)
                    self.logger.debug("🎙️ [NATIVE-macOS] voice processing abilitato")
                }
            }

            try audioEngine!.start()
            isRecording = true
            isPaused = false
            self.logger.info("🎙️ [NATIVE-macOS] startRecording: OK — engine running")
            result(true)
        } catch {
            self.logger.error("🎙️ [NATIVE-macOS] startRecording ERROR: \(error)")
            result(FlutterError(code: "RECORD_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func finishRecordingConversion() throws {
        guard let file = audioFile, let converter = recordingPCMConverter else { return }
        framesWrittenThisSegment += try converter.finish { try file.write(from: $0) }
    }

    private func pauseRecording(result: @escaping FlutterResult) {
        guard isRecording, !isPaused else {
            result(FlutterError(code: "INVALID_STATE", message: "Not recording or already paused", details: nil))
            return
        }
        // Log frames scritti PRIMA di chiudere il file
        if let file = audioFile {
            let sr = file.processingFormat.sampleRate
            let frames = file.length
            self.logger.debug("⏸️ [NATIVE-macOS] pauseRecording: PRIMA chiusura — frames=\(frames) (\(Double(frames)/sr)s ≈ \(Int((Double(frames)/sr)*10)) bars@100ms)")
        }
        audioEngine?.pause()
        do { try finishRecordingConversion() }
        catch {
            result(FlutterError(code: "CONVERSION_ERROR", message: error.localizedDescription, details: nil))
            return
        }
        if let path = recordingFilePath {
            framesInPreviousSegments += framesWrittenThisSegment
            framesWrittenThisSegment = 0
            audioFile = nil   // ARC chiude il file → header WAV aggiornato
            recordingSegments.append(path)
            // Riapri in lettura per verificare che il file sia stato chiuso correttamente
            if let readFile = try? AVAudioFile(forReading: URL(fileURLWithPath: path)) {
                let sr = readFile.processingFormat.sampleRate
                let frames = readFile.length
                self.logger.debug("⏸️ [NATIVE-macOS] pauseRecording: DOPO chiusura — frames=\(frames) (\(Double(frames)/sr)s ≈ \(Int((Double(frames)/sr)*10)) bars@100ms) segmenti=\(recordingSegments.count)")
            }
            if let attrs = try? FileManager.default.attributesOfItem(atPath: path) {
                self.logger.debug("⏸️ [NATIVE-macOS] pauseRecording: size=\(attrs[.size] ?? 0) bytes")
            }
        }
        isPaused = true
        currentAmplitude = 0.0
        result(true)
    }

    private func resumeRecording(result: @escaping FlutterResult) {
        guard isRecording, isPaused else {
            result(FlutterError(code: "INVALID_STATE", message: "Not paused", details: nil))
            return
        }
        do {
            guard let settings = recordingSettings else {
                result(FlutterError(code: "RESUME_ERROR", message: "No recording settings available", details: nil))
                return
            }
            
            let baseURL = URL(fileURLWithPath: recordingSegments.first ?? "")
            let contPath = baseURL.deletingPathExtension().path + "_cnt\(recordingSegments.count)." + baseURL.pathExtension
            self.logger.debug("▶️ [NATIVE-macOS] resumeRecording: nuovo frammento → \(contPath)")
            audioFile = try AVAudioFile(forWriting: URL(fileURLWithPath: contPath), settings: settings)
            recordingFilePath = contPath
            framesWrittenThisSegment = 0
            lastClockEmitTime = 0
            try audioEngine?.start()
            isPaused = false
            result(true)
        } catch {
            self.logger.error("▶️ [NATIVE-macOS] resumeRecording ERROR: \(error)")
            result(FlutterError(code: "RESUME_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func stopRecording(raw: Bool = false, result: @escaping FlutterResult) {
        self.logger.debug("⏹️ [NATIVE-macOS] stopRecording — raw=\(raw) segmenti=\(recordingSegments.count)")
        guard isRecording else {
            result(FlutterError(code: "INVALID_STATE", message: "Not recording", details: nil))
            return
        }
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        do { try finishRecordingConversion() }
        catch {
            result(FlutterError(code: "CONVERSION_ERROR", message: error.localizedDescription, details: nil))
            return
        }
        recordingPCMConverter = nil
        if let path = recordingFilePath, audioFile != nil {
            audioFile = nil
            recordingSegments.append(path)
        } else {
            audioFile = nil
        }
        recordingFilePath = nil
        isRecording = false
        isPaused = false
        currentAmplitude = 0.0
        framesInPreviousSegments = 0
        framesWrittenThisSegment = 0

        guard !recordingSegments.isEmpty else {
            recordingSettings = nil
            result(FlutterError(code: "NO_DATA", message: "No recording data", details: nil))
            return
        }

        let wavSettings = recordingSettings ?? [:]
        let finalFormat = requestedFormat
        let finalOutputPath = requestedOutputPath ?? recordingSegments[0]
        let all = recordingSegments
        recordingSegments = []
        recordingSettings = nil

        let singleSegment = all.count == 1

        let afterWAVReady: (String) -> Void = { [weak self] wavPath in
            guard let self = self else { return }
            if raw {
                self.finishWithFile(wavPath, outputPath: wavPath, segments: all, result: result)
                return
            }
            if finalFormat == "wav" {
                self.finishWithFile(wavPath, outputPath: finalOutputPath, segments: all, result: result)
            } else {
                self.convertWAVToFormat(wavPath: wavPath, outputPath: finalOutputPath,
                    format: finalFormat, settings: self.requestedFormatSettings) { error in
                    if let error = error {
                        self.logger.error("⏹️ [NATIVE-macOS] conversione FALLITA — \(error)")
                        self.finishWithFile(wavPath, outputPath: wavPath, segments: all, result: result)
                    } else {
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

    private func finishWithFile(_ path: String, outputPath: String, segments: [String], result: @escaping FlutterResult) {
        if path != outputPath {
            do {
                let fm = FileManager.default
                if fm.fileExists(atPath: outputPath) { try fm.removeItem(atPath: outputPath) }
                try fm.moveItem(atPath: path, toPath: outputPath)
            } catch {
                self.logger.error("⏹️ [NATIVE-macOS] finishWithFile: move ERROR — \(error)")
            }
        }
        let dur = durationOf(path: outputPath)
        requestedFormatSettings = nil
        requestedOutputPath = nil
        result(["path": outputPath, "duration": dur * 1000])
    }

    private func cancelRecording(result: @escaping FlutterResult) {
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        recordingPCMConverter = nil
        audioFile = nil
        audioPlayer?.stop()
        stopPlaybackClockTimer()
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

    private func getRecordingStatus(result: @escaping FlutterResult) {
        let durationMs = Int(Double(framesInPreviousSegments + framesWrittenThisSegment) / outputSampleRate * 1000)
        result([
            "isRecording": isRecording,
            "isPaused": isPaused,
            "path": recordingFilePath ?? NSNull(),
            "durationMs": durationMs,
            "amplitude": Double(currentAmplitude)
        ])
    }

    // MARK: - Standalone Format Conversion

    private func convertAudio(wavPath: String, outputPath: String, format: String, result: @escaping FlutterResult) {
        self.logger.debug("🔄 [NATIVE-macOS] convertAudio — \(wavPath) → \(outputPath) formato=\(format)")
        if format == "wav" {
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
        guard let wavFile = try? AVAudioFile(forReading: URL(fileURLWithPath: wavPath)) else {
            result(FlutterError(code: "FILE_ERROR", message: "Cannot read WAV file", details: nil))
            return
        }
        let sampleRate = Int(wavFile.fileFormat.sampleRate)
        let settings = buildRecordingSettings(format: format, sampleRate: sampleRate, bitRate: 128000)
        convertWAVToFormat(wavPath: wavPath, outputPath: outputPath, format: format, settings: settings) { [weak self] error in
            if let error = error {
                result(FlutterError(code: "CONVERT_ERROR", message: error.localizedDescription, details: nil))
            } else {
                let dur = self?.durationOf(path: outputPath) ?? 0
                result(["path": outputPath, "duration": dur * 1000])
            }
        }
    }

    // MARK: - Microphone Permission (macOS native)

    private func checkMicPermission(result: @escaping FlutterResult) {
        if #available(macOS 10.14, *) {
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            self.logger.debug("🔐 [NATIVE-macOS] checkMicPermission — status rawValue=\(status.rawValue)")
            
            // DEBUG: Log dettagliato
            #if DEBUG
            let statusDesc: String
            switch status {
            case .authorized: statusDesc = "authorized ✅"
            case .notDetermined: statusDesc = "notDetermined 📢"
            case .denied: statusDesc = "denied ❌"
            case .restricted: statusDesc = "restricted ⚠️"
            @unknown default: statusDesc = "unknown"
            }
            self.logger.debug("🔐 [NATIVE-macOS] 📋 Status: \(statusDesc)")
            #endif
            
            switch status {
            case .authorized:    result("authorized")
            case .notDetermined: result("notDetermined")
            case .denied:        result("denied")
            case .restricted:    result("restricted")
            @unknown default:    result("denied")
            }
        } else {
            result("authorized")
        }
    }

    private func requestMicPermission(result: @escaping FlutterResult) {
        if #available(macOS 10.14, *) {
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            self.logger.debug("🔐 [NATIVE-macOS] requestMicPermission — currentStatus=\(status.rawValue)")
            
            // DEBUG: Log dettagliato per troubleshoot
            #if DEBUG
            let statusDescription: String
            switch status {
            case .authorized: statusDescription = "authorized (già concesso)"
            case .notDetermined: statusDescription = "notDetermined (richiederò dialogo)"
            case .denied: statusDescription = "denied (negato - manuale)"
            case .restricted: statusDescription = "restricted (limitato sistema)"
            @unknown default: statusDescription = "unknown"
            }
            self.logger.debug("🔐 [NATIVE-macOS] ⚡️ Status: \(statusDescription)")
            #endif
            
            switch status {
            case .authorized:
                self.logger.info("🔐 [NATIVE-macOS] ✅ Già autorizzato, ritorno true")
                result(true)
            case .notDetermined:
                self.logger.debug("🔐 [NATIVE-macOS] 📢 Mostro dialogo richiesta permesso...")
                DispatchQueue.global(qos: .userInitiated).async {
                    AVCaptureDevice.requestAccess(for: .audio) { granted in
                        DispatchQueue.main.async {
                            self.logger.debug("🔐 [NATIVE-macOS] 📢 Dialogo risposto: granted=\(granted)")
                            if granted {
                                self.logger.info("🔐 [NATIVE-macOS] ✅ Permesso CONCESSO!")
                            } else {
                                self.logger.error("🔐 [NATIVE-macOS] ❌ Permesso NEGATO!")
                            }
                            result(granted)
                        }
                    }
                }
            case .denied:
                self.logger.error("🔐 [NATIVE-macOS] ❌ Permesso negato. Utente deve andare in Preferenze Sistema > Privacy > Microfono")
                result(false)
            case .restricted:
                self.logger.error("🔐 [NATIVE-macOS] ❌ Permesso restrict (controllo genitori/dispositivo)")
                result(false)
            @unknown default:
                self.logger.warning("🔐 [NATIVE-macOS] ⚠️ Status sconosciuto, torno false")
                result(false)
            }
        } else {
            self.logger.debug("🔐 [NATIVE-macOS] macOS < 10.14, ritorno true")
            result(true)
        }
    }

    // MARK: - Voice Processing

    private func setVoiceProcessing(enabled: Bool, result: @escaping FlutterResult) {
        voiceProcessingEnabled = enabled
        self.logger.debug("🎤 [NATIVE-macOS] Voice processing: \(enabled ? "ON" : "OFF")")
        if let input = inputNode, isRecording {
            if #available(macOS 10.14, *) {
                do { try input.setVoiceProcessingEnabled(enabled); result(true) }
                catch { result(FlutterError(code: "VP_ERROR", message: error.localizedDescription, details: nil)) }
                return
            } else {
                result(FlutterError(code: "VP_UNSUPPORTED", message: "Requires macOS 10.14+", details: nil))
                return
            }
        }
        result(true)
    }
}
