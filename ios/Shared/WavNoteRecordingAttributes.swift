// File: ios/Shared/WavNoteRecordingAttributes.swift
import ActivityKit
import Foundation

@available(iOS 16.1, *)
public struct WavNoteRecordingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var startedAt: Date
        public var elapsedSeconds: Int
        public var isPaused: Bool
        public var title: String
        public var amplitudeSeed: Double

        public init(
            startedAt: Date,
            elapsedSeconds: Int,
            isPaused: Bool,
            title: String,
            amplitudeSeed: Double
        ) {
            self.startedAt = startedAt
            self.elapsedSeconds = elapsedSeconds
            self.isPaused = isPaused
            self.title = title
            self.amplitudeSeed = amplitudeSeed
        }
    }

    public var recordingId: String

    public init(recordingId: String) {
        self.recordingId = recordingId
    }
}
