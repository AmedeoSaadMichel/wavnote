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
        await WavNoteRecordingControlDispatcher.dispatch("pause")
        return .result()
    }
}

@available(iOS 17.0, *)
struct WavNoteResumeRecordingIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Resume Recording"
    static var description = IntentDescription("Resume the paused Wavnote recording.")

    func perform() async throws -> some IntentResult {
        await WavNoteRecordingControlDispatcher.dispatch("resume")
        return .result()
    }
}

@available(iOS 17.0, *)
struct WavNoteStopRecordingIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Recording"
    static var description = IntentDescription("Stop and save the active Wavnote recording.")

    func perform() async throws -> some IntentResult {
        await WavNoteRecordingControlDispatcher.dispatch("stop")
        return .result()
    }
}

@available(iOS 17.0, *)
struct WavNoteCancelRecordingIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Cancel Recording"
    static var description = IntentDescription("Cancel the active Wavnote recording.")

    func perform() async throws -> some IntentResult {
        await WavNoteRecordingControlDispatcher.dispatch("cancel")
        return .result()
    }
}

private enum WavNoteRecordingControlDispatcher {
    static func dispatch(_ action: String) async {
        #if WAVNOTE_APP
        await MainActor.run {
            AudioEnginePlugin.activeInstance?.sendLiveActivityControl(action: action)
        }
        #endif
    }
}
