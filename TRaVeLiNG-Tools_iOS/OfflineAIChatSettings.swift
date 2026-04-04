//
//  OfflineAIChatSettings.swift
//  TRaVeLiNG-Tools-iOS
//
//  Created with guidance from Apple Intelligence Chat
//

import SwiftUI

// MARK: - App Settings

enum ChatAppSettings {
    @AppStorage("offlineChat_useStreaming") static var useStreaming: Bool = true
    @AppStorage("offlineChat_temperature") static var temperature: Double = 0.7
    @AppStorage("offlineChat_systemInstructions") static var systemInstructions: String = "あなたは有用なアシスタントです。日本語で簡潔かつ親切に応答してください。"
}

// MARK: - Settings View

struct OfflineAIChatSettings: View {
    @Environment(\.dismiss) private var dismiss
    var onDismiss: (() -> Void)?
    
    @AppStorage("offlineChat_useStreaming") private var useStreaming = ChatAppSettings.useStreaming
    @AppStorage("offlineChat_temperature") private var temperature = ChatAppSettings.temperature
    @AppStorage("offlineChat_systemInstructions") private var systemInstructions = ChatAppSettings.systemInstructions
    
    var body: some View {
        NavigationStack {
            Form {
                Section("生成設定") {
                    Toggle("ストリーミング応答を使用", isOn: $useStreaming)
                        .tint(.blue)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("温度: \(String(format: "%.2f", temperature))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Slider(value: $temperature, in: 0...2, step: 0.1)
                            .tint(.blue)
                    }
                }
                
                Section("システムプロンプト") {
                    TextEditor(text: $systemInstructions)
                        .frame(minHeight: 100)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .navigationTitle("チャット設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        onDismiss?()
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    OfflineAIChatSettings()
}
