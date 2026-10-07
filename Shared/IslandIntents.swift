import ActivityKit
import AppIntents

// 펼친 아일랜드와 잠금화면의 버튼들. LiveActivityIntent 의 perform 은 위젯이 아니라
// 앱 프로세스에서 돌기 때문에, 음악은 앱의 MusicPlayer 를 움직이고 아일랜드는 그 상태를 따라간다.
// 위젯 익스텐션은 버튼을 그리려고 이 타입들만 알면 되므로 WIDGET 에선 몸통을 뺀다.

struct ToggleIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "재생·멈춤"

    func perform() async throws -> some IntentResult {
        #if !WIDGET
        if IslandController.current?.attributes.kind == .music {
            await MusicPlayer.shared.toggle()
        } else {
            await IslandController.update { $0.toggled() }
        }
        #endif
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
        #if !WIDGET
        await MusicPlayer.shared.skip(forward: forward)
        #endif
        return .result()
    }
}

struct EndIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "끄기"

    func perform() async throws -> some IntentResult {
        #if !WIDGET
        await MusicPlayer.shared.stop()
        await IslandController.endAll()
        #endif
        return .result()
    }
}
