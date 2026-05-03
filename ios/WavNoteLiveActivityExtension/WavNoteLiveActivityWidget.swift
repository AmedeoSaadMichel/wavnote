// File: ios/WavNoteLiveActivityExtension/WavNoteLiveActivityWidget.swift
import ActivityKit
import SwiftUI
import WidgetKit

struct WavNoteLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WavNoteRecordingAttributes.self) { context in
            LockScreenActivityView(state: context.state)
                .activityBackgroundTint(WavNoteColors.ink)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(state: context.state)
                }
            } compactLeading: {
                HStack(spacing: 6) {
                    RecDotView(size: 9)
                    TimerText(state: context.state, size: 13, color: WavNoteColors.pink)
                }
            } compactTrailing: {
                RecordingShortBadgeView(isPaused: context.state.isPaused)
                .frame(width: 56)
            } minimal: {
                RecDotView(size: 8)
            }
            .keylineTint(WavNoteColors.yellow)
        }
    }
}

private struct LockScreenActivityView: View {
    let state: WavNoteRecordingAttributes.ContentState

    var body: some View {
        ZStack {
            WavNoteGradient()
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    AppIdentityView(isPaused: state.isPaused, uppercase: true)
                    Spacer()
                    RecordingShortBadgeView(isPaused: state.isPaused)
                }
                Text(displayTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(WavNoteColors.yellow)
                    .lineLimit(1)
                    .padding(.top, 4)
                TimerText(state: state, size: 26, color: .white)
                VisualControlsView(isPaused: state.isPaused, compact: true)
                    .padding(.top, 4)
                    .padding(.bottom, 2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, minHeight: 174)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.32), radius: 22, y: 14)
    }

    private var displayTitle: String {
        state.title.isEmpty || state.title == "Wavnote" ? "Registrazione in corso" : state.title
    }
}

private struct AppIdentityView: View {
    let isPaused: Bool
    var uppercase: Bool = false

    var body: some View {
        HStack(spacing: 7) {
            RecordPupilIndicatorView(isPaused: isPaused, size: 23)
            Text(uppercase ? "WAVNOTE" : "Wavnote")
                .font(.system(size: 13, weight: .semibold))
                .tracking(uppercase ? 0.4 : 0)
                .foregroundStyle(.white)
        }
    }
}

private struct StateBadgeView: View {
    let isPaused: Bool

    var body: some View {
        HStack(spacing: 6) {
            if !isPaused {
                RecDotView(size: 8)
            }
            Text(isPaused ? "PAUSED" : "RECORDING")
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundStyle(isPaused ? WavNoteColors.yellow : WavNoteColors.pink)
        }
    }
}

private struct RecordingShortBadgeView: View {
    let isPaused: Bool

    var body: some View {
        HStack(spacing: 6) {
            if !isPaused {
                RecDotView(size: 8)
            }
            Text(isPaused ? "PAUSED" : "REC")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .foregroundStyle(isPaused ? WavNoteColors.yellow : WavNoteColors.pink)
        }
    }
}

private struct TimerText: View {
    let state: WavNoteRecordingAttributes.ContentState
    let size: CGFloat
    var color: Color = WavNoteColors.yellow

    var body: some View {
        Group {
            if state.isPaused {
                Text(format(seconds: state.elapsedSeconds))
            } else {
                Text(timerInterval: audioTimerInterval, countsDown: false)
            }
        }
        .monospacedDigit()
        .font(.system(size: size, weight: .medium, design: .monospaced))
        .tracking(size >= 28 ? 1.5 : 0.5)
        .foregroundStyle(color)
        .shadow(color: WavNoteColors.yellow.opacity(0.35), radius: 10)
    }

    private func format(seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let rest = max(0, seconds) % 60
        return String(format: "%02d:%02d", minutes, rest)
    }

    private var audioTimerInterval: ClosedRange<Date> {
        let elapsed = max(0, state.elapsedSeconds)
        let start = Date().addingTimeInterval(-Double(elapsed))
        return start...Date.distantFuture
    }
}

private struct RecDotView: View {
    var size: CGFloat = 9

    var body: some View {
        Circle()
            .fill(WavNoteColors.red)
            .frame(width: size, height: size)
            .shadow(color: WavNoteColors.red.opacity(0.95), radius: 8)
    }
}

private struct RecordPupilIndicatorView: View {
    let isPaused: Bool
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.65, blue: 0.0), WavNoteColors.yellow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(Circle().stroke(WavNoteColors.cyan, lineWidth: max(1.2, size * 0.06)))
                .shadow(color: Color.black.opacity(0.20), radius: size * 0.10, y: size * 0.05)
            Circle()
                .fill(WavNoteColors.ink)
                .frame(width: size * (isPaused ? 0.28 : 0.65), height: size * (isPaused ? 0.28 : 0.65))
        }
        .frame(width: size, height: size)
    }
}

private struct VisualControlsView: View {
    let isPaused: Bool
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 8 : 10) {
            if #available(iOSApplicationExtension 17.0, *) {
                Button(intent: WavNoteCancelRecordingIntent()) {
                    CircleButton(
                        systemName: "xmark",
                        color: WavNoteColors.purple,
                        foreground: .white,
                        size: compact ? 26 : 30
                    )
                }
                .buttonStyle(.plain)

                if isPaused {
                    Button(intent: WavNoteResumeRecordingIntent()) {
                        CapsuleButton(
                            title: "RESUME",
                            systemName: "play.fill",
                            color: WavNoteColors.teal,
                            height: compact ? 26 : 30
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                } else {
                    Button(intent: WavNotePauseRecordingIntent()) {
                        CapsuleButton(
                            title: "PAUSE",
                            systemName: "pause.fill",
                            color: WavNoteColors.yellow,
                            height: compact ? 26 : 30
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }

                Button(intent: WavNoteStopRecordingIntent()) {
                    CircleButton(
                        systemName: "stop.fill",
                        color: WavNoteColors.red,
                        foreground: .white,
                        size: compact ? 26 : 30
                    )
                }
                .buttonStyle(.plain)
            } else {
                CircleButton(
                    systemName: "xmark",
                    color: WavNoteColors.purple,
                    foreground: .white,
                    size: compact ? 26 : 30
                )
                CapsuleButton(
                    title: isPaused ? "RESUME" : "PAUSE",
                    systemName: isPaused ? "play.fill" : "pause.fill",
                    color: isPaused ? WavNoteColors.teal : WavNoteColors.yellow,
                    height: compact ? 26 : 30
                )
                .frame(maxWidth: .infinity)
                CircleButton(
                    systemName: "stop.fill",
                    color: WavNoteColors.red,
                    foreground: .white,
                    size: compact ? 26 : 30
                )
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ExpandedBottomView: View {
    let state: WavNoteRecordingAttributes.ContentState

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let compact = width < 330
            let timerSize: CGFloat = compact ? 29 : 32
            let horizontalInset: CGFloat = compact ? 2 : 6

            VStack(alignment: .center, spacing: compact ? 10 : 12) {
                HStack(alignment: .center, spacing: compact ? 10 : 14) {
                    RecordPupilIndicatorView(isPaused: state.isPaused, size: compact ? 28 : 31)
                    TimerText(state: state, size: timerSize, color: WavNoteColors.yellow)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                    Spacer(minLength: 8)
                    RecDotView(size: compact ? 8 : 9)
                        .padding(.trailing, compact ? 14 : 18)
                }
                .frame(maxWidth: .infinity, minHeight: 35, alignment: .center)

                VisualControlsView(isPaused: state.isPaused)
                    .padding(.bottom, compact ? 6 : 7)
            }
            .padding(.horizontal, horizontalInset)
        }
        .frame(height: 86)
    }
}

private struct CircleButton: View {
    let systemName: String
    let color: Color
    let foreground: Color
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            Circle().fill(color)
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(foreground)
        }
        .frame(width: size, height: size)
        .shadow(color: color.opacity(0.40), radius: 10)
    }
}

private struct CapsuleButton: View {
    let title: String
    let systemName: String
    let color: Color
    var height: CGFloat = 30

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemName)
            Text(title)
        }
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(.black)
        .frame(maxWidth: .infinity, minHeight: height)
        .background(color)
        .clipShape(Capsule())
        .shadow(color: color.opacity(0.40), radius: 10)
    }
}

private struct WavNoteGradient: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    WavNoteColors.primaryPurple,
                    WavNoteColors.primaryPink,
                    WavNoteColors.primaryOrange
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [WavNoteColors.cyan.opacity(0.18), .clear],
                center: .topLeading,
                startRadius: 4,
                endRadius: 180
            )
            RadialGradient(
                colors: [WavNoteColors.yellow.opacity(0.14), .clear],
                center: .bottomTrailing,
                startRadius: 4,
                endRadius: 180
            )
        }
    }
}

private enum WavNoteColors {
    static let ink = Color(red: 0.04, green: 0.02, blue: 0.08)
    static let yellow = Color(red: 1.0, green: 0.78, blue: 0.25)
    static let teal = Color(red: 0.10, green: 0.82, blue: 0.74)
    static let cyan = Color(red: 0.0, green: 0.74, blue: 0.83)
    static let magenta = Color(red: 0.96, green: 0.22, blue: 0.74)
    static let purple = Color(red: 0.54, green: 0.15, blue: 0.88)
    static let pink = Color(red: 1.0, green: 0.30, blue: 0.52)
    static let red = Color(red: 1.0, green: 0.15, blue: 0.25)
    static let primaryPurple = Color(red: 0.56, green: 0.18, blue: 0.89)
    static let primaryPink = Color(red: 0.85, green: 0.13, blue: 1.0)
    static let primaryOrange = Color(red: 1.0, green: 0.31, blue: 0.31)
}
