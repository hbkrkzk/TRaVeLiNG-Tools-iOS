import SwiftUI

struct BrownNoiseView: View {
    @State private var showTimerPicker = false
    @State private var timerStarted = false
    @State private var displayVolume: Float = 0.5
    @State private var refreshTrigger = UUID()
    
    var body: some View {
        let player = BrownNoisePlayer.shared
        let timerMinutes = UserDefaults.standard.integer(forKey: "brownNoise_timerMinutes")
        
        return ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "waveform.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)
                    
                    Text("Brown Noise")
                        .font(.title2.weight(.bold))
                    
                    Text("フォーカスと睡眠をサポート")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                
                // Playback Controls Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("再生コントロール")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Button(action: {
                                if player.isPlaying {
                                    player.pause()
                                } else {
                                    player.play()
                                }
                                refreshTrigger = UUID()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text(player.isPlaying ? "一時停止" : "再生")
                                        .font(.system(.body, design: .rounded))
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(.blue)
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                            }
                            
                            Button(action: {
                                player.stop()
                                timerStarted = false
                                refreshTrigger = UUID()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "stop.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("停止")
                                        .font(.system(.body, design: .rounded))
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(.red)
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                            }
                        }
                        
                        // Status indicator
                        HStack(spacing: 8) {
                            Circle()
                                .fill(player.isPlaying ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            
                            Text(player.isPlaying ? "再生中" : "停止中")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            if player.isPlaying && timerStarted && player.timerDuration > 0 {
                                Text(formatTime(player.timeRemaining))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Volume Control Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("ボリューム")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "speaker.fill")
                                .foregroundStyle(.secondary)
                            
                            Slider(value: Binding(
                                get: { player.volume },
                                set: { newValue in
                                    player.volume = newValue
                                    displayVolume = newValue
                                    UserDefaults.standard.set(newValue, forKey: "brownNoise_volume")
                                    refreshTrigger = UUID()
                                }
                            ), in: 0...1)
                            
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("\(Int(displayVolume * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .id(refreshTrigger)
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Timer Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("タイマー")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    VStack(spacing: 12) {
                        Button(action: { showTimerPicker.toggle() }) {
                            HStack(spacing: 12) {
                                Image(systemName: "timer")
                                    .foregroundStyle(.blue)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("タイマー設定")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    
                                    Text(timerMinutes == 0 ? "なし" : formatTimerDisplay(timerMinutes))
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        
                        // Start Timer Button
                        if timerMinutes > 0 && !timerStarted {
                            Button(action: {
                                player.timerDuration = TimeInterval(timerMinutes * 60)
                                timerStarted = true
                                if !player.isPlaying {
                                    player.play()
                                }
                                refreshTrigger = UUID()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("タイマーをスタート")
                                        .font(.system(.body, design: .rounded))
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(.green)
                                .foregroundStyle(.white)
                                .cornerRadius(8)
                            }
                        }
                        
                        if timerStarted && player.timerDuration > 0 {
                            VStack(spacing: 8) {
                                HStack {
                                    Text("残り時間:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(formatTime(player.timeRemaining))
                                        .font(.caption.monospacedDigit().weight(.semibold))
                                        .foregroundStyle(.blue)
                                }
                                
                                Button(action: {
                                    player.timerDuration = 0
                                    timerStarted = false
                                    refreshTrigger = UUID()
                                }) {
                                    Text("タイマーをキャンセル")
                                        .font(.caption.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 36)
                                        .background(.gray.opacity(0.3))
                                        .foregroundStyle(.red)
                                        .cornerRadius(6)
                                }
                            }
                            .padding(10)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .onAppear {
            player.volume = UserDefaults.standard.float(forKey: "brownNoise_volume")
            if player.volume == 0 {
                player.volume = 0.5
            }
            displayVolume = player.volume
        }
        .sheet(isPresented: $showTimerPicker) {
            TimerPickerSheet(player: player) {
                timerStarted = false
                refreshTrigger = UUID()
            }
        }
        .navigationTitle("Brown Noise")
        .navigationBarTitleDisplayMode(.inline)
        .id(refreshTrigger)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
    
    private func formatTimerDisplay(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) 分"
        } else if minutes == 60 {
            return "1 時間"
        } else if minutes % 60 == 0 {
            return "\(minutes / 60) 時間"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours) 時間 \(mins) 分"
        }
    }
}

struct TimerPickerSheet: View {
    @State private var selectedMinutes = 0
    @Environment(\.dismiss) var dismiss
    var player: BrownNoisePlayer
    var onDismiss: () -> Void = {}
    
    var timerOptions: [Int] {
        var options: [Int] = []
        // 0 to 120 min (2 hours) in 5 min increments
        for i in stride(from: 0, through: 120, by: 5) {
            options.append(i)
        }
        // 2.5 hours to 12 hours in 30 min increments
        for i in stride(from: 150, through: 720, by: 30) {
            options.append(i)
        }
        return options
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Picker("タイマー時間", selection: $selectedMinutes) {
                    ForEach(timerOptions, id: \.self) { option in
                        if option == 0 {
                            Text("なし").tag(option)
                        } else if option < 60 {
                            Text("\(option) 分").tag(option)
                        } else if option == 60 {
                            Text("1 時間").tag(option)
                        } else if option % 60 == 0 {
                            Text("\(option / 60) 時間").tag(option)
                        } else {
                            let hours = option / 60
                            let mins = option % 60
                            Text("\(hours)h \(mins)m").tag(option)
                        }
                    }
                }
                .pickerStyle(.wheel)
                
                Button(action: {
                    UserDefaults.standard.set(selectedMinutes, forKey: "brownNoise_timerMinutes")
                    onDismiss()
                    dismiss()
                }) {
                    Text("完了")
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("タイマーを設定")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    NavigationStack {
        BrownNoiseView()
    }
}
