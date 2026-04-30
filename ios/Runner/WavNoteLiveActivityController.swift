// File: ios/Runner/WavNoteLiveActivityController.swift
import Foundation

#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
final class WavNoteLiveActivityController {
    static let shared = WavNoteLiveActivityController()

    private var activity: Activity<WavNoteRecordingAttributes>?
    private var startedAt = Date()
    private var lastElapsedSeconds = 0

    private init() {}

    func start(title: String, initialElapsedSeconds: Int = 0) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        Task {
            await end()
            lastElapsedSeconds = max(0, initialElapsedSeconds)
            startedAt = Date().addingTimeInterval(-Double(lastElapsedSeconds))
            let attributes = WavNoteRecordingAttributes(
                recordingId: UUID().uuidString
            )
            let state = WavNoteRecordingAttributes.ContentState(
                startedAt: startedAt,
                elapsedSeconds: lastElapsedSeconds,
                isPaused: false,
                title: title,
                amplitudeSeed: 0
            )
            do {
                activity = try Activity.request(
                    attributes: attributes,
                    contentState: state,
                    pushType: nil
                )
            } catch {
                activity = nil
            }
        }
    }

    func update(elapsedSeconds: Int, isPaused: Bool, amplitude: Double) {
        guard let activity else { return }
        lastElapsedSeconds = max(0, elapsedSeconds)
        let effectiveStart = isPaused
            ? startedAt
            : Date().addingTimeInterval(-Double(lastElapsedSeconds))
        if !isPaused {
            startedAt = effectiveStart
        }
        let state = WavNoteRecordingAttributes.ContentState(
            startedAt: effectiveStart,
            elapsedSeconds: lastElapsedSeconds,
            isPaused: isPaused,
            title: "Wavnote",
            amplitudeSeed: amplitude
        )
        Task {
            await activity.update(using: state)
        }
    }

    func end() async {
        guard let activity else { return }
        let state = WavNoteRecordingAttributes.ContentState(
            startedAt: startedAt,
            elapsedSeconds: lastElapsedSeconds,
            isPaused: false,
            title: "Wavnote",
            amplitudeSeed: 0
        )
        await activity.end(using: state, dismissalPolicy: .immediate)
        self.activity = nil
    }
}
#endif
