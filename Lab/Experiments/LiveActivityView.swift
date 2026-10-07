import ActivityKit
import SwiftUI

/// 진짜 다이내믹 아일랜드. 사이트의 웹 실험에서 흉내 냈던 음악과 타이머를
/// 라이브 액티비티로 띄운다. 켜고 홈으로 나가면 아일랜드에 뜬다.
/// `-start music` 이나 `-start timer` 로 실행하면 들어오자마자 띄운다(녹화용).
struct LiveActivityView: View {
    @State private var error: String?

    var body: some View {
        List {
            Section {
                Button("음악 띄우기", systemImage: "music.note") {
                    start(.music)
                }
                Button("라면 타이머 띄우기", systemImage: "timer") {
                    start(.timer)
                }
                Button("끄기", systemImage: "xmark", role: .destructive) {
                    Task { await IslandController.endAll() }
                }
            } footer: {
                Text("띄운 뒤 홈으로 나가면 아일랜드에 뜬다. 길게 누르면 펼쳐지고, 펼친 아일랜드의 버튼도 동작한다.")
            }

            if !ActivityAuthorizationInfo().areActivitiesEnabled {
                Text("설정에서 이 앱의 실시간 현황이 꺼져 있다.")
                    .foregroundStyle(.red)
            }
            if let error {
                Text(error)
                    .foregroundStyle(.red)
            }
        }
        .task {
            let kind = UserDefaults.standard.string(forKey: "start").flatMap(IslandAttributes.Kind.init)
            if let kind { start(kind) }
        }
    }

    private func start(_ kind: IslandAttributes.Kind) {
        Task {
            do {
                try await IslandController.start(kind)
                error = nil
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

#Preview {
    LiveActivityView()
}
