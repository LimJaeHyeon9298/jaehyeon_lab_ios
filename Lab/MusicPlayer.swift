import AVFoundation
import MediaPlayer
import UIKit

/// 음악 아일랜드의 실제 소리. 재생·멈춤·곡 넘김·위치 옮기기는 모두 여기서 하고,
/// 그때마다 지금 위치를 아일랜드에 넘겨 따라오게 한다. 곡이 끝나면 다음 곡으로 넘어간다.
///
/// 아일랜드는 두 가지로 띄울 수 있다.
/// - 직접 만든 아일랜드: 라이브 액티비티. 모양을 마음대로 그리지만 버튼만 눌린다.
/// - 시스템 아일랜드: "지금 재생 중" 정보를 넘기면 iOS 가 자기 UI 로 띄운다.
///   음악 앱들의 아일랜드가 이쪽이라 재생 막대를 끌 수 있지만, 모양은 손댈 수 없다.
@MainActor
final class MusicPlayer {
    enum Mode: String, CaseIterable {
        case liveActivity, system
    }

    static let shared = MusicPlayer()

    private(set) var mode = Mode.liveActivity
    var isActive: Bool { player.currentItem != nil }

    private let player = AVPlayer()
    private var track = 0
    private var duration = Track.duration
    private var artwork: [Int: UIImage] = [:]
    private var endObserver: NSObjectProtocol?
    private var commandsReady = false

    private init() {}

    func start(_ mode: Mode) async throws {
        stop()
        self.mode = mode
        if mode == .liveActivity {
            try await IslandController.start(.music)
        } else {
            await IslandController.endAll()
        }
        await play(track: 0)
    }

    /// 듣던 자리에서 끊지 않고 아일랜드만 바꿔 띄운다.
    func switchMode(to mode: Mode) async throws {
        guard mode != self.mode else { return }
        self.mode = mode
        guard isActive else { return }
        if mode == .liveActivity {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            try await IslandController.start(.music)
        } else {
            await IslandController.endAll()
        }
        await sync()
    }

    func play(track: Int) async {
        self.track = track
        duration = Track.duration
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        setUpCommands()

        let item = AVPlayerItem(url: Track.at(track).preview)
        player.replaceCurrentItem(with: item)
        observeEnd(of: item)
        player.play()
        // 아일랜드는 버튼의 perform() 이 끝나야 다시 그려진다. 그래서 곡 길이를 네트워크로
        // 읽는 건 기다리지 않고, 일단 30초로 띄운 뒤 길이가 오면 한 번 더 맞춘다.
        await sync()
        Task { await loadDuration(of: item) }
        Task { await loadArtwork(for: track) }
    }

    func toggle() async {
        if player.currentItem == nil {
            await play(track: track)
        } else if player.rate == 0 {
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
            await seek(to: 0)
        } else {
            await play(track: track + (forward ? 1 : -1))
        }
    }

    func seek(to seconds: TimeInterval) async {
        await player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        await sync()
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        endObserver.map(NotificationCenter.default.removeObserver)
        endObserver = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - 아일랜드에 넘기기

    private var elapsed: TimeInterval {
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? seconds : 0
    }

    private func sync() async {
        switch mode {
        case .liveActivity:
            var state = IslandAttributes.ContentState.running(track: track, duration: duration, elapsed: elapsed)
            if player.rate == 0 { state.pausedAt = .now }
            await IslandController.set(state)
        case .system:
            publishNowPlaying()
        }
    }

    /// 위치와 재생 속도만 넘기면 시스템이 막대를 알아서 흘린다.
    private func publishNowPlaying() {
        let current = Track.at(track)
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: current.title,
            MPMediaItemPropertyArtist: current.artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: player.rate,
        ]
        if let image = artwork[track] {
            info[MPMediaItemPropertyArtwork] = Self.artwork(image)
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// 시스템은 표지를 백그라운드 스레드에서 달라고 한다. 메인 액터 안에서 만든 클로저는
    /// 메인 스레드 전용으로 추론되어 그 자리에서 앱이 죽으므로, 메인 액터 밖에서 만든다.
    private nonisolated static func artwork(_ image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    /// 같은 이유로 명령 처리기도 메인 액터 밖에서 만들고, 할 일만 메인 액터로 넘긴다.
    private nonisolated static func on(
        _ command: MPRemoteCommand,
        _ action: @escaping @Sendable @MainActor (MPRemoteCommandEvent) async -> Void
    ) {
        command.addTarget { event in
            nonisolated(unsafe) let event = event
            Task { @MainActor in await action(event) }
            return .success
        }
    }

    /// 시스템 아일랜드·잠금화면·제어 센터의 버튼과 막대가 여기로 들어온다.
    private func setUpCommands() {
        guard !commandsReady else { return }
        commandsReady = true
        let center = MPRemoteCommandCenter.shared()
        let on = Self.on
        on(center.playCommand) { [unowned self] _ in if player.rate == 0 { await toggle() } }
        on(center.pauseCommand) { [unowned self] _ in if player.rate != 0 { await toggle() } }
        on(center.togglePlayPauseCommand) { [unowned self] _ in await toggle() }
        on(center.nextTrackCommand) { [unowned self] _ in await skip(forward: true) }
        on(center.previousTrackCommand) { [unowned self] _ in await skip(forward: false) }
        on(center.changePlaybackPositionCommand) { [unowned self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return }
            await seek(to: event.positionTime)
        }
    }

    // MARK: - 불러오기

    private func loadDuration(of item: AVPlayerItem) async {
        guard let length = try? await item.asset.load(.duration).seconds,
              length.isFinite, length > 0,
              player.currentItem === item else { return }
        // 미리듣기는 거의 30초라 차이가 작으면 업데이트를 아낀다.
        guard abs(length - duration) > 0.5 else { return }
        duration = length
        await sync()
    }

    private func loadArtwork(for track: Int) async {
        guard artwork[track] == nil,
              let (data, _) = try? await URLSession.shared.data(from: Track.at(track).artwork),
              let image = UIImage(data: data) else { return }
        artwork[track] = image
        if mode == .system && self.track == track { publishNowPlaying() }
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
