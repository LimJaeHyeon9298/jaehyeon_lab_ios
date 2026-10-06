import SwiftUI

/// 실험 목록. `-experiment <id>` 로 실행하면 그 실험 화면에서 바로 시작한다.
/// 시뮬레이터에서 녹화할 때 목록을 거치지 않으려고 둔 길이다.
struct ExperimentList: View {
    @State private var path: [Experiment] = {
        let id = UserDefaults.standard.string(forKey: "experiment")
        return id.flatMap { Experiments.find($0) }.map { [$0] } ?? []
    }()

    var body: some View {
        NavigationStack(path: $path) {
            List(Experiments.all) { experiment in
                NavigationLink(value: experiment) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(experiment.title)
                            .font(.headline)
                        Text(experiment.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("실험실")
            .navigationDestination(for: Experiment.self) { experiment in
                experiment.content()
                    .navigationTitle(experiment.title)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

#Preview {
    ExperimentList()
}
