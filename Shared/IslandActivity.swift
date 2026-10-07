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

/// 사이트의 다이내믹 아일랜드 실험과 같은 곡들. Apple 이 주는 30초 미리듣기를 재생한다.
/// 주소는 https://itunes.apple.com/lookup?id=<trackId>&country=KR 에서 받았다.
struct Track: Sendable {
    let title: String
    let artist: String
    let colors: [Color]
    let preview: URL
    /// 시스템 아일랜드(지금 재생 중)에 넘기는 앨범 표지. 위젯은 네트워크 이미지를 못 그려서
    /// 직접 만든 아일랜드는 곡 색 그라데이션으로 대신한다.
    let artwork: URL

    /// 미리듣기의 실제 길이를 읽기 전에 쓰는 값.
    static let duration: TimeInterval = 30
    static let all = [
        Track(
            title: "LOVE ATTACK", artist: "RESCENE", colors: [.pink, .purple],
            preview: URL(string: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/6a/c5/ec/6ac5ecf5-6e26-e551-0b1d-d9f2fcb253a2/mzaf_18228858557779313654.plus.aac.p.m4a")!,
            artwork: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/43/0b/4c/430b4c8e-3cb8-da27-648f-435ec3b391a6/8804775334160.jpg/600x600bb.jpg")!
        ),
        Track(
            title: "Deja Vu", artist: "RESCENE", colors: [.orange, .red],
            preview: URL(string: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/08/47/ac/0847ac83-1c65-e840-bf12-f6530c2da6e8/mzaf_4114291550689561164.plus.aac.p.m4a")!,
            artwork: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/e3/4e/e4/e34ee4d9-47a3-8b51-b6cc-4d991508f0b5/cover_KM0023041_1.jpg/600x600bb.jpg")!
        ),
        Track(
            title: "밤밤밤", artist: "RESCENE", colors: [.indigo, .blue],
            preview: URL(string: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/1c/32/c9/1c32c9aa-d07b-f31a-984d-d053ee71a22c/mzaf_2014368852966868589.plus.aac.p.m4a")!,
            artwork: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/c1/4b/95/c14b95a9-1bc8-a4a4-4c02-f9c3d428aaef/8800303114402.jpg/600x600bb.jpg")!
        ),
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
        // 끝 시각이 지나 낡은(stale) 것도 버튼으로 다시 살릴 수 있어야 한다.
        Activity<IslandAttributes>.activities.first { [.active, .stale].contains($0.activityState) }
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

    static func set(_ state: IslandAttributes.ContentState) async {
        await update { _ in state }
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
