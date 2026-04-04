import AVFoundation
import Combine

class BrownNoisePlayer: NSObject, ObservableObject {
    static let shared = BrownNoisePlayer()
    
    @Published var isPlaying = false
    @Published var volume: Float = 0.5 {
        didSet {
            player?.volume = volume
        }
    }
    @Published var timerDuration: TimeInterval = 0 // 0 means no timer
    @Published var timeRemaining: TimeInterval = 0
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var timerTask: DispatchSourceTimer?
    
    override init() {
        super.init()
        setupAudioSession()
        setupNotifications()
    }
    
    deinit {
        stop()
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }
    
    // MARK: - Playback Control
    
    func play() {
        guard player != nil || createPlayer() else { return }
        
        player?.play()
        isPlaying = true
        
        if timerDuration > 0 {
            startTimer()
        }
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func stop() {
        player?.pause()
        player = nil
        isPlaying = false
        timeRemaining = 0
        stopTimer()
    }
    
    // MARK: - Player Setup
    
    private func createPlayer() -> Bool {
        guard let audioURL = Bundle.main.url(forResource: "brownnoise_30min", withExtension: "m4a") else {
            print("Brown noise audio file not found")
            return false
        }
        
        let asset = AVAsset(url: audioURL)
        let playerItem = AVPlayerItem(asset: asset)
        
        player = AVPlayer(playerItem: playerItem)
        player?.volume = volume
        
        // Set up looping
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlayerItemDidReachEnd),
            name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        // Observe playback time for timer display
        observePlaybackTime()
        
        return true
    }
    
    @objc private func handlePlayerItemDidReachEnd() {
        // Restart playback from beginning for seamless looping
        player?.seek(to: .zero)
        player?.play()
    }
    
    // MARK: - Timer Management
    
    private func startTimer() {
        stopTimer()
        timeRemaining = timerDuration
        
        let queue = DispatchQueue.main
        let timer = DispatchSource.makeTimerSource(queue: queue)
        
        timer.setEventHandler { [weak self] in
            self?.timeRemaining -= 1
            if self?.timeRemaining ?? 0 <= 0 {
                self?.stop()
            }
        }
        
        timer.schedule(wallDeadline: .now(), repeating: 1.0)
        timer.resume()
        
        timerTask = timer
    }
    
    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
    
    // MARK: - Playback Time Observation
    
    private func observePlaybackTime() {
        guard let player = player else { return }
        
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
            queue: .main
        ) { [weak self] _ in
            // Update UI if needed (optional - for progress display)
        }
    }
    
    // MARK: - Audio Session Interruption Handling
    
    @objc private func handleAudioSessionInterruption(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let interruptionTypeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let interruptionType = AVAudioSession.InterruptionType(rawValue: interruptionTypeValue) else {
            return
        }
        
        switch interruptionType {
        case .began:
            // Interruption started (e.g., phone call)
            pause()
        case .ended:
            // Interruption ended
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    play()
                }
            }
        @unknown default:
            break
        }
    }
}
