import SwiftUI

/// 실험 하나. id 는 사이트(jaehyeon_portfolio)의 src/data/lab.ts slug 와 맞춘다.
struct Experiment: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let content: @MainActor () -> AnyView

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// 새 실험은 Experiments/ 에 화면을 만들고 여기에 등록한다. 최신순.
@MainActor
enum Experiments {
    static let all: [Experiment] = [
        Experiment(
            id: "app-video-test",
            title: "앱 실험 자리",
            summary: "첫 앱 실험을 만들기 전까지 쓰는 임시 화면.",
            content: { AnyView(PlaceholderView()) }
        ),
    ]

    static func find(_ id: String) -> Experiment? {
        all.first { $0.id == id }
    }
}
