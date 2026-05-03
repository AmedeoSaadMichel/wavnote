// File: ios/Runner/WavNoteLiveActivityController.swift
import Foundation

#if canImport(ActivityKit)
import ActivityKit
import Logging

@available(iOS 16.1, *)
final class WavNoteLiveActivityController {
    static let shared = WavNoteLiveActivityController()
    private let logger = Logger(label: "com.wavnote.live_activity_controller")

    private var activity: Activity<WavNoteRecordingAttributes>?
    private var startedAt = Date()
    private var lastElapsedSeconds = 0
    private var updateCount = 0
    private var waveformRevision = 0
    private var lastDebugLogAt = Date.distantPast

    private init() {}

    func start(title: String, initialElapsedSeconds: Int = 0) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.warning("🌊 [LIVE_ACTIVITY_CONTROLLER] start skipped: activities disabled")
            return
        }
        Task {
            await endAllExistingActivities()
            lastElapsedSeconds = max(0, initialElapsedSeconds)
            startedAt = Date().addingTimeInterval(-Double(lastElapsedSeconds))
            updateCount = 0
            waveformRevision = 0
            lastDebugLogAt = Date.distantPast
            let attributes = WavNoteRecordingAttributes(
                recordingId: UUID().uuidString
            )
            let state = WavNoteRecordingAttributes.ContentState(
                startedAt: startedAt,
                elapsedSeconds: lastElapsedSeconds,
                isPaused: false,
                title: title,
                amplitudeSeed: 0,
                amplitudeSamples: [],
                waveformRevision: waveformRevision
            )
            do {
                activity = try Activity.request(
                    attributes: attributes,
                    contentState: state,
                    pushType: nil
                )
                logger.info("🌊 [LIVE_ACTIVITY_CONTROLLER] start OK elapsed=\(self.lastElapsedSeconds)")
            } catch {
                activity = nil
                logger.error("🌊 [LIVE_ACTIVITY_CONTROLLER] start failed: \(String(describing: error))")
            }
        }
    }

    private func endAllExistingActivities() async {
        var endedCount = 0
        for existingActivity in Activity<WavNoteRecordingAttributes>.activities {
            await existingActivity.end(
                using: existingActivity.contentState,
                dismissalPolicy: .immediate
            )
            endedCount += 1
        }
        activity = nil
        if endedCount > 0 {
            logger.info("🌊 [LIVE_ACTIVITY_CONTROLLER] ended stale activities count=\(endedCount)")
        }
    }

    func update(
        elapsedSeconds: Int,
        isPaused: Bool,
        amplitude: Double,
        amplitudeSamples: [Double]
    ) {
        guard let activity else {
            logger.warning("🌊 [LIVE_ACTIVITY_CONTROLLER] update skipped: no active activity")
            return
        }
        lastElapsedSeconds = max(0, elapsedSeconds)
        let effectiveStart = isPaused
            ? startedAt
            : Date().addingTimeInterval(-Double(lastElapsedSeconds))
        if !isPaused {
            startedAt = effectiveStart
        }
        updateCount += 1
        waveformRevision += 1
        let state = WavNoteRecordingAttributes.ContentState(
            startedAt: effectiveStart,
            elapsedSeconds: lastElapsedSeconds,
            isPaused: isPaused,
            title: "Wavnote",
            amplitudeSeed: amplitude,
            amplitudeSamples: amplitudeSamples,
            waveformRevision: waveformRevision
        )
        let now = Date()
        if now.timeIntervalSince(lastDebugLogAt) >= 1.0 || isPaused {
            lastDebugLogAt = now
            let lastSample = amplitudeSamples.last ?? -1
            let nonZeroSamples = amplitudeSamples.filter { $0 > 0 }.count
            logger.debug(
                "🌊 [LIVE_ACTIVITY_CONTROLLER] update #\(self.updateCount) rev=\(self.waveformRevision) elapsed=\(self.lastElapsedSeconds)s paused=\(isPaused) amp=\(amplitude) samples=\(amplitudeSamples.count) nonZero=\(nonZeroSamples) last=\(lastSample)"
            )
        }
        Task {
            await activity.update(using: state)
            if self.updateCount <= 3 || isPaused {
                self.logger.debug(
                    "🌊 [LIVE_ACTIVITY_CONTROLLER] activity.update completed #\(self.updateCount) paused=\(isPaused)"
                )
            }
        }
    }

    func end() async {
        guard let activity else { return }
        let state = WavNoteRecordingAttributes.ContentState(
            startedAt: startedAt,
            elapsedSeconds: lastElapsedSeconds,
            isPaused: false,
            title: "Wavnote",
            amplitudeSeed: 0,
            amplitudeSamples: [],
            waveformRevision: waveformRevision
        )
        await activity.end(using: state, dismissalPolicy: .immediate)
        self.activity = nil
    }
}
#endif
