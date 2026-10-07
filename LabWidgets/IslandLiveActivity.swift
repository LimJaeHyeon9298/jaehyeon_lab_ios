import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct IslandLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: IslandAttributes.self) { context in
            LockScreenView(kind: context.attributes.kind, state: context.state)
                .padding(16)
                .activityBackgroundTint(.black.opacity(0.75))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            switch context.attributes.kind {
            case .music:
                let track = Track.at(state.track)
                return DynamicIsland {
                    DynamicIslandExpandedRegion(.leading) {
                        Artwork(track: track, size: 52)
                            .padding(.leading, 4)
                    }
                    DynamicIslandExpandedRegion(.trailing) {
                        Waveform(track: track, paused: state.isPaused)
                            .font(.title2)
                            .padding(.trailing, 4)
                    }
                    DynamicIslandExpandedRegion(.center) {
                        TrackTitle(track: track)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    DynamicIslandExpandedRegion(.bottom) {
                        VStack(spacing: 10) {
                            Progress(state: state)
                            MusicControls(paused: state.isPaused)
                        }
                        .padding(.horizontal, 4)
                    }
                } compactLeading: {
                    Artwork(track: track, size: 22)
                } compactTrailing: {
                    Waveform(track: track, paused: state.isPaused)
                } minimal: {
                    Artwork(track: track, size: 22)
                }
                .keylineTint(track.colors.first)
            case .timer:
                return DynamicIsland {
                    DynamicIslandExpandedRegion(.leading) {
                        Label("라면", systemImage: "timer")
                            .font(.headline)
                            .foregroundStyle(.orange)
                            .padding(.leading, 4)
                    }
                    DynamicIslandExpandedRegion(.trailing) {
                        Countdown(state: state)
                            .font(.system(size: 40, weight: .semibold))
                            .frame(maxWidth: 120, alignment: .trailing)
                            .padding(.trailing, 4)
                    }
                    DynamicIslandExpandedRegion(.bottom) {
                        TimerControls(paused: state.isPaused)
                            .padding(.horizontal, 4)
                    }
                } compactLeading: {
                    Image(systemName: "timer")
                        .foregroundStyle(.orange)
                } compactTrailing: {
                    Countdown(state: state)
                        .frame(maxWidth: 44)
                } minimal: {
                    Image(systemName: "timer")
                        .foregroundStyle(.orange)
                }
                .keylineTint(.orange)
            }
        }
    }
}

// MARK: - 조각들

private struct Artwork: View {
    let track: Track
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
            .fill(LinearGradient(colors: track.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(width: size, height: size)
    }
}

private struct Waveform: View {
    let track: Track
    let paused: Bool

    var body: some View {
        Image(systemName: "waveform")
            .foregroundStyle(LinearGradient(colors: track.colors, startPoint: .leading, endPoint: .trailing))
            .opacity(paused ? 0.35 : 1)
    }
}

private struct TrackTitle: View {
    let track: Track

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(track.title)
                .font(.headline)
                .foregroundStyle(.white)
            Text(track.artist)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
        .lineLimit(1)
    }
}

/// 흘러간 시간 · 막대 · 남은 시간. 흐르는 동안은 시스템이 매 순간 다시 그린다.
private struct Progress: View {
    let state: IslandAttributes.ContentState

    var body: some View {
        HStack(spacing: 8) {
            Text(timerInterval: state.range, pauseTime: state.pausedAt, countsDown: false)
                .frame(width: 36, alignment: .leading)
            Group {
                if state.isPaused {
                    ProgressView(value: state.elapsed(), total: state.duration)
                } else {
                    ProgressView(timerInterval: state.range, countsDown: false) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                }
            }
            .tint(.white)
            Text(timerInterval: state.range, pauseTime: state.pausedAt, countsDown: true)
                .frame(width: 36, alignment: .trailing)
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.white.opacity(0.6))
    }
}

private struct Countdown: View {
    let state: IslandAttributes.ContentState

    var body: some View {
        Text(timerInterval: state.range, pauseTime: state.pausedAt, countsDown: true)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.orange)
    }
}

private struct MusicControls: View {
    let paused: Bool

    var body: some View {
        HStack(spacing: 44) {
            Button(intent: SkipTrackIntent(forward: false)) {
                Image(systemName: "backward.fill")
            }
            Button(intent: ToggleIntent()) {
                Image(systemName: paused ? "play.fill" : "pause.fill")
                    .font(.title)
                    .frame(width: 32)
            }
            Button(intent: SkipTrackIntent(forward: true)) {
                Image(systemName: "forward.fill")
            }
        }
        .font(.title2)
        .foregroundStyle(.white)
        .buttonStyle(.plain)
    }
}

private struct TimerControls: View {
    let paused: Bool

    var body: some View {
        HStack {
            Button(intent: EndIntent()) {
                Image(systemName: "xmark")
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(0.2), in: Circle())
            }
            Spacer()
            Button(intent: ToggleIntent()) {
                Image(systemName: paused ? "play.fill" : "pause.fill")
                    .frame(width: 48, height: 48)
                    .background(.orange.opacity(0.3), in: Circle())
                    .foregroundStyle(.orange)
            }
        }
        .font(.title3.weight(.semibold))
        .foregroundStyle(.white)
        .buttonStyle(.plain)
    }
}

private struct LockScreenView: View {
    let kind: IslandAttributes.Kind
    let state: IslandAttributes.ContentState

    var body: some View {
        switch kind {
        case .music:
            let track = Track.at(state.track)
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Artwork(track: track, size: 52)
                    TrackTitle(track: track)
                    Spacer()
                    Waveform(track: track, paused: state.isPaused)
                        .font(.title2)
                }
                Progress(state: state)
                MusicControls(paused: state.isPaused)
            }
        case .timer:
            HStack(spacing: 12) {
                Label("라면", systemImage: "timer")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Spacer()
                Countdown(state: state)
                    .font(.system(size: 40, weight: .semibold))
                    .frame(maxWidth: 120, alignment: .trailing)
                TimerControls(paused: state.isPaused)
                    .frame(width: 112)
            }
        }
    }
}
