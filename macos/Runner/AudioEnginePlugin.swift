// File: macos/Runner/AudioEnginePlugin.swift
// AVAudioEngine recorder con playback simultaneo per macOS.
// Adattamento del plugin iOS — senza AVAudioSession (macOS non lo usa).

import Cocoa
import FlutterMacOS
import AVFoundation

public class AudioEnginePlugin: NSObject, FlutterPlugin {
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
    /// Incrementato ad ogni nuova sessione di playback (startPlayback o seekTo).
    /// I completion handler confrontano la propria generazione con quella corrente:
    /// se diversa, il handler è orfano (da un vecchio segmento) e va ignorato.
    private var playbackGeneration: Int = 0

    private var recordingFilePath: String?
    private var recordingSettings: [String: Any]?
    private var recordingSegments: [String] = []
    private var recordingFormat: String = "wav"
    private var requestedFormat: String = "m4a"
    private var requestedOutputPath: String?
    private var requestedFormatSettings: [String: Any]?
    private var playbackTempPath: String?
    private var currentAmplitude: Float = 0.0
    /// Frame di inizio del segmento schedulato (usato per calcolare la posizione di playback corretta dopo seekTo).
    private var seekOffsetFrames: Int64 = 0

    private var voiceProcessingEnabled = false
    private static let maxSampleRate = 48000

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.wavnote/audio_engine",
            binaryMessenger: registrar.messenger
        )
        let instance = AudioEnginePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
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
                startPlayback(path: path, result: result)
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
        case "getAmplitude":
            result(currentAmplitude)
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
        NSLog("🔧 [NATIVE-macOS] initialize — isRecording=\(isRecording) isPaused=\(isPaused)")
        if isRecording || isPaused {
            NSLog("🔧 [NATIVE-macOS] initialize: motore già attivo, skip")
            result(true)
            return
        }

        // macOS: verifica permesso microfono
        if #available(macOS 10.14, *) {
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            NSLog("🔧 [NATIVE-macOS] mic authStatus=\(status.rawValue)")

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
                            NSLog("🔧 [NATIVE-macOS] requestAccess: granted=\(granted)")
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
            NSLog("🔧 [NATIVE-macOS] inputNode sampleRate=\(format.sampleRate) ch=\(format.channelCount)")
        } else {
            NSLog("🔧 [NATIVE-macOS] ⚠️ inputNode è nil!")
        }

        NSLog("🔧 [NATIVE-macOS] initialize: OK")
        result(true)
    }

    // MARK: - Recording

    private func startRecording(path: String, sampleRate: Int, bitRate: Int, format: String, result: @escaping FlutterResult) {
        let cappedSampleRate = min(sampleRate, AudioEnginePlugin.maxSampleRate)
        NSLog("🎙️ [NATIVE-macOS] startRecording — path=\(path) format=\(format) sr=\(cappedSampleRate)")
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

            let wavURL = fileURL.deletingPathExtension().appendingPathExtension("wav")
            let wavPath = wavURL.path
            NSLog("🎙️ [NATIVE-macOS] startRecording: interno WAV → \(wavPath) (formato finale: \(format))")

            audioFile = try AVAudioFile(forWriting: wavURL, settings: wavSettings)
            recordingFilePath = wavPath

            let rawFormat = input.outputFormat(forBus: 0)
            NSLog("🎙️ [NATIVE-macOS] rawFormat — sampleRate=\(rawFormat.sampleRate) ch=\(rawFormat.channelCount)")

            let inputFormat: AVAudioFormat
            if rawFormat.channelCount == 0 || rawFormat.sampleRate == 0 {
                NSLog("🎙️ [NATIVE-macOS] formato invalido, ricreo engine...")
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
            var converter: AVAudioConverter? = nil
            if !inputFormat.isEqual(outputFormat) {
                converter = AVAudioConverter(from: inputFormat, to: outputFormat)
                if converter == nil {
                    result(FlutterError(code: "FORMAT_ERROR", message: "Cannot create audio format converter", details: nil))
                    return
                }
            }

            var bufferCount = 0
            let tapInput = inputNode!

            tapInput.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
                guard let self = self, self.audioFile != nil else { return }
                bufferCount += 1
                let shouldLog = bufferCount % 100 == 1
                if shouldLog {
                    NSLog("🎙️ [NATIVE-macOS] tap buffer #\(bufferCount) — frames=\(buffer.frameLength)")
                }
                do {
                    if let converter = converter {
                        let pcmBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: buffer.frameCapacity)
                        var error: NSError? = nil
                        converter.convert(to: pcmBuffer!, error: &error) { _, outStatus in
                            outStatus.pointee = .haveData
                            return buffer
                        }
                        if let err = error {
                            NSLog("🎙️ [NATIVE-macOS] converter ERROR: \(err)")
                        } else if let pcmBuffer = pcmBuffer {
                            try self.audioFile?.write(from: pcmBuffer)
                        }
                    } else {
                        try self.audioFile?.write(from: buffer)
                    }
                } catch {
                    NSLog("🎙️ [NATIVE-macOS] tap write ERROR: \(error)")
                }
                if let ch = buffer.floatChannelData?[0] {
                    let n = Int(buffer.frameLength)
                    var sq: Float = 0
                    for i in 0..<n { sq += ch[i] * ch[i] }
                    let amp = min(sqrt(sq / Float(max(n, 1))) * 10.0, 1.0)
                    self.currentAmplitude = amp
                }
            }

            if voiceProcessingEnabled {
                if #available(macOS 10.14, *) {
                    try tapInput.setVoiceProcessingEnabled(true)
                    NSLog("🎙️ [NATIVE-macOS] voice processing abilitato")
                }
            }

            try audioEngine!.start()
            isRecording = true
            isPaused = false
            NSLog("🎙️ [NATIVE-macOS] startRecording: OK — engine running")
            result(true)
        } catch {
            NSLog("🎙️ [NATIVE-macOS] startRecording ERROR: \(error)")
            result(FlutterError(code: "RECORD_ERROR", message: error.localizedDescription, details: nil))
        }
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
            NSLog("⏸️ [NATIVE-macOS] pauseRecording: PRIMA chiusura — frames=\(frames) (\(Double(frames)/sr)s ≈ \(Int((Double(frames)/sr)*10)) bars@100ms)")
        }
        audioEngine?.pause()
        if let path = recordingFilePath {
            audioFile = nil   // ARC chiude il file → header WAV aggiornato
            recordingSegments.append(path)
            // Riapri in lettura per verificare che il file sia stato chiuso correttamente
            if let readFile = try? AVAudioFile(forReading: URL(fileURLWithPath: path)) {
                let sr = readFile.processingFormat.sampleRate
                let frames = readFile.length
                NSLog("⏸️ [NATIVE-macOS] pauseRecording: DOPO chiusura — frames=\(frames) (\(Double(frames)/sr)s ≈ \(Int((Double(frames)/sr)*10)) bars@100ms) segmenti=\(recordingSegments.count)")
            }
            if let attrs = try? FileManager.default.attributesOfItem(atPath: path) {
                NSLog("⏸️ [NATIVE-macOS] pauseRecording: size=\(attrs[.size] ?? 0) bytes")
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
            guard let settings = recordingSettings, let first = recordingSegments.first else {
                result(FlutterError(code: "RESUME_ERROR", message: "No recording settings available", details: nil))
                return
            }
            let baseURL = URL(fileURLWithPath: first)
            let contPath = baseURL.deletingPathExtension().path + "_cnt\(recordingSegments.count)." + baseURL.pathExtension
            NSLog("▶️ [NATIVE-macOS] resumeRecording: nuovo file → \(contPath)")
            audioFile = try AVAudioFile(forWriting: URL(fileURLWithPath: contPath), settings: settings)
            recordingFilePath = contPath
            try audioEngine?.start()
            isPaused = false
            result(true)
        } catch {
            NSLog("▶️ [NATIVE-macOS] resumeRecording ERROR: \(error)")
            result(FlutterError(code: "RESUME_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func stopRecording(raw: Bool = false, result: @escaping FlutterResult) {
        NSLog("⏹️ [NATIVE-macOS] stopRecording — raw=\(raw) segmenti=\(recordingSegments.count)")
        guard isRecording else {
            result(FlutterError(code: "INVALID_STATE", message: "Not recording", details: nil))
            return
        }
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
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
                        NSLog("⏹️ [NATIVE-macOS] conversione FALLITA — \(error)")
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
                NSLog("⏹️ [NATIVE-macOS] finishWithFile: move ERROR — \(error)")
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
        result(true)
    }

    // MARK: - Standalone Format Conversion

    private func convertAudio(wavPath: String, outputPath: String, format: String, result: @escaping FlutterResult) {
        NSLog("🔄 [NATIVE-macOS] convertAudio — \(wavPath) → \(outputPath) formato=\(format)")
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

    // MARK: - Playback

    private func startPlayback(path: String, result: @escaping FlutterResult) {
        if isRecording && !isPaused {
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
                self.startPlaybackInternal(path: tempPath, result: result)
            }
        } else if isRecording && isPaused {
            startPlaybackFromSegments(result: result)
        } else {
            startPlaybackInternal(path: path, result: result)
        }
    }

    private func startPlaybackFromSegments(result: @escaping FlutterResult) {
        guard !recordingSegments.isEmpty else {
            result(FlutterError(code: "NO_SEGMENTS", message: "No recording segments available", details: nil))
            return
        }
        if recordingSegments.count == 1 {
            startPlaybackInternal(path: recordingSegments[0], result: result)
        } else {
            let tempDir = NSTemporaryDirectory()
            let tempPath = tempDir + "wavnote_pb_\(Int(Date().timeIntervalSince1970 * 1000)).wav"
            let savedSettings = recordingSettings ?? [:]
            let segs = recordingSegments
            concatenatePCMFiles(segs, into: tempPath, settings: savedSettings) { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    NSLog("▶️ [NATIVE-macOS] playbackFromSegments CONCAT ERROR: \(error)")
                    self.startPlaybackInternal(path: self.recordingSegments[0], result: result)
                } else {
                    self.playbackTempPath = tempPath
                    self.startPlaybackInternal(path: tempPath, result: result)
                }
            }
        }
    }

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
                completion(nil, NSError(domain: "WavNote", code: -2,
                    userInfo: [NSLocalizedDescriptionKey: session.error?.localizedDescription ?? "Export failed"]))
            }
        }
    }

    private func startPlaybackInternal(path: String, result: @escaping FlutterResult) {
        NSLog("🔊 [NATIVE-macOS] startPlaybackInternal — path=\(path)")
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
            let srPb = file.processingFormat.sampleRate
            NSLog("🔊 [NATIVE-macOS] startPlaybackInternal: file.length=\(file.length) (\(Double(file.length)/srPb)s ≈ \(Int((Double(file.length)/srPb)*10)) bars@100ms)")
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
            player.scheduleFile(file, at: nil) { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self, self.playbackGeneration == gen else { return }
                    self.isPlaying = false
                }
            }
            seekOffsetFrames = 0
            try engine.start()
            player.play()
            isPlaying = true
            isPlaybackPaused = false
            result(true)
        } catch {
            NSLog("🔊 [NATIVE-macOS] startPlaybackInternal ERROR: \(error)")
            result(FlutterError(code: "PLAYBACK_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func stopPlayback(result: @escaping FlutterResult) {
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
        audioPlayer?.pause()
        isPlaying = false
        result(true)
    }

    private func resumePlayback(result: @escaping FlutterResult) {
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
        // Clamp: l'ultima barra waveform può mappare esattamente a file.length frame.
        // Riduciamo al frame precedente per evitare il reject del guard originale.
        let framePosition = min(rawFramePosition, file.length > 0 ? file.length - 1 : 0)
        let frameCount = max(1, AVAudioFrameCount(file.length - framePosition))
        NSLog("🔊 [NATIVE-macOS] seekTo: file.length=\(file.length) (\(Double(file.length)/sampleRate)s) framePos=\(framePosition) frameCount=\(frameCount) → suonerà \(Double(frameCount)/sampleRate)s")
        // Incrementa la generazione prima di stop(): il completion handler orfano
        // del vecchio segmento (triggerato da player.stop()) confronterà la propria
        // generazione con quella corrente e la troverà diversa → verrà ignorato.
        playbackGeneration += 1
        let gen = playbackGeneration
        seekOffsetFrames = Int64(framePosition)
        player.stop()
        player.scheduleSegment(file, startingFrame: framePosition, frameCount: frameCount, at: nil) { [weak self] in
            DispatchQueue.main.async {
                guard let self = self, self.playbackGeneration == gen else { return }
                self.isPlaying = false
            }
        }
        player.play()
        isPlaying = true
        result(true)
    }

    private func getPlaybackPosition(result: @escaping FlutterResult) {
        guard let p = audioPlayer, let f = audioFileForPlayback else { result(0); return }
        // Usa playerTime per ottenere i campioni renderizzati relativi al segmento corrente,
        // poi aggiunge seekOffsetFrames per calcolare la posizione assoluta nel file.
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
        guard let f = audioFileForPlayback else { result(0); return }
        result(Int(Double(f.length) / f.processingFormat.sampleRate * 1000))
    }

    // MARK: - Helpers

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

    // MARK: - WAV → Format Conversion

    private func convertWAVToFormat(wavPath: String, outputPath: String, format: String, settings: [String: Any]?, completion: @escaping (Error?) -> Void) {
        switch format {
        case "m4a":
            convertWAVToM4A(wavPath: wavPath, outputPath: outputPath, completion: completion)
        case "flac":
            convertWAVToFLAC(wavPath: wavPath, outputPath: outputPath, settings: settings ?? [:], completion: completion)
        default:
            completion(nil)
        }
    }

    private func convertWAVToM4A(wavPath: String, outputPath: String, completion: @escaping (Error?) -> Void) {
        let asset = AVURLAsset(url: URL(fileURLWithPath: wavPath))
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            completion(NSError(domain: "WavNote", code: -10,
                userInfo: [NSLocalizedDescriptionKey: "Cannot create M4A export session"]))
            return
        }
        let outputURL = URL(fileURLWithPath: outputPath)
        try? FileManager.default.removeItem(at: outputURL)
        session.outputURL = outputURL
        session.outputFileType = .m4a
        session.exportAsynchronously {
            if session.status == .completed { completion(nil) }
            else { completion(session.error ?? NSError(domain: "WavNote", code: -11,
                userInfo: [NSLocalizedDescriptionKey: "M4A export failed"])) }
        }
    }

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
                DispatchQueue.main.async { completion(nil) }
            } catch {
                DispatchQueue.main.async { completion(error) }
            }
        }
    }

    // MARK: - Format Validation

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

    private func validateRecordingSettings(_ settings: [String: Any], format: String) -> Bool {
        guard let sampleRate = settings[AVSampleRateKey] as? Double else { return false }
        let channels = settings[AVNumberOfChannelsKey] as? Int ?? 1
        if format == "wav" { return true }
        guard let inputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: AVAudioChannelCount(channels),
            interleaved: true
        ) else { return false }
        guard let outputFormat = AVAudioFormat(settings: settings) else { return false }
        return AVAudioConverter(from: inputFormat, to: outputFormat) != nil
    }

    // MARK: - Microphone Permission (macOS native)

    private func checkMicPermission(result: @escaping FlutterResult) {
        if #available(macOS 10.14, *) {
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            NSLog("🔐 [NATIVE-macOS] checkMicPermission — status=\(status.rawValue)")
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
            NSLog("🔐 [NATIVE-macOS] requestMicPermission — currentStatus=\(status.rawValue)")
            switch status {
            case .authorized:
                result(true)
            case .notDetermined:
                DispatchQueue.global(qos: .userInitiated).async {
                    AVCaptureDevice.requestAccess(for: .audio) { granted in
                        DispatchQueue.main.async {
                            NSLog("🔐 [NATIVE-macOS] requestMicPermission — granted=\(granted)")
                            result(granted)
                        }
                    }
                }
            default:
                // Denied o restricted — l'utente deve andare in Preferenze di Sistema
                result(false)
            }
        } else {
            result(true)
        }
    }

    // MARK: - Voice Processing

    private func setVoiceProcessing(enabled: Bool, result: @escaping FlutterResult) {
        voiceProcessingEnabled = enabled
        NSLog("🎤 [NATIVE-macOS] Voice processing: \(enabled ? "ON" : "OFF")")
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
