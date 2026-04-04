import SwiftUI

struct BrownNoiseView: View {
    @State private var player = BrownNoisePlayer.shared
    @AppStorage("brownNoise_volume") private var savedVolume: Float = 0.5
    @AppStorage("brownNoise_timerMinutes") private var timerMinutes: Int = 0
    @State private var showTimerPicker = false
    
    var body: some View {
        ScrollView {
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
                            
                            if player.isPlaying && player.timerDuration > 0 {
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
                            
                            Slider(value: $player.volume, in: 0...1)
                                .onChange(of: player.volume) { _, newValue in
                                    savedVolume = newValue
                                }
                            
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("\(Int(player.volume * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
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
                                    Text("タイマー")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    
                                    Text(timerMinutes == 0 ? "なし" : "\(timerMinutes) 分")
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
                        
                        if timerMinutes > 0 {
                            Text("指定時間後に自動停止します")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Info Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("情報")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        InfoRow(icon: "info.circle", title: "バックグラウンド再生", value: "有効")
                        InfoRow(icon: "phone", title: "通話割り込み", value: "対応済み")
                        InfoRow(icon: "lock", title: "デバイスロック中", value: "再生継続")
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
            player.volume = savedVolume
            player.timerDuration = TimeInterval(timerMinutes * 60)
        }
        .sheet(isPresented: $showTimerPicker) {
            TimerPickerSheet(minutes: $timerMinutes, player: player)
        }
        .navigationTitle("Brown Noise")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct TimerPickerSheet: View {
    @Binding var minutes: Int
    @Environment(\.dismiss) var dismiss
    var player: BrownNoisePlayer
    
    let timerOptions = [0, 5, 10, 15, 30, 45, 60, 90, 120]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Picker("タイマー時間", selection: $minutes) {
                    ForEach(timerOptions, id: \.self) { option in
                        if option == 0 {
                            Text("なし").tag(option)
                        } else {
                            Text("\(option) 分").tag(option)
                        }
                    }
                }
                .pickerStyle(.wheel)
                
                Button(action: {
                    player.timerDuration = TimeInterval(minutes * 60)
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
