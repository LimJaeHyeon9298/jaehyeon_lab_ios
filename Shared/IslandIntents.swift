import ActivityKit
import AppIntents

/// 펼친 아일랜드와 잠금화면의 버튼들. LiveActivityIntent 는 앱 프로세스에서 돈다.
struct ToggleIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "재생·멈춤"

    func perform() async throws -> some IntentResult {
        await IslandController.update { $0.toggled() }
        return .result()
    }
}

struct SkipTrackIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "곡 넘기기"

    @Parameter(title: "다음 곡", default: true)
    var forward: Bool

    init() {}

    init(forward: Bool) {
        self.forward = forward
    }

    func perform() async throws -> some IntentResult {
        await IslandController.update { state in
            // iOS 처럼 3초가 지났으면 이전 곡 대신 처음으로 되감는다.
            let rewind = !forward && state.elapsed() > 3
            let track = rewind ? state.track : state.track + (forward ? 1 : -1)
            return .running(track: track, duration: Track.duration)
        }
        return .result()
    }
}

struct EndIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "끄기"

    func perform() async throws -> some IntentResult {
        await IslandController.endAll()
        return .result()
    }
}
