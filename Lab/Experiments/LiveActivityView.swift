import ActivityKit
import SwiftUI

/// 진짜 다이내믹 아일랜드. 사이트의 웹 실험에서 흉내 냈던 음악과 타이머를
/// 라이브 액티비티로 띄운다. 켜고 홈으로 나가면 아일랜드에 뜬다.
/// `-start music` 이나 `-start timer` 로 실행하면 들어오자마자 띄운다(녹화용).
struct LiveActivityView: View {
    /// 지금 떠 있는 것. 앱이 앞에 있는 동안엔 iOS 가 아일랜드에 띄우지 않으므로
    /// 눌렀을 때 무엇이 떴는지 여기서 보여 준다.
    @State private var running: IslandAttributes.Kind?
    @State private var error: String?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Capsule()
                        .fill(.black)
                        .frame(width: 96, height: 30)
                        .overlay {
                            if let running {
                                HStack {
                                    Image(systemName: running == .music ? "music.note" : "timer")
                                    Spacer()
                                    Image(systemName: "waveform")
                                        .symbolEffect(.variableColor.iterative, isActive: running == .music)
                                        .opacity(running == .music ? 1 : 0)
                                }
                                .font(.caption.weight(.bold))
                                .foregroundStyle(running == .music ? .pink : .orange)
                                .padding(.horizontal, 10)
                                .transition(.opacity.combined(with: .scale))
                            }
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(status)
                            .font(.headline)
                        Text(running == nil ? "아래에서 하나 골라 띄워 보자." : "홈으로 나가면 아일랜드에 보인다.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
                .animation(.spring(duration: 0.4, bounce: 0.3), value: running)
            }

            Section {
                Button("음악 띄우기", systemImage: "music.note") {
                    start(.music)
                }
                Button("라면 타이머 띄우기", systemImage: "timer") {
                    start(.timer)
                }
                Button("끄기", systemImage: "xmark", role: .destructive) {
                    Task {
                        MusicPlayer.shared.stop()
                        await IslandController.endAll()
                        running = nil
                    }
                }
                .disabled(running == nil)
            } footer: {
                Text("앱이 화면 앞에 있는 동안에는 iOS 가 아일랜드에 띄우지 않는다. 홈으로 나가면 뜨고, 길게 누르면 펼쳐지며, 펼친 아일랜드의 버튼도 동작한다.")
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
        .sensoryFeedback(.success, trigger: running) { _, new in new != nil }
        .task {
            refresh()
            let kind = UserDefaults.standard.string(forKey: "start").flatMap(IslandAttributes.Kind.init)
            if let kind { start(kind) }
        }
        // 아일랜드의 끄기 버튼으로 끄고 돌아왔을 수 있다.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
    }

    private var status: String {
        switch running {
        case .music: "음악이 떠 있다"
        case .timer: "라면 타이머가 떠 있다"
        case nil: "떠 있는 게 없다"
        }
    }

    private func refresh() {
        running = IslandController.current?.attributes.kind
    }

    private func start(_ kind: IslandAttributes.Kind) {
        Task {
            do {
                MusicPlayer.shared.stop()
                try await IslandController.start(kind)
                if kind == .music { await MusicPlayer.shared.play(track: 0) }
                running = kind
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
