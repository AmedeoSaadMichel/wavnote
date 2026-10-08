// File: macos/Runner/AudioEnginePlugin+Playback.swift
import Cocoa
import FlutterMacOS
import AVFoundation
import Logging

extension AudioEnginePlugin {
    // MARK: - Playback

    func stopAllSegmentPlayers() {
        for player in segmentPlayers.values { player.stop() }
        segmentPlayers.removeAll()
    }

    func getFileWaveform(path: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
                let format = file.processingFormat
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096) else {
                    throw NSError(domain: "WavnoteWaveform", code: 1)
                }
                let bucketFrames = max(1, Int(format.sampleRate / 10))
                var samples: [Double] = []
                var frames = 0
                var peak: Float = 0
                while file.framePosition < file.length {
                    try file.read(into: buffer)
                    guard buffer.frameLength > 0, let channels = buffer.floatChannelData else { break }
                    for frame in 0..<Int(buffer.frameLength) {
                        for channel in 0..<Int(format.channelCount) {
                            peak = max(peak, abs(channels[channel][frame]))
                        }
                        frames += 1
                        if frames == bucketFrames {
                            samples.append(Double(min(peak, 1)))
                            frames = 0
                            peak = 0
                        }
                    }
                }
                if frames > 0 { samples.append(Double(min(peak, 1))) }
                let waveform = samples
                DispatchQueue.main.async { result(waveform) }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "WAVEFORM_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }


    func startPlayback(path: String, position: Int?, result: @escaping FlutterResult) {
        let isArchivedTake = URL(fileURLWithPath: path).deletingLastPathComponent()
            .lastPathComponent.hasPrefix("wavnote_segments_")
        if isArchivedTake {
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

    func startPlaybackFromSegments(position: Int?, result: @escaping FlutterResult) {
        guard !recordingSegments.isEmpty else {
            result(FlutterError(code: "NO_SEGMENTS", message: "No recording segments available", details: nil))
            return
        }
        if recordingSegments.count == 1 {
            startPlaybackInternal(path: recordingSegments[0], position: position, result: result)
        } else {
            let tempDir = NSTemporaryDirectory()
            let tempPath = tempDir + "wavnote_pb_\(Int(Date().timeIntervalSince1970 * 1000)).wav"
            let savedSettings = recordingSettings ?? [:]
            let segs = recordingSegments
            concatenatePCMFiles(segs, into: tempPath, settings: savedSettings) { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    self.logger.error("▶️ [NATIVE-macOS] playbackFromSegments CONCAT ERROR: \(error)")
                    self.startPlaybackInternal(path: self.recordingSegments[0], position: position, result: result)
                } else {
                    self.playbackTempPath = tempPath
                    self.startPlaybackInternal(path: tempPath, position: position, result: result)
                }
            }
        }
    }

    func exportForPlayback(sourcePath: String, completion: @escaping (String?, Error?) -> Void) {
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

    func startPlaybackInternal(path: String, position: Int?, result: @escaping FlutterResult) {
        self.logger.debug("🔊 [NATIVE-macOS] startPlaybackInternal — path=\(path)")
        do {
            // Rilascia sempre le risorse CoreAudio precedenti prima di riaprire il file.
            // Stessa fix applicata al plugin iOS: il gate su playbackEngine != nil causava
            // il bug 2003334207 sulla riapertura dello stesso file al secondo tentativo.
            audioPlayer?.stop()
            audioPlayer?.reset()       // dequeue sincrono → libera ref interno a ExtAudioFile
            playbackEngine?.stop()
            playbackEngine = nil
            audioPlayer = nil          // forza ARC a rilasciare il nodo
            audioFileForPlayback = nil
            audioFileForPlayback = try AVAudioFile(forReading: URL(fileURLWithPath: path))
            guard let file = audioFileForPlayback else {
                result(FlutterError(code: "FILE_ERROR", message: "Could not open audio file", details: nil))
                return
            }
            let srPb = file.processingFormat.sampleRate
            self.logger.debug("🔊 [NATIVE-macOS] startPlaybackInternal: file.length=\(file.length) (\(Double(file.length)/srPb)s ≈ \(Int((Double(file.length)/srPb)*10)) bars@100ms)")
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

            if let pos = position, pos > 0 {
                // Avvio con seek
                let rawFramePosition = AVAudioFramePosition(Double(pos) / 1000.0 * srPb)
                let framePosition = min(rawFramePosition, file.length > 0 ? file.length - 1 : 0)
                let frameCount = max(1, AVAudioFrameCount(file.length - framePosition))

                if frameCount < 4410 {
                    self.logger.debug("🔊 [NATIVE-macOS] startPlaybackInternal: fine file raggiunta (frameCount=\(frameCount)), emulo completamento")
                    self.isPlaying = false
                    self.handlePlaybackCompleted()
                    result(true)
                    return
                }

                seekOffsetFrames = Int64(framePosition)
                if #available(macOS 10.13, *) {
                    player.scheduleSegment(file, startingFrame: framePosition, frameCount: frameCount, at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                        DispatchQueue.main.async {
                            guard let self = self, self.playbackEngine != nil else { return }
                            guard self.playbackGeneration == gen else { return }
                            self.logger.info("🔊 [NATIVE-macOS] playback completato naturalmente (dataPlayedBack)")
                            self.isPlaying = false
                            self.handlePlaybackCompleted()
                        }
                    }
                } else {
                    player.scheduleSegment(file, startingFrame: framePosition, frameCount: frameCount, at: nil) { [weak self] in
                        DispatchQueue.main.async {
                            guard let self = self, self.playbackEngine != nil else { return }
                            guard self.playbackGeneration == gen else { return }
                            let latency = self.playbackEngine?.outputNode.presentationLatency ?? 0.2
                            DispatchQueue.main.asyncAfter(deadline: .now() + latency) {
                                guard self.playbackGeneration == gen else { return }
                                self.logger.info("🔊 [NATIVE-macOS] playback completato naturalmente (fallback)")
                                self.isPlaying = false
                                self.handlePlaybackCompleted()
                            }
                        }
                    }
                }
            } else {
                // Avvio normale dall'inizio
                seekOffsetFrames = 0
                if #available(macOS 10.13, *) {
                    player.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                        DispatchQueue.main.async {
                            guard let self = self, self.playbackEngine != nil else { return }
                            guard self.playbackGeneration == gen else { return }
                            self.logger.info("🔊 [NATIVE-macOS] playback completato naturalmente (dataPlayedBack)")
                            self.isPlaying = false
                            self.handlePlaybackCompleted()
                        }
                    }
                } else {
                    player.scheduleFile(file, at: nil) { [weak self] in
                        DispatchQueue.main.async {
                            guard let self = self, self.playbackEngine != nil else { return }
                            guard self.playbackGeneration == gen else { return }
                            let latency = self.playbackEngine?.outputNode.presentationLatency ?? 0.2
                            DispatchQueue.main.asyncAfter(deadline: .now() + latency) {
                                guard self.playbackGeneration == gen else { return }
                                self.logger.info("🔊 [NATIVE-macOS] playback completato naturalmente (fallback)")
                                self.isPlaying = false
                                self.handlePlaybackCompleted()
                            }
                        }
                    }
                }
            }

            // Forza il pre-buffering per evitare la starvation I/O che causa la chiusura precoce del playback
            player.prepare(withFrameCount: 8192)
            player.play()

            isPlaying = true
            isPlaybackPaused = false
            startPlaybackClockTimer()
            result(true)
        } catch {
            self.logger.error("🔊 [NATIVE-macOS] startPlaybackInternal ERROR: \(error)")
            result(FlutterError(code: "PLAYBACK_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    func stopPlayback(result: @escaping FlutterResult) {
        audioPlayer?.stop()
        audioPlayer?.reset()   // dequeue pending content → libera ref interno a ExtAudioFile
        playbackEngine?.stop()
        playbackEngine = nil
        audioPlayer = nil      // nil esplicito (mancava in macOS come in iOS)
        audioFileForPlayback = nil
        isPlaying = false
        isPlaybackPaused = false
        stopPlaybackClockTimer()
        if let tmp = playbackTempPath {
            try? FileManager.default.removeItem(atPath: tmp)
            playbackTempPath = nil
        }
        result(true)
    }

    func pausePlayback(result: @escaping FlutterResult) {
        audioPlayer?.pause()
        isPlaying = false
        isPlaybackPaused = true
        stopPlaybackClockTimer()
        result(true)
    }

    func resumePlayback(result: @escaping FlutterResult) {
        audioPlayer?.play()
        isPlaying = true
        isPlaybackPaused = false
        startPlaybackClockTimer()
        result(true)
    }

    func seekTo(position: Int, result: @escaping FlutterResult) {
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
        // Se framePosition >= file.length, non c'è nulla da suonare.
        let framePosition = min(rawFramePosition, file.length > 0 ? file.length - 1 : 0)
        let frameCount = max(1, AVAudioFrameCount(file.length - framePosition))

        // Se mancano pochi frame (es. < 441 per <10ms a 44.1kHz), ignora o triggera fine subito,
        // altrimenti il CoreAudio potrebbe incantarsi senza emettere completion
        if frameCount < 4410 {
             self.logger.debug("🔊 [NATIVE-macOS] seekTo: fine file raggiunta (frameCount=\(frameCount)), emulo completamento")
             self.isPlaying = false
             self.handlePlaybackCompleted()
             result(true)
             return
        }

        self.logger.debug("🔊 [NATIVE-macOS] seekTo: file.length=\(file.length) (\(Double(file.length)/sampleRate)s) framePos=\(framePosition) frameCount=\(frameCount) → suonerà \(Double(frameCount)/sampleRate)s")
        // Incrementa la generazione prima di stop(): il completion handler orfano
        // del vecchio segmento (triggerato da player.stop()) confronterà la propria
        // generazione con quella corrente e la troverà diversa → verrà ignorato.
        playbackGeneration += 1
        let gen = playbackGeneration
        seekOffsetFrames = Int64(framePosition)
        player.stop()

        if #available(macOS 10.13, *) {
            player.scheduleSegment(file, startingFrame: framePosition, frameCount: frameCount, at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self = self, self.playbackEngine != nil else { return }
                    guard self.playbackGeneration == gen else { return }
                    self.logger.info("🔊 [NATIVE-macOS] playback completato naturalmente (dataPlayedBack)")
                    self.isPlaying = false
                    self.handlePlaybackCompleted()
                }
            }
        } else {
            player.scheduleSegment(file, startingFrame: framePosition, frameCount: frameCount, at: nil) { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self, self.playbackEngine != nil else { return }
                    guard self.playbackGeneration == gen else { return }
                    let latency = self.playbackEngine?.outputNode.presentationLatency ?? 0.2
                    DispatchQueue.main.asyncAfter(deadline: .now() + latency) {
                        guard self.playbackGeneration == gen else { return }
                        self.logger.info("🔊 [NATIVE-macOS] playback completato naturalmente (fallback)")
                        self.isPlaying = false
                        self.handlePlaybackCompleted()
                    }
                }
            }
        }

        // Forza il pre-buffering prima del play per evitare starvation e interruzione anticipata
        player.prepare(withFrameCount: 8192)
        player.play()

        isPlaying = true
        isPlaybackPaused = false
        result(true)
    }

    func getPlaybackPosition(result: @escaping FlutterResult) {
        result(currentPlaybackPositionMs())
    }

    func getPlaybackDuration(result: @escaping FlutterResult) {
        result(currentPlaybackDurationMs())
    }

    func currentPlaybackPositionMs() -> Int {
        guard let p = audioPlayer, let f = audioFileForPlayback else { return 0 }

        let sampleRate = f.processingFormat.sampleRate
        var renderedFrames: Int64 = 0

        if let nodeTime = p.lastRenderTime, let playerTime = p.playerTime(forNodeTime: nodeTime) {
            let outputLatency = playbackEngine?.outputNode.presentationLatency ?? 0
            let frameLatency = Int64(outputLatency * sampleRate)
            let adjustedSampleTime = max(0, Int64(playerTime.sampleTime) - frameLatency)
            renderedFrames = adjustedSampleTime
        }

        let totalFrames = seekOffsetFrames + renderedFrames
        let clampedFrames = min(totalFrames, f.length)
        return Int(Double(clampedFrames) / sampleRate * 1000)
    }

    func currentPlaybackDurationMs() -> Int {
        guard let f = audioFileForPlayback else { return 0 }
        return Int(Double(f.length) / f.processingFormat.sampleRate * 1000)
    }

    func startPlaybackClockTimer() {
        stopPlaybackClockTimer()

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            guard let self = self, self.isPlaying else { return }
            self.clockStreamHandler.sendPlaybackTick(
                positionMs: self.currentPlaybackPositionMs(),
                durationMs: self.currentPlaybackDurationMs()
            )
        }
        playbackClockTimer = timer
        timer.resume()
    }

    func stopPlaybackClockTimer() {
        playbackClockTimer?.cancel()
        playbackClockTimer = nil
    }

    func handlePlaybackCompleted() {
        stopPlaybackClockTimer()
        playbackStreamHandler.sendPlaybackComplete()
    }

}
