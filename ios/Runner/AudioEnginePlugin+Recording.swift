// File: ios/Runner/AudioEnginePlugin+Recording.swift
import Flutter
import AVFoundation
import Logging

extension AudioEnginePlugin {
    // MARK: - Recording

    func startRecording(
        path: String,
        sampleRate: Int,
        bitRate: Int,
        format: String,
        initialElapsedMs: Int = 0,
        result: @escaping FlutterResult
    ) {
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
            try configureAudioSession(preferredSampleRate: cappedSampleRate)
            self.logger.debug("🎙️ [NATIVE] startRecording: AVAudioSession riconfigurata (preferredSampleRate=\(cappedSampleRate))")
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
            lastLiveActivityUpdateTime = 0
            liveActivityAmplitudeSamples = []
            lastLiveActivitySampleTime = 0
            liveActivitySampleAppendCount = 0
            liveActivityUpdateRequestCount = 0
            lastLiveActivityDebugLogTime = 0
            liveActivityElapsedOffsetMs = max(0, initialElapsedMs)

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
                self.appendLiveActivityAmplitudeSample(
                    Double(self.currentAmplitude),
                    timestamp: now
                )
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
                if now - self.lastLiveActivityUpdateTime >= AudioEnginePlugin.liveActivityUpdateInterval {
                    self.lastLiveActivityUpdateTime = now
                    self.updateLiveActivity(isPaused: false)
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
            if #available(iOS 16.1, *) {
                WavNoteLiveActivityController.shared.start(
                    title: "Wavnote",
                    initialElapsedSeconds: liveActivityElapsedOffsetMs / 1000
                )
            }
            self.logger.info("🎙️ [NATIVE] startRecording: OK — engine running")
            result(true)
        } catch {
            self.logger.error("🎙️ [NATIVE] startRecording ERROR: \(error)")
            result(FlutterError(code: "RECORD_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    func pauseRecording(result: @escaping FlutterResult) {
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
        updateLiveActivity(isPaused: true)
        result(true)
    }

    func resumeRecording(result: @escaping FlutterResult) {
        self.logger.debug("▶️ [NATIVE] resumeRecording — isRecording=\(isRecording) isPaused=\(isPaused) segmenti=\(recordingSegments.count)")
        guard isRecording, isPaused else {
            self.logger.error("▶️ [NATIVE] resumeRecording ERROR: stato invalido")
            result(FlutterError(code: "INVALID_STATE", message: "Not paused", details: nil))
            return
        }
        do {
            try configureAudioSession(preferredSampleRate: Int(outputSampleRate))
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
            updateLiveActivity(isPaused: false)
            self.logger.info("▶️ [NATIVE] resumeRecording: OK — engine riavviato")
            result(true)
        } catch {
            self.logger.error("▶️ [NATIVE] resumeRecording ERROR: \(error)")
            result(FlutterError(code: "RESUME_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    func stopRecording(raw: Bool = false, result: @escaping FlutterResult) {
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
        liveActivityAmplitudeSamples = []
        lastLiveActivitySampleTime = 0
        liveActivitySampleAppendCount = 0
        liveActivityUpdateRequestCount = 0
        lastLiveActivityDebugLogTime = 0
        liveActivityElapsedOffsetMs = 0
        if #available(iOS 16.1, *) {
            Task {
                await WavNoteLiveActivityController.shared.end()
            }
        }
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
    func finishWithFile(_ path: String, outputPath: String, segments: [String], result: @escaping FlutterResult) {
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

    func cancelRecording(result: @escaping FlutterResult) {
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
        liveActivityAmplitudeSamples = []
        lastLiveActivitySampleTime = 0
        liveActivitySampleAppendCount = 0
        liveActivityUpdateRequestCount = 0
        lastLiveActivityDebugLogTime = 0
        liveActivityElapsedOffsetMs = 0
        if #available(iOS 16.1, *) {
            Task {
                await WavNoteLiveActivityController.shared.end()
            }
        }
        result(true)
    }

    func getRecordingStatus(result: @escaping FlutterResult) {
        let durationMs = Int(Double(framesInPreviousSegments + framesWrittenThisSegment) / outputSampleRate * 1000)
        result([
            "isRecording": isRecording,
            "isPaused": isPaused,
            "path": recordingFilePath ?? NSNull(),
            "durationMs": durationMs,
            "amplitude": Double(currentAmplitude)
        ])
    }

    func updateLiveActivity(isPaused: Bool) {
        if #available(iOS 16.1, *) {
            let segmentElapsedMs = Int(
                Double(framesInPreviousSegments + framesWrittenThisSegment) /
                    outputSampleRate * 1000
            )
            let elapsedSeconds = max(
                0,
                (segmentElapsedMs + liveActivityElapsedOffsetMs) / 1000
            )
            liveActivityUpdateRequestCount += 1
            let now = CACurrentMediaTime()
            if now - lastLiveActivityDebugLogTime >= 1.0 || isPaused {
                lastLiveActivityDebugLogTime = now
                let lastSample = liveActivityAmplitudeSamples.last ?? -1
                let nonZeroSamples = liveActivityAmplitudeSamples.filter { $0 > 0 }.count
                logger.debug(
                    "🌊 [LIVE_ACTIVITY] update request #\(self.liveActivityUpdateRequestCount) elapsed=\(elapsedSeconds)s paused=\(isPaused) amp=\(Double(self.currentAmplitude)) samples=\(self.liveActivityAmplitudeSamples.count) nonZero=\(nonZeroSamples) last=\(lastSample)"
                )
            }
            let amplitude = Double(currentAmplitude)
            let samples = liveActivityAmplitudeSamples
            DispatchQueue.main.async {
                WavNoteLiveActivityController.shared.update(
                    elapsedSeconds: elapsedSeconds,
                    isPaused: isPaused,
                    amplitude: amplitude,
                    amplitudeSamples: samples
                )
            }
        }
    }

    func appendLiveActivityAmplitudeSample(
        _ amplitude: Double,
        timestamp: CFTimeInterval
    ) {
        guard timestamp - lastLiveActivitySampleTime >= AudioEnginePlugin.liveActivitySampleInterval else { return }
        lastLiveActivitySampleTime = timestamp
        let normalized = min(max(amplitude, 0.0), 1.0)
        liveActivityAmplitudeSamples.append(normalized)
        liveActivitySampleAppendCount += 1
        if liveActivityAmplitudeSamples.count > AudioEnginePlugin.maxLiveActivityAmplitudeSamples {
            let overflow = liveActivityAmplitudeSamples.count -
                AudioEnginePlugin.maxLiveActivityAmplitudeSamples
            liveActivityAmplitudeSamples.removeFirst(overflow)
        }
        if liveActivitySampleAppendCount % 30 == 1 {
            logger.debug(
                "🌊 [LIVE_ACTIVITY] sample append #\(self.liveActivitySampleAppendCount) raw=\(amplitude) normalized=\(normalized) buffer=\(self.liveActivityAmplitudeSamples.count)"
            )
        }
    }
}
