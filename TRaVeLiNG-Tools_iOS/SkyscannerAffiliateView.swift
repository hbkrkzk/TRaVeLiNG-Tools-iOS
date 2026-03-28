import SwiftUI

struct SkyscannerAffiliateView: View {
    @State private var skyscannerLink: String = ""
    @State private var generatedURL: String?
    @State private var shortenedURL: String?
    @State private var shareText: String?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showError: Bool = false
    @State private var isViewLoaded: Bool = false
    @State private var showSettingsSheet: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("URLを入力")
                            .font(.headline)
                        
                        HStack(spacing: 8) {
                            TextField("Skyscannerリンク", text: $skyscannerLink)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                            
                            Button(action: pasteFromClipboard) {
                                Image(systemName: "doc.on.clipboard.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    Button(action: generateURL) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "link")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            Text(isLoading ? "生成中..." : "URLを生成")
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading || skyscannerLink.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(isLoading || skyscannerLink.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1)
                    
                    if isViewLoaded {
                        if let text = shareText {
                            resultBox(title: "シェアテキスト", icon: "quote.bubble.fill", content: text, color: .orange)
                        }
                        
                        if let shortUrl = shortenedURL {
                            resultBox(title: "短縮URL", icon: "link.circle.fill", content: shortUrl, color: .purple)
                        }
                        
                        if let url = generatedURL {
                            resultBox(title: "アフィリエイトURL", icon: "checkmark.circle.fill", content: url, color: .green)
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(12)
            }
            .navigationTitle("Skyscanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showSettingsSheet = true }) {
                        Image(systemName: "gear")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "エラーが発生しました")
            }
            .sheet(isPresented: $showSettingsSheet) {
                ShareTextSettingsView(isPresented: $showSettingsSheet)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isViewLoaded = true
                }
            }
        }
    }
    
    @ViewBuilder
    private func resultBox(title: String, icon: String, content: String, color: Color) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(color)
                    .cornerRadius(8)
                
                Text(title)
                    .font(.headline)
                
                Spacer()
            }
            
            Text(content)
                .font(.caption)
                .lineLimit(3)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            Button(action: { copyToClipboard(content) }) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14, weight: .semibold))
                    Text("コピー")
                        .font(.callout.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(color.opacity(0.8))
                .foregroundStyle(.white)
                .cornerRadius(8)
            }
        }
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func generateURL() {
        let trimmedLink = skyscannerLink.trimmingCharacters(in: .whitespaces)
        guard !trimmedLink.isEmpty else {
            errorMessage = "URLを入力してください"
            showError = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        SkyscannerURLService.parseSkyscannerLink(trimmedLink) { info in
            DispatchQueue.main.async {
                guard let info = info else {
                    self.errorMessage = "URLを解析できませんでした"
                    self.showError = true
                    self.isLoading = false
                    return
                }
                
                var affiliateUrl: String?
                if info.isRoundTrip, let returnDate = info.returnDate {
                    affiliateUrl = SkyscannerURLService.generateRoundtripUrl(
                        departure: info.departure,
                        arrival: info.arrival,
                        departDate: info.departureDate,
                        returnDate: returnDate
                    )
                } else {
                    affiliateUrl = SkyscannerURLService.generateOneWayUrl(
                        departure: info.departure,
                        arrival: info.arrival,
                        departDate: info.departureDate
                    )
                }
                
                self.generatedURL = affiliateUrl
                if let url = affiliateUrl {
                    self.shareText = ShareTextService.shared.getRoundTripTemplate()
                        .replacingOccurrences(of: "{URL}", with: url)
                    SkyscannerURLService().shortenURL(url) { shortUrl in
                        DispatchQueue.main.async {
                            self.shortenedURL = shortUrl
                        }
                    }
                }
                self.isLoading = false
            }
        }
    }
    
    private func pasteFromClipboard() {
        if let clipboard = UIPasteboard.general.string {
            skyscannerLink = clipboard
        }
    }
    
    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }
}

// MARK: - Share Text Settings View

struct ShareTextSettingsView: View {
    @Binding var isPresented: Bool
    @State private var roundTripTemplate: String = ""
    @State private var onewayTemplate: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("往復フライト")) {
                    TextEditor(text: $roundTripTemplate)
                        .frame(height: 200)
                }
                
                Section(header: Text("片道フライト")) {
                    TextEditor(text: $onewayTemplate)
                        .frame(height: 200)
                }
                
                Section {
                    Button(action: saveTemplates) {
                        Text("保存する")
                    }
                    Button(action: resetToDefaults) {
                        Text("デフォルトに戻す")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("テンプレート設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") {
                        isPresented = false
                    }
                }
            }
            .onAppear {
                roundTripTemplate = ShareTextService.shared.getRoundTripTemplate()
                onewayTemplate = ShareTextService.shared.getOnewayTemplate()
            }
        }
    }
    
    private func saveTemplates() {
        if ShareTextService.shared.validateTemplate(roundTripTemplate) {
            ShareTextService.shared.setRoundTripTemplate(roundTripTemplate)
        }
        if ShareTextService.shared.validateTemplate(onewayTemplate) {
            ShareTextService.shared.setOnewayTemplate(onewayTemplate)
        }
    }
    
    private func resetToDefaults() {
        ShareTextService.shared.resetToDefaults()
        roundTripTemplate = ShareTextService.shared.getRoundTripTemplate()
        onewayTemplate = ShareTextService.shared.getOnewayTemplate()
    }
}

#Preview {
    SkyscannerAffiliateView()
}
