import SwiftUI
import AVFoundation
import MediaPlayer

// MARK: - Brown Noise Player Service (Singleton)

class BrownNoisePlayerService: NSObject, ObservableObject {
    static let shared = BrownNoisePlayerService()
    
    private var audioPlayer: AVAudioPlayer?
    private var displayLink: CADisplayLink?
    private var timerTask: Task<Void, Never>?
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var timerStartTime: Date?
    
    @Published var isPlaying: Bool = false
    @Published var remainingSeconds: Int = 0
    @Published var elapsedSeconds: Int = 0
    @Published var currentTimerDuration: Int = 0
    
    override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommands()
        // 常に50%の音量で再生
        if let player = audioPlayer {
            player.volume = 0.5
        }
    }
    
    deinit {
        stopTimer()
        stopBackgroundTask()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.defaultToSpeaker, .duckOthers]
            )
            try audioSession.setPreferredSampleRate(44100)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ AVAudioSession エラー: \(error.localizedDescription)")
        }
    }
    
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        commandCenter.stopCommand.addTarget { [weak self] _ in
            self?.stop()
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            if self?.isPlaying ?? false {
                self?.pause()
            } else {
                self?.resume()
            }
            return .success
        }
    }
    
    private func updateNowPlayingInfo() {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = "Brown Noise Player"
        nowPlayingInfo[MPMediaItemPropertyArtist] = "Relaxation"
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "Brown Noise"
        
        if let player = audioPlayer {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = player.duration
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    func startPlayback(duration: TimeInterval = 0) {
        // ファイルを検索（Resourcesフォルダ内も確認）
        var audioURL: URL?
        
        audioURL = Bundle.main.url(forResource: "brownnoise_30min", withExtension: "m4a")
        
        if audioURL == nil {
            audioURL = Bundle.main.url(forResource: "brownnoise_30min", withExtension: "m4a", subdirectory: "Resources")
        }
        
        guard let audioURL = audioURL else {
            print("❌ オーディオファイルが見つかりません")
            return
        }
        
        do {
            print("📁 オーディオファイルURL: \(audioURL)")
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.delegate = self
            audioPlayer?.volume = 0.5
            audioPlayer?.enableRate = false
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.play()
            
            DispatchQueue.main.async {
                self.isPlaying = true
                self.currentTimerDuration = Int(duration)
                self.remainingSeconds = Int(duration)
                self.elapsedSeconds = 0
                self.timerStartTime = Date()
            }
            
            setupDisplayLink()
            startTimer(duration: duration)
            startBackgroundTask()
            updateNowPlayingInfo()
            
            print("✅ 再生開始")
        } catch {
            print("❌ オーディオ再生エラー: \(error.localizedDescription)")
        }
    }
    
    func pause() {
        audioPlayer?.pause()
        DispatchQueue.main.async {
            self.isPlaying = false
        }
        displayLink?.invalidate()
        displayLink = nil
        stopTimer()
        updateNowPlayingInfo()
        print("⏸ 一時停止")
    }
    
    func resume() {
        guard let audioPlayer = audioPlayer, !isPlaying else { return }
        audioPlayer.play()
        DispatchQueue.main.async {
            self.isPlaying = true
            if self.timerStartTime == nil {
                self.timerStartTime = Date()
            }
        }
        setupDisplayLink()
        startTimer(duration: Double(currentTimerDuration))
        updateNowPlayingInfo()
        print("▶️ 再開")
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        DispatchQueue.main.async {
            self.isPlaying = false
            self.elapsedSeconds = 0
            self.remainingSeconds = 0
        }
        displayLink?.invalidate()
        displayLink = nil
        stopTimer()
        stopBackgroundTask()
        timerStartTime = nil
        currentTimerDuration = 0
        
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
        print("⏹ 停止")
    }
    
    private func setupDisplayLink() {
        if displayLink != nil { return }
        
        let displayLink = CADisplayLink(
            target: self,
            selector: #selector(updateDisplay)
        )
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
    }
    
    @objc private func updateDisplay() {
        guard audioPlayer != nil, isPlaying else {
            displayLink?.invalidate()
            displayLink = nil
            return
        }
        
        DispatchQueue.main.async {
            if let timerStartTime = self.timerStartTime {
                let elapsed = Int(Date().timeIntervalSince(timerStartTime))
                self.elapsedSeconds = elapsed
                
                if self.currentTimerDuration > 0 {
                    self.remainingSeconds = max(0, self.currentTimerDuration - elapsed)
                }
            }
            
            self.updateNowPlayingInfo()
        }
    }
    
    private func startTimer(duration: TimeInterval) {
        guard duration > 0 else { return }
        
        stopTimer()
        
        timerTask = Task {
            let startTime = Date()
            
            while !Task.isCancelled && isPlaying {
                let elapsed = Date().timeIntervalSince(startTime)
                
                if elapsed >= duration {
                    await MainActor.run {
                        self.stop()
                    }
                    break
                }
                
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }
    
    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
    
    private func startBackgroundTask() {
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.stopBackgroundTask()
        }
    }
    
    private func stopBackgroundTask() {
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
        }
    }
}

extension BrownNoisePlayerService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if !flag {
            print("⚠️ オーディオ再生エラー")
        }
    }
}

// MARK: - Timer Options

struct BrownNoiseTimerOption: Hashable, Equatable {
    let minutes: Int
    
    var displayText: String {
        if minutes == 0 {
            return "無制限"
        } else if minutes < 60 {
            return "\(minutes)分"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours)時間"
            } else {
                return "\(hours)時間\(mins)分"
            }
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(minutes)
    }
    
    static func == (lhs: BrownNoiseTimerOption, rhs: BrownNoiseTimerOption) -> Bool {
        lhs.minutes == rhs.minutes
    }
}

class BrownNoiseTimerCalculator {
    static func generateTimerOptions() -> [BrownNoiseTimerOption] {
        var options: [BrownNoiseTimerOption] = [
            BrownNoiseTimerOption(minutes: 0)
        ]
        
        for i in stride(from: 15, through: 120, by: 15) {
            options.append(BrownNoiseTimerOption(minutes: i))
        }
        
        for i in stride(from: 150, through: 720, by: 30) {
            options.append(BrownNoiseTimerOption(minutes: i))
        }
        
        return options
    }
}

// MARK: - Brown Noise Player View

struct BrownNoisePlayerView: View {
    @ObservedObject var audioService = BrownNoisePlayerService.shared
    @State private var selectedTimerOption: BrownNoiseTimerOption = BrownNoiseTimerOption(minutes: 0)
    @State private var timerOptions: [BrownNoiseTimerOption] = []
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    statusSection
                    timerSelectionSection
                    playerControlsSection
                    
                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("Brown Noise Player")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                timerOptions = BrownNoiseTimerCalculator.generateTimerOptions()
                if selectedTimerOption.minutes == 0 && !timerOptions.isEmpty {
                    selectedTimerOption = timerOptions.first ?? BrownNoiseTimerOption(minutes: 0)
                }
            }
        }
    }
    
    private var statusSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: audioService.isPlaying ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(audioService.isPlaying ? .green : .gray)
                
                Text(audioService.isPlaying ? "再生中" : "停止中")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
                
                Spacer()
                
                if audioService.remainingSeconds > 0 && audioService.isPlaying {
                    HStack(spacing: 4) {
                        Image(systemName: "hourglass.circle.fill")
                            .font(.system(size: 14))
                        Text(formatCountdown(audioService.remainingSeconds))
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.blue)
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            if audioService.isPlaying && audioService.remainingSeconds > 0 {
                VStack(spacing: 8) {
                    Text(formatCountdown(audioService.remainingSeconds))
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundStyle(.blue)
                    
                    ProgressView(
                        value: Double(audioService.elapsedSeconds),
                        total: Double(audioService.currentTimerDuration)
                    )
                    .tint(.blue)
                }
                .padding(16)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    private var timerSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("タイマー設定")
                .font(.headline)
            
            if audioService.isPlaying {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "hourglass.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        
                        Text(selectedTimerOption.displayText)
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.semibold)
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            } else {
                Picker("タイマー", selection: $selectedTimerOption) {
                    ForEach(timerOptions, id: \.minutes) { option in
                        Text(option.displayText).tag(option)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 140)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var playerControlsSection: some View {
        HStack(spacing: 12) {
            // スタートボタン
            Button(action: {
                audioService.startPlayback(
                    duration: Double(selectedTimerOption.minutes * 60)
                )
            }) {
                Image(systemName: "play.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.white)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .disabled(audioService.isPlaying)
            .opacity(audioService.isPlaying ? 0.5 : 1)
            
            // 停止ボタン
            Button(action: { audioService.stop() }) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.white)
                    .background(Color.red)
                    .cornerRadius(12)
            }
            .disabled(!audioService.isPlaying)
            .opacity(!audioService.isPlaying ? 0.5 : 1)
        }
    }
    
    private func formatCountdown(_ seconds: Int) -> String {
        let totalSeconds = max(0, seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

#Preview {
    BrownNoisePlayerView()
}
