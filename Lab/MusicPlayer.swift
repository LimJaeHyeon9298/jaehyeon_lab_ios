import AVFoundation

/// 음악 아일랜드의 실제 소리. 재생·멈춤·곡 넘김은 모두 여기서 하고,
/// 그때마다 지금 위치를 라이브 액티비티에 넘겨 아일랜드가 따라오게 한다.
/// 곡이 끝나면 다음 곡으로 넘어간다. 홈으로 나가도 백그라운드 오디오로 계속 재생된다.
@MainActor
final class MusicPlayer {
    static let shared = MusicPlayer()

    private let player = AVPlayer()
    private var track = 0
    private var duration = Track.duration
    private var endObserver: NSObjectProtocol?

    private init() {}

    func play(track: Int) async {
        self.track = track
        duration = Track.duration
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)

        let item = AVPlayerItem(url: Track.at(track).preview)
        player.replaceCurrentItem(with: item)
        observeEnd(of: item)
        player.play()
        // 아일랜드는 버튼의 perform() 이 끝나야 다시 그려진다. 그래서 곡 길이를 네트워크로
        // 읽는 건 기다리지 않고, 일단 30초로 띄운 뒤 길이가 오면 한 번 더 맞춘다.
        await sync()
        Task { await loadDuration(of: item) }
    }

    private func loadDuration(of item: AVPlayerItem) async {
        guard let length = try? await item.asset.load(.duration).seconds,
              length.isFinite, length > 0,
              player.currentItem === item else { return }
        // 미리듣기는 거의 30초라 차이가 작으면 업데이트를 아낀다.
        guard abs(length - duration) > 0.5 else { return }
        duration = length
        await sync()
    }

    func toggle() async {
        if player.currentItem == nil {
            await play(track: track)
        } else if player.timeControlStatus == .paused {
            player.play()
            await sync()
        } else {
            player.pause()
            await sync()
        }
    }

    func skip(forward: Bool) async {
        // iOS 처럼 3초가 지났으면 이전 곡 대신 처음으로 되감는다.
        if !forward && player.currentTime().seconds > 3 {
            await player.seek(to: .zero)
            player.play()
            await sync()
        } else {
            await play(track: track + (forward ? 1 : -1))
        }
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        endObserver.map(NotificationCenter.default.removeObserver)
        endObserver = nil
    }

    private func sync() async {
        let elapsed = player.currentTime().seconds.isFinite ? player.currentTime().seconds : 0
        var state = IslandAttributes.ContentState.running(track: track, duration: duration, elapsed: elapsed)
        if player.rate == 0 { state.pausedAt = .now }
        await IslandController.set(state)
    }

    private func observeEnd(of item: AVPlayerItem) {
        endObserver.map(NotificationCenter.default.removeObserver)
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                await self.play(track: self.track + 1)
            }
        }
    }
}
