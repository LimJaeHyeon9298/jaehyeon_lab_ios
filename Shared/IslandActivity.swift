import ActivityKit
import SwiftUI

/// 다이내믹 아일랜드에 띄우는 라이브 액티비티. 앱과 위젯 익스텐션이 같이 쓴다.
///
/// 진행 중인 시간과 막대는 시작·끝 시각만 넘기면 시스템이 알아서 흘려 그린다.
/// 그래서 앱은 재생·멈춤·곡 넘김처럼 상태가 바뀔 때만 업데이트를 보낸다.
struct IslandAttributes: ActivityAttributes {
    enum Kind: String, Codable, Hashable {
        case music, timer
    }

    struct ContentState: Codable, Hashable {
        /// 음악일 때 몇 번째 곡인지.
        var track = 0
        var start: Date
        var end: Date
        /// 멈춘 시각. nil 이면 흘러가는 중.
        var pausedAt: Date?
    }

    let kind: Kind
}

extension IslandAttributes.ContentState {
    var range: ClosedRange<Date> { start...end }
    var duration: TimeInterval { end.timeIntervalSince(start) }
    var isPaused: Bool { pausedAt != nil }

    func elapsed(at now: Date = .now) -> TimeInterval {
        min(max((pausedAt ?? now).timeIntervalSince(start), 0), duration)
    }

    static func running(
        track: Int = 0,
        duration: TimeInterval,
        elapsed: TimeInterval = 0,
        now: Date = .now
    ) -> Self {
        let start = now.addingTimeInterval(-elapsed)
        return Self(track: track, start: start, end: start.addingTimeInterval(duration))
    }

    /// 재생 중이면 멈추고, 멈춰 있으면 멈춘 자리부터 다시 흘린다. 끝까지 갔으면 처음부터.
    func toggled(now: Date = .now) -> Self {
        if let pausedAt {
            return .running(track: track, duration: duration, elapsed: pausedAt.timeIntervalSince(start), now: now)
        }
        if now >= end {
            return .running(track: track, duration: duration, now: now)
        }
        var state = self
        state.pausedAt = now
        return state
    }
}

/// 사이트의 다이내믹 아일랜드 실험과 같은 곡들. 웹처럼 30초 미리듣기 길이로 흘린다.
struct Track: Sendable {
    let title: String
    let artist: String
    let colors: [Color]

    static let duration: TimeInterval = 30
    static let all = [
        Track(title: "LOVE ATTACK", artist: "RESCENE", colors: [.pink, .purple]),
        Track(title: "Deja Vu", artist: "RESCENE", colors: [.orange, .red]),
        Track(title: "밤밤밤", artist: "RESCENE", colors: [.indigo, .blue]),
    ]

    static func at(_ index: Int) -> Track {
        all[(index % all.count + all.count) % all.count]
    }
}

enum Ramen {
    static let duration: TimeInterval = 3 * 60
}

/// 액티비티를 켜고, 바꾸고, 끄는 곳. 한 번에 하나만 띄운다.
enum IslandController {
    static var current: Activity<IslandAttributes>? {
        Activity<IslandAttributes>.activities.first { $0.activityState == .active }
    }

    static func start(_ kind: IslandAttributes.Kind) async throws {
        await endAll()
        let state: IslandAttributes.ContentState = switch kind {
        case .music: .running(duration: Track.duration)
        case .timer: .running(duration: Ramen.duration)
        }
        _ = try Activity.request(
            attributes: IslandAttributes(kind: kind),
            content: ActivityContent(state: state, staleDate: state.end)
        )
    }

    static func update(_ change: (IslandAttributes.ContentState) -> IslandAttributes.ContentState) async {
        guard let activity = current else { return }
        let state = change(activity.content.state)
        // 멈춰 있는 동안은 낡을 일이 없다.
        await activity.update(ActivityContent(state: state, staleDate: state.isPaused ? nil : state.end))
    }

    static func endAll() async {
        for activity in Activity<IslandAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
