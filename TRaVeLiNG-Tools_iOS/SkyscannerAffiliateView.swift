import SwiftUI

struct SkyscannerAffiliateView: View {
    @State private var skyscannerLink: String = ""
    @State private var partnerLink: String = ""
    @State private var generatedURL: String?
    @State private var shortenedURL: String?
    @State private var partnerGeneratedURL: String?
    @State private var partnerShortenedURL: String?
    @State private var shareText: String?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showError: Bool = false
    @State private var isViewLoaded: Bool = false
    @State private var showMenuSheet: Bool = false
    @State private var activeMenuTab: Int = 0
    @State private var flightInfo: SkyscannerFlightInfo?
    @State private var showCopyFeedback: String?
    @State private var partnerName: String?
    @State private var campaignId: Int?
    @StateObject private var historyManager = AffiliateURLHistoryManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("URLを入力")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            TextField("Skyscannerリンク", text: $skyscannerLink)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                                .frame(height: 44)
                            
                            TextField("Traveloka / Trip.com (オプション)", text: $partnerLink)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                                .frame(height: 44)
                            
                            Button(action: pasteFromClipboard) {
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.on.clipboard.fill")
                                    Text("ペーストする")
                                }
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .foregroundStyle(Color.blue)
                                .background(Color.clear)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue, lineWidth: 2))
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
                        
                        if let shortUrl = partnerShortenedURL, let pName = partnerName {
                            resultBox(title: "パートナーURL (\(pName))", icon: "link.circle.fill", content: shortUrl, color: .cyan)
                        }
                        
                        if let shortUrl = shortenedURL {
                            resultBox(title: "短縮URL (Skyscanner)", icon: "link.circle.fill", content: shortUrl, color: .purple)
                        }
                        
                        if let url = generatedURL {
                            resultBox(title: "アフィリエイトURL", icon: "checkmark.circle.fill", content: url, color: .green)
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(12)
            }
            .navigationTitle("Affiliate Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button(action: { showMenuSheet = true; activeMenuTab = 0 }) {
                            Label("履歴", systemImage: "clock")
                        }
                        Button(action: { showMenuSheet = true; activeMenuTab = 1 }) {
                            Label("設定", systemImage: "gear")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
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
            .toast(message: $showCopyFeedback)
            .sheet(isPresented: $showMenuSheet) {
                if activeMenuTab == 0 {
                    AffiliateHistoryListView()
                } else {
                    ShareTextSettingsView(isPresented: $showMenuSheet)
                }
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
            
            Button(action: { 
                copyToClipboard(content)
                showCopyFeedback = "コピーしました"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showCopyFeedback = nil
                }
            }) {
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
        let trimmedSkyscannerLink = skyscannerLink.trimmingCharacters(in: .whitespaces)
        let trimmedPartnerLink = partnerLink.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedSkyscannerLink.isEmpty else {
            errorMessage = "Skyscanner URLを入力してください"
            showError = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // async/await で処理を実行
        Task {
            do {
                // URL解析
                guard let info = await parseSkyscannerLinkAsync(trimmedSkyscannerLink) else {
                    await MainActor.run {
                        self.errorMessage = "URLを解析できませんでした"
                        self.showError = true
                        self.isLoading = false
                    }
                    return
                }
                
                // Impact.com API でSkyscannerアフィリエイトURL生成
                let affiliateUrl = try await SkyscannerURLService.generateAffiliateURLDirectAsync(trimmedSkyscannerLink)
                
                // パートナーリンクの処理
                var finalPartnerName: String? = nil
                var finalCampaignId: Int? = nil
                var finalPartnerAffiliateUrl: String? = nil
                var finalPartnerShortenedUrl: String? = nil
                
                if !trimmedPartnerLink.isEmpty {
                    do {
                        let (partnerAffiliateUrl, campaignId) = try await TravelPayoutsAffiliateService.generateAffiliateLink(from: trimmedPartnerLink)
                        finalPartnerName = TravelPayoutsAffiliateService.getPartnerName(campaignId: campaignId)
                        finalCampaignId = campaignId
                        finalPartnerAffiliateUrl = partnerAffiliateUrl
                        
                        // パートナーURLを短縮
                        if let shortened = await shortenURLAsync(partnerAffiliateUrl) {
                            finalPartnerShortenedUrl = shortened
                        } else {
                            finalPartnerShortenedUrl = partnerAffiliateUrl
                        }
                    } catch {
                        print("⚠️ パートナーリンク生成エラー: \(error.localizedDescription)")
                    }
                }
                
                // 短縮URL取得
                let shortUrl = await shortenURLAsync(affiliateUrl)
                
                await MainActor.run {
                    self.flightInfo = info
                    self.generatedURL = affiliateUrl
                    self.partnerGeneratedURL = finalPartnerAffiliateUrl
                    
                    let finalUrl = shortUrl ?? affiliateUrl
                    self.shortenedURL = finalUrl
                    self.partnerShortenedURL = finalPartnerShortenedUrl
                    self.partnerName = finalPartnerName
                    self.campaignId = finalCampaignId
                    
                    // シェアテキスト生成
                    if let partnerName = finalPartnerName, let partnerShortUrl = finalPartnerShortenedUrl {
                        self.shareText = ShareTextService.shared.generateShareTextWithPartner(
                            isRoundTrip: info.isRoundTrip,
                            partnerName: partnerName,
                            partnerURL: partnerShortUrl,
                            skycannerURL: finalUrl
                        )
                    } else {
                        let template = info.isRoundTrip
                            ? ShareTextService.shared.getRoundTripTemplate()
                            : ShareTextService.shared.getOnewayTemplate()
                        self.shareText = template.replacingOccurrences(of: "{URL}", with: finalUrl)
                    }
                    
                    // 履歴に保存
                    self.historyManager.addRecord(
                        departureCode: info.departure,
                        arrivalCode: info.arrival,
                        outboundDate: info.departureDate,
                        returnDate: info.returnDate,
                        shortenedURL: finalUrl,
                        affiliateURL: affiliateUrl,
                        isRoundTrip: info.isRoundTrip,
                        partnerName: finalPartnerName,
                        campaignId: finalCampaignId
                    )
                    
                    self.isLoading = false
                }
            } catch let error as ImpactAffiliateService.ImpactError {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "エラーが発生しました: \(error.localizedDescription)"
                    self.showError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    /// URL解析を非同期で実行
    private func parseSkyscannerLinkAsync(_ link: String) async -> SkyscannerFlightInfo? {
        return await withCheckedContinuation { continuation in
            SkyscannerURLService.parseSkyscannerLink(link) { info in
                continuation.resume(returning: info)
            }
        }
    }
    
    /// URL短縮を非同期で実行
    private func shortenURLAsync(_ url: String) async -> String? {
        return await withCheckedContinuation { continuation in
            SkyscannerURLService().shortenURL(url) { shortUrl in
                continuation.resume(returning: shortUrl)
            }
        }
    }
    
    private func pasteFromClipboard() {
        if let clipboard = UIPasteboard.general.string {
            // パートナーリンクかSkyscannerリンクかを自動判定
            if TravelPayoutsAffiliateService.getCampaignId(from: clipboard) != nil {
                partnerLink = clipboard
            } else {
                skyscannerLink = clipboard
            }
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

// MARK: - History Module

// MARK: - TravelPayouts Affiliate Service

class TravelPayoutsAffiliateService {
    private static let baseURL = "https://api.travelpayouts.com/links/v1/create"
    private static let trs = 532203
    private static let marker = 731698
    
    private static let apiKey: String = {
        if let configPath = Bundle.main.path(forResource: "LocalConfig", ofType: "plist"),
           let config = NSDictionary(contentsOfFile: configPath) as? [String: Any],
           let key = config["TRAVELPAYOUTS_API_KEY"] as? String,
           !key.isEmpty {
            return key
        }
        
        if let key = Bundle.main.infoDictionary?["TRAVELPAYOUTS_API_KEY"] as? String,
           !key.isEmpty {
            return key
        }
        
        return ""
    }()
    
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()
    
    enum TravelPayoutsError: LocalizedError {
        case invalidURL
        case networkError(Error)
        case invalidResponse
        case decodingError(Error)
        case apiError(String)
        case noPartnerURL
        case missingAPIKey
        case invalidPartner
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "無効なURLです"
            case .networkError(let error):
                return "ネットワークエラー: \(error.localizedDescription)"
            case .invalidResponse:
                return "無効なAPIレスポンスです"
            case .decodingError(let error):
                return "レスポンス解析エラー: \(error.localizedDescription)"
            case .apiError(let message):
                return "APIエラー: \(message)"
            case .noPartnerURL:
                return "パートナーURLが返されませんでした"
            case .missingAPIKey:
                return "TravelPayouts API Keyが設定されていません"
            case .invalidPartner:
                return "無効なパートナーです"
            }
        }
    }
    
    private struct LinkRequest: Codable {
        let url: String
        let sub_id: String?
        
        enum CodingKeys: String, CodingKey {
            case url, sub_id
        }
    }
    
    private struct CreateLinksRequest: Codable {
        let trs: Int
        let marker: Int
        let shorten: Bool
        let links: [LinkRequest]
    }
    
    private struct PartnerLink: Codable {
        let url: String
        let code: String
        let partner_url: String?
        let campaign_id: Int?
    }
    
    private struct CreateLinksResponse: Codable {
        let result: Result?
        let code: String
        let status: Int
        
        struct Result: Codable {
            let trs: Int
            let marker: Int
            let shorten: Bool
            let links: [PartnerLink]
        }
    }
    
    static func getPartnerName(campaignId: Int) -> String {
        switch campaignId {
        case 632:
            return "Traveloka"
        case 121:
            return "Trip.com"
        default:
            return "パートナー"
        }
    }
    
    static func getCampaignId(from url: String) -> Int? {
        let travelokaPatterns = [
            "traveloka.com",
            "traveloka.co.jp"
        ]
        let tripcomPatterns = [
            "trip.com",
            "tripadvisor.com"
        ]
        
        if travelokaPatterns.contains(where: { url.lowercased().contains($0) }) {
            return 632
        } else if tripcomPatterns.contains(where: { url.lowercased().contains($0) }) {
            return 121
        }
        return nil
    }
    
    static func generateAffiliateLink(from url: String) async throws -> (partnerURL: String, campaignId: Int) {
        guard !url.isEmpty else {
            throw TravelPayoutsError.invalidURL
        }
        
        guard !apiKey.isEmpty else {
            throw TravelPayoutsError.missingAPIKey
        }
        
        guard let campaignId = getCampaignId(from: url) else {
            throw TravelPayoutsError.invalidPartner
        }
        
        guard let requestURL = URL(string: baseURL) else {
            throw TravelPayoutsError.invalidURL
        }
        
        let linkRequest = LinkRequest(url: url, sub_id: nil)
        let createRequest = CreateLinksRequest(
            trs: trs,
            marker: marker,
            shorten: true,
            links: [linkRequest]
        )
        
        let encoder = JSONEncoder()
        guard let requestBody = try? encoder.encode(createRequest) else {
            throw TravelPayoutsError.invalidURL
        }
        
        var httpRequest = URLRequest(url: requestURL)
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        httpRequest.setValue(apiKey, forHTTPHeaderField: "X-Access-Token")
        httpRequest.httpBody = requestBody
        
        do {
            let (data, response) = try await session.data(for: httpRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TravelPayoutsError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = parseErrorResponse(data)
                throw TravelPayoutsError.apiError("HTTPステータス: \(httpResponse.statusCode) - \(errorMessage)")
            }
            
            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(CreateLinksResponse.self, from: data)
            
            guard let result = apiResponse.result,
                  let firstLink = result.links.first,
                  let partnerURL = firstLink.partner_url,
                  !partnerURL.isEmpty else {
                throw TravelPayoutsError.noPartnerURL
            }
            
            return (partnerURL: partnerURL, campaignId: campaignId)
        } catch let error as TravelPayoutsError {
            throw error
        } catch let error as DecodingError {
            throw TravelPayoutsError.decodingError(error)
        } catch {
            throw TravelPayoutsError.networkError(error)
        }
    }
    
    private static func parseErrorResponse(_ data: Data) -> String {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let message = json["message"] as? String {
                    return message
                }
                if let errors = json["errors"] as? [String: Any] {
                    return String(describing: errors)
                }
            }
        } catch {
            if let errorString = String(data: data, encoding: .utf8) {
                return errorString
            }
        }
        return "不明なエラー"
    }
}
