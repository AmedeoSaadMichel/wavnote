// File: ios/Runner/AudioEnginePlugin+Playback.swift
import Flutter
import AVFoundation
import Logging

extension AudioEnginePlugin {
    // MARK: - Playback

    func startPlayback(path: String, position: Int?, result: @escaping FlutterResult) {
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

    func startPlaybackFromSegments(position: Int?, result: @escaping FlutterResult) {
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
                let msg = session.error?.localizedDescription ?? "Export failed"
                completion(nil, NSError(domain: "WavNote", code: -2,
                    userInfo: [NSLocalizedDescriptionKey: msg]))
            }
        }
    }

    func startPlaybackInternal(path: String, position: Int?, result: @escaping FlutterResult) {
        self.logger.debug("🔊 [NATIVE] startPlaybackInternal — path=\(path)")
        do {
            // Rilascia sempre le risorse CoreAudio precedenti prima di riaprire il file.
            // Il gate su playbackEngine != nil causava il bug: dopo stopPlayback il playbackEngine
            // è nil ma audioPlayer mantiene ancora un ExtAudioFile handle aperto → errore 2003334207
            // sulla riapertura dello stesso file (es. preview overdub al secondo tentativo).
            audioPlayer?.stop()
            audioPlayer?.reset()       // dequeue sincrono: libera il ref interno a ExtAudioFile
            playbackEngine?.stop()
            playbackEngine = nil
            audioPlayer = nil          // forza ARC a rilasciare il nodo
            audioFileForPlayback = nil // drop ref esplicito (già nil se stopPlayback era stato chiamato)
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

    func stopPlayback(result: @escaping FlutterResult) {
        self.logger.debug("⏹️ [NATIVE] stopPlayback")
        stopPlaybackClock()
        audioPlayer?.stop()
        audioPlayer?.reset()   // dequeue pending content → rilascia il ref interno a ExtAudioFile
        playbackEngine?.stop()
        playbackEngine = nil
        audioPlayer = nil      // rilascia il nodo esplicitamente (stopPlayback non lo faceva)
        audioFileForPlayback = nil
        isPlaying = false
        isPlaybackPaused = false
        if let tmp = playbackTempPath {
            try? FileManager.default.removeItem(atPath: tmp)
            playbackTempPath = nil
        }
        result(true)
    }

    func pausePlayback(result: @escaping FlutterResult) {
        self.logger.debug("⏸️ [NATIVE] pausePlayback")
        audioPlayer?.pause()
        isPlaying = false
        result(true)
    }

    func resumePlayback(result: @escaping FlutterResult) {
        self.logger.debug("▶️ [NATIVE] resumePlayback")
        audioPlayer?.play()
        isPlaying = true
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

    func getPlaybackPosition(result: @escaping FlutterResult) {
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

    func getPlaybackDuration(result: @escaping FlutterResult) {
        guard let player = audioPlayer, let file = audioFileForPlayback else {
            result(0)
            return
        }
        let durationMs = Int((Double(file.length) / file.processingFormat.sampleRate) * 1000)
        result(durationMs)
    }

    func getAudioDuration(path: String, result: @escaping FlutterResult) {
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

    // MARK: - Playback Clock

    /// Avvia il DispatchSourceTimer che emette playback tick ogni 100ms.
    /// La posizione è calcolata da lastRenderTime (sample-accurate).
    /// Il timer è l'unica autorità per la posizione e il completamento del playback.
    func startPlaybackClock() {
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

    func stopPlaybackClock() {
        playbackClockTimer?.cancel()
        playbackClockTimer = nil
    }
}
