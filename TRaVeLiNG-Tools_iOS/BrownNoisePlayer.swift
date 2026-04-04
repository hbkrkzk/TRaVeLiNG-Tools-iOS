import SwiftUI
import AVFoundation

// MARK: - Brown Noise Player Service

class BrownNoisePlayerService: NSObject, ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    private var displayLink: CADisplayLink?
    private var timerTask: Task<Void, Never>?
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private let startTime = Date()
    
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Float = 1.0 {
        didSet {
            audioPlayer?.volume = volume
        }
    }
    @Published var remainingSeconds: Int = 0
    @Published var elapsedSeconds: Int = 0
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    deinit {
        stopTimer()
        stopBackgroundTask()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ AVAudioSession エラー: \(error.localizedDescription)")
        }
    }
    
    func startPlayback(duration: TimeInterval = 0) {
        guard let audioURL = Bundle.main.url(forResource: "brownnoise_30min", withExtension: "m4a") else {
            print("❌ オーディオファイルが見つかりません")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.delegate = self
            audioPlayer?.volume = volume
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.play()
            
            isPlaying = true
            self.duration = audioPlayer?.duration ?? 0
            remainingSeconds = Int(duration)
            elapsedSeconds = 0
            
            setupDisplayLink()
            startTimer(duration: duration)
            startBackgroundTask()
            
            print("✅ 再生開始")
        } catch {
            print("❌ オーディオ再生エラー: \(error.localizedDescription)")
        }
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        displayLink?.invalidate()
        displayLink = nil
        print("⏸ 一時停止")
    }
    
    func resume() {
        guard let audioPlayer = audioPlayer, !isPlaying else { return }
        audioPlayer.play()
        isPlaying = true
        setupDisplayLink()
        print("▶️ 再開")
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0
        elapsedSeconds = 0
        remainingSeconds = 0
        displayLink?.invalidate()
        displayLink = nil
        stopTimer()
        stopBackgroundTask()
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
        guard let audioPlayer = audioPlayer, isPlaying else {
            displayLink?.invalidate()
            displayLink = nil
            return
        }
        
        DispatchQueue.main.async {
            self.currentTime = audioPlayer.currentTime
            
            if self.remainingSeconds > 0 {
                self.elapsedSeconds = Int(Date().timeIntervalSince(self.startTime))
            }
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
    @StateObject private var audioService = BrownNoisePlayerService()
    @State private var selectedTimerOption: BrownNoiseTimerOption = BrownNoiseTimerOption(minutes: 0)
    @State private var timerOptions: [BrownNoiseTimerOption] = []
    @State private var volumeLevel: Float = 1.0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    statusSection
                    playerControlsSection
                    timerSection
                    volumeControlSection
                    
                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("ブラウンノイズ")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                timerOptions = BrownNoiseTimerCalculator.generateTimerOptions()
                selectedTimerOption = timerOptions.first ?? BrownNoiseTimerOption(minutes: 0)
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
                
                if audioService.remainingSeconds > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "hourglass.circle.fill")
                            .font(.system(size: 14))
                        Text(formatTime(audioService.remainingSeconds - audioService.elapsedSeconds))
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.blue)
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            if audioService.duration > 0 {
                VStack(spacing: 6) {
                    ProgressView(
                        value: audioService.currentTime / audioService.duration
                    )
                    .tint(.blue)
                    
                    HStack {
                        Text(formatTime(Int(audioService.currentTime)))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text(formatTime(Int(audioService.duration)))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    private var playerControlsSection: some View {
        HStack(spacing: 12) {
            Button(action: { audioService.stop() }) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.white)
                    .background(Color.red)
                    .cornerRadius(10)
            }
            .disabled(!audioService.isPlaying && audioService.currentTime == 0)
            .opacity(!audioService.isPlaying && audioService.currentTime == 0 ? 0.5 : 1)
            
            Button(action: {
                if audioService.isPlaying {
                    audioService.pause()
                } else if audioService.currentTime > 0 {
                    audioService.resume()
                } else {
                    audioService.startPlayback(
                        duration: Double(selectedTimerOption.minutes * 60)
                    )
                }
            }) {
                Image(systemName: audioService.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.white)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
    }
    
    private var timerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("タイマー")
                .font(.headline)
            
            Picker("タイマー", selection: $selectedTimerOption) {
                ForEach(timerOptions, id: \.minutes) { option in
                    Text(option.displayText).tag(option)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
            .disabled(audioService.isPlaying)
            .opacity(audioService.isPlaying ? 0.6 : 1)
            
            if !audioService.isPlaying && audioService.currentTime == 0 {
                Text("再生前にタイマーを設定できます")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var volumeControlSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 24)
                
                Slider(
                    value: $volumeLevel,
                    in: 0...1,
                    step: 0.05
                )
                .onChange(of: volumeLevel) { newValue in
                    audioService.volume = newValue
                }
                
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 24)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
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
