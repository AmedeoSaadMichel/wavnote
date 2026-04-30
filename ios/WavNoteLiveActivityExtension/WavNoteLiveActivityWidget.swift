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
                MiniWaveView(
                    preferredBars: 14,
                    height: 16,
                    seed: context.state.amplitudeSeed,
                    isPaused: context.state.isPaused
                )
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
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    AppIdentityView(uppercase: true)
                    Spacer()
                    RecordingShortBadgeView(isPaused: state.isPaused)
                }
                Text(displayTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(WavNoteColors.yellow)
                    .lineLimit(1)
                    .padding(.top, 12)
                TimerText(state: state, size: 28, color: .white)
                    .padding(.top, 2)
                Spacer(minLength: 0)
                MiniWaveView(
                    preferredBars: 96,
                    height: 22,
                    seed: state.amplitudeSeed,
                    isPaused: state.isPaused
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, minHeight: 158)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.32), radius: 22, y: 14)
    }

    private var displayTitle: String {
        state.title.isEmpty || state.title == "Wavnote" ? "Registrazione in corso" : state.title
    }
}

private struct AppIdentityView: View {
    var uppercase: Bool = false

    var body: some View {
        HStack(spacing: 7) {
            EyeGlyphView()
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

private struct MiniWaveView: View {
    let preferredBars: Int
    let height: CGFloat
    let seed: Double
    let isPaused: Bool

    var body: some View {
        if isPaused {
            barsView(tick: seed * 8.0)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
                barsView(tick: timeline.date.timeIntervalSinceReferenceDate * 7.5 + seed * 2.0)
            }
        }
    }

    private func barsView(tick: Double) -> some View {
        GeometryReader { geometry in
            let barWidth: CGFloat = 2.4
            let spacing: CGFloat = 2
            let availableWidth = max(geometry.size.width, 1)
            let fittedBars = Int((availableWidth + spacing) / (barWidth + spacing))
            let barCount = max(1, min(preferredBars, fittedBars))

            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(WavNoteColors.yellow)
                        .frame(width: barWidth, height: barHeight(index: index, tick: tick))
                        .shadow(color: WavNoteColors.yellow.opacity(0.55), radius: 4)
                        .opacity(isPaused ? 0.78 : 0.96)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: height, alignment: .leading)
        }
        .frame(height: height)
    }

    private func barHeight(index: Int, tick: Double) -> CGFloat {
        if isPaused { return height * 0.42 }
        let primary = sin(tick + Double(index) * 0.45)
        let secondary = cos(tick * 0.6 + Double(index) * 0.2)
        let value = abs(primary * secondary)
        return height * (0.35 + 0.65 * value)
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

private struct EyeGlyphView: View {
    var body: some View {
        ZStack {
            EyeShape()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.95, blue: 0.55),
                            WavNoteColors.yellow,
                            Color(red: 0.78, green: 0.46, blue: 0.10)
                        ],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: 22
                    )
                )
                .overlay(
                    EyeShape()
                        .stroke(Color(red: 0.36, green: 0.16, blue: 0.05), lineWidth: 1)
                )
                .frame(width: 23, height: 17)
            Circle()
                .fill(Color(red: 0.24, green: 0.10, blue: 0.05))
                .frame(width: 9, height: 9)
            Circle()
                .fill(WavNoteColors.ink)
                .frame(width: 4, height: 4)
            Circle()
                .fill(.white)
                .frame(width: 2, height: 2)
                .offset(x: -2, y: -2)
        }
    }
}

private struct EyeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return path
    }
}

private struct VisualControlsView: View {
    let isPaused: Bool

    var body: some View {
        HStack(spacing: 10) {
            if #available(iOSApplicationExtension 17.0, *) {
                Button(intent: WavNoteCancelRecordingIntent()) {
                    CircleButton(systemName: "xmark", color: WavNoteColors.purple, foreground: .white)
                }
                .buttonStyle(.plain)

                if isPaused {
                    Button(intent: WavNoteResumeRecordingIntent()) {
                        CapsuleButton(title: "RESUME", systemName: "play.fill", color: WavNoteColors.teal)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                } else {
                    Button(intent: WavNotePauseRecordingIntent()) {
                        CapsuleButton(title: "PAUSE", systemName: "pause.fill", color: WavNoteColors.yellow)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }

                Button(intent: WavNoteStopRecordingIntent()) {
                    CircleButton(systemName: "stop.fill", color: WavNoteColors.red, foreground: .white)
                }
                .buttonStyle(.plain)
            } else {
                CircleButton(systemName: "xmark", color: WavNoteColors.purple, foreground: .white)
                CapsuleButton(
                    title: isPaused ? "RESUME" : "PAUSE",
                    systemName: isPaused ? "play.fill" : "pause.fill",
                    color: isPaused ? WavNoteColors.teal : WavNoteColors.yellow
                )
                .frame(maxWidth: .infinity)
                CircleButton(systemName: "stop.fill", color: WavNoteColors.red, foreground: .white)
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
            let waveHeight: CGFloat = state.isPaused ? 15 : (compact ? 19 : 22)
            let horizontalInset: CGFloat = compact ? 2 : 6

            VStack(alignment: .center, spacing: compact ? 7 : 8) {
                HStack(alignment: .center, spacing: compact ? 10 : 14) {
                    EyeGlyphView()
                    TimerText(state: state, size: timerSize, color: WavNoteColors.yellow)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                    Spacer(minLength: 8)
                    RecDotView(size: compact ? 8 : 9)
                        .padding(.trailing, compact ? 14 : 18)
                }
                .frame(maxWidth: .infinity, minHeight: 35, alignment: .center)

                MiniWaveView(
                    preferredBars: compact ? 64 : 74,
                    height: waveHeight,
                    seed: state.amplitudeSeed,
                    isPaused: state.isPaused
                )
                .frame(maxWidth: .infinity, alignment: .center)
                .clipped()

                VisualControlsView(isPaused: state.isPaused)
                    .padding(.bottom, compact ? 6 : 7)
            }
            .padding(.horizontal, horizontalInset)
        }
        .frame(height: 112)
    }
}

private struct CircleButton: View {
    let systemName: String
    let color: Color
    let foreground: Color

    var body: some View {
        ZStack {
            Circle().fill(color)
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(foreground)
        }
        .frame(width: 30, height: 30)
        .shadow(color: color.opacity(0.40), radius: 10)
    }
}

private struct CapsuleButton: View {
    let title: String
    let systemName: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemName)
            Text(title)
        }
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(.black)
        .frame(maxWidth: .infinity, minHeight: 30)
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
                    Color(red: 0.10, green: 0.02, blue: 0.20),
                    Color(red: 0.18, green: 0.04, blue: 0.32),
                    Color(red: 0.29, green: 0.08, blue: 0.44)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [WavNoteColors.purple.opacity(0.40), .clear],
                center: .topLeading,
                startRadius: 4,
                endRadius: 180
            )
            RadialGradient(
                colors: [WavNoteColors.magenta.opacity(0.32), .clear],
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
    static let cyan = Color(red: 0.40, green: 0.88, blue: 0.95)
    static let magenta = Color(red: 0.96, green: 0.22, blue: 0.74)
    static let purple = Color(red: 0.54, green: 0.15, blue: 0.88)
    static let pink = Color(red: 1.0, green: 0.30, blue: 0.52)
    static let red = Color(red: 1.0, green: 0.15, blue: 0.25)
}
