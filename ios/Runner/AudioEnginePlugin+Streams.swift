// File: ios/Runner/AudioEnginePlugin+Streams.swift
import Flutter
import Logging

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

    /// Emette bucket waveform temporizzati a 100ms.
    func sendWaveformBuckets(startIndex: Int, samples: [Double], totalCount: Int) {
        eventSink?([
            "type": "waveformBuckets",
            "startIndex": startIndex,
            "samples": samples,
            "totalCount": totalCount
        ])
    }

    /// Emette un tick di posizione playback (da DispatchSourceTimer, 100ms).
    func sendPlaybackTick(positionMs: Int, durationMs: Int) {
        eventSink?(["type": "playbackTick", "positionMs": positionMs, "durationMs": durationMs])
    }
}
