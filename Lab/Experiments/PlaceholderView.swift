import SwiftUI

/// 사이트의 "앱 실험 자리". 첫 앱 실험을 만들면 지운다.
struct PlaceholderView: View {
    @State private var bounce = 0

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "flask.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
                .symbolEffect(.bounce, value: bounce)
            Text("첫 앱 실험 준비 중")
                .font(.title3.weight(.semibold))
            Text("눌러 보세요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { bounce += 1 }
    }
}

#Preview {
    PlaceholderView()
}
