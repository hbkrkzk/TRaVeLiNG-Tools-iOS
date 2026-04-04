import SwiftUI

// MARK: - LazyView ラッパー（ビューの遅延初期化）
struct LazyView<Content: View>: View {
    let build: () -> Content
    
    init(@ViewBuilder _ build: @escaping () -> Content) {
        self.build = build
    }
    
    var body: some View {
        build()
    }
}

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TRaVeLiNG Tools")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        Text("使いたいツールを選んで開始してください。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )

                    NavigationLink {
                        LazyView {
                            SkyscannerAffiliateView()
                        }
                    } label: {
                        ToolCard(
                            title: "Skyscanner Link",
                            subtitle: "",
                            systemImage: "link.circle.fill"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        LazyView {
                            BrownNoisePlayerView()
                        }
                    } label: {
                        ToolCard(
                            title: "Brown Noise Player",
                            subtitle: "",
                            systemImage: "waveform.circle.fill"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        LazyView {
                            OfflineAIChatView()
                        }
                    } label: {
                        ToolCard(
                            title: "Offline AI Chat",
                            subtitle: "",
                            systemImage: "sparkles",
                            tag: "AI"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        LazyView {
                            OfflineAITranslatorView()
                        }
                    } label: {
                        ToolCard(
                            title: "Offline AI Translator",
                            subtitle: "",
                            systemImage: "globe",
                            tag: "AI"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        LazyView {
                            BoardingBarcodeView()
                        }
                    } label: {
                        ToolCard(
                            title: "Boarding Pass Code",
                            subtitle: "",
                            systemImage: "airplane.departure"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        LazyView {
                            FireSimulatorView()
                        }
                    } label: {
                        ToolCard(
                            title: "FIRE Simulator",
                            subtitle: "",
                            systemImage: "flame.fill"
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .navigationTitle("ホーム")
        }
    }
}

private struct ToolCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tag: String?
    
    init(title: String, subtitle: String, systemImage: String, tag: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tag = tag
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.primary)
            
            if let tag = tag {
                Text(tag)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue)
                    .cornerRadius(4)
            }
            
            Spacer()
            
            Text("開く")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.blue.opacity(0.15), in: Capsule())
                .foregroundColor(.blue)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    ContentView()
}
