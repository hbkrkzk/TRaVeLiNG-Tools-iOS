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
                            title: "Skyscannerアフィリエイト",
                            subtitle: "Skyscannerの検索リンクからアフィリエイトリンクを生成・短縮します。",
                            systemImage: "link.circle.fill"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        LazyView {
                            BoardingBarcodeView()
                        }
                    } label: {
                        ToolCard(
                            title: "Boarding Barcode",
                            subtitle: "搭乗券の入力情報をもとに、IATA文字列と Aztec / PDF417 バーコードを生成します。",
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
                            subtitle: "資産推移、リタイア時資産、資産寿命を可視化して、FIRE計画の試算ができます。",
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Text("このツールを開く")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.blue.opacity(0.15), in: Capsule())
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    ContentView()
}
