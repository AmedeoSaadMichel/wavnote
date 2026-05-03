// File: ios/Shared/WavNoteRecordingControlIntents.swift
import AppIntents

#if WAVNOTE_APP
import Flutter
#endif

@available(iOS 17.0, *)
struct WavNotePauseRecordingIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause Recording"
    static var description = IntentDescription("Pause the active Wavnote recording.")

    func perform() async throws -> some IntentResult {
        try await WavNoteRecordingControlDispatcher.dispatch("pause")
        return .result()
    }
}

@available(iOS 17.0, *)
struct WavNoteResumeRecordingIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Resume Recording"
    static var description = IntentDescription("Resume the paused Wavnote recording.")

    func perform() async throws -> some IntentResult {
        try await WavNoteRecordingControlDispatcher.dispatch("resume")
        return .result()
    }
}

@available(iOS 17.0, *)
struct WavNoteStopRecordingIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Recording"
    static var description = IntentDescription("Stop and save the active Wavnote recording.")

    func perform() async throws -> some IntentResult {
        try await WavNoteRecordingControlDispatcher.dispatch("stop")
        return .result()
    }
}

@available(iOS 17.0, *)
struct WavNoteCancelRecordingIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Cancel Recording"
    static var description = IntentDescription("Cancel the active Wavnote recording.")

    func perform() async throws -> some IntentResult {
        try await WavNoteRecordingControlDispatcher.dispatch("cancel")
        return .result()
    }
}

private enum WavNoteRecordingControlDispatcher {
    static func dispatch(_ action: String) async throws {
        #if WAVNOTE_APP
        let dispatched = await AudioEnginePlugin.dispatchLiveActivityControl(action: action)
        if !dispatched {
            throw WavNoteRecordingControlError.dispatchFailed(action)
        }
        #else
        throw WavNoteRecordingControlError.dispatchFailed(action)
        #endif
    }
}

private enum WavNoteRecordingControlError: LocalizedError {
    case dispatchFailed(String)

    var errorDescription: String? {
        switch self {
        case .dispatchFailed(let action):
            "WavNote could not dispatch the \(action) recording command."
        }
    }
}
