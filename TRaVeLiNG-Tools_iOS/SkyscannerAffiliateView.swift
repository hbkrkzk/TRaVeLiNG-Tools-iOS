import SwiftUI

struct SkyscannerAffiliateView: View {
    @State private var skyscannerLink: String = ""
    @State private var tripComEnabled: Bool = false
    @State private var travelokaEnabled: Bool = false
    @State private var kiwiComEnabled: Bool = false
    @State private var generatedURL: String?
    @State private var shortenedURL: String?
    @State private var tripShortenedURL: String?
    @State private var travelokaShortenedURL: String?
    @State private var kiwiShortenedURL: String?
    @State private var shareText: String?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showError: Bool = false
    @State private var isViewLoaded: Bool = false
    @State private var showMenuSheet: Bool = false
    @State private var activeMenuTab: Int = 0
    @State private var flightInfo: SkyscannerFlightInfo?
    @State private var showCopyFeedback: String?
    @StateObject private var historyManager = AffiliateURLHistoryManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Skyscannerリンク入力
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Skyscannerリンク")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            TextField("リンクをペーストする", text: $skyscannerLink)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                                .frame(height: 44)
                            
                            HStack(spacing: 8) {
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
                                
                                Button(action: { skyscannerLink = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16))
                                        .frame(width: 44, height: 48)
                                        .foregroundStyle(.gray)
                                        .background(Color.clear)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // パートナー選択
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("パートナー選択")
                                .font(.headline)
                            Spacer()
                            Button(action: {
                                tripComEnabled = true
                                travelokaEnabled = true
                                kiwiComEnabled = true
                            }) {
                                Text("すべて選択")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundStyle(.blue)
                                    .cornerRadius(6)
                            }
                        }
                        
                        HStack(spacing: 12) {
                            Toggle(isOn: $kiwiComEnabled) {
                                Text("kiwi")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .toggleStyle(CompactToggleStyle())

                            Toggle(isOn: $tripComEnabled) {
                                Text("Trip")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .toggleStyle(CompactToggleStyle())
                            
                            Toggle(isOn: $travelokaEnabled) {
                                Text("トラベロカ")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .toggleStyle(CompactToggleStyle())
                        }
                        .padding(.vertical, 4)
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // 生成ボタン
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
                        
                        if let shortUrl = travelokaShortenedURL {
                            resultBox(title: "短縮URL (トラベロカ)", icon: "link.circle.fill", content: shortUrl, color: .blue)
                        }

                        if let shortUrl = kiwiShortenedURL {
                            resultBox(title: "短縮URL (kiwi)", icon: "link.circle.fill", content: shortUrl, color: .green)
                        }

                        if let shortUrl = tripShortenedURL {
                            resultBox(title: "短縮URL (Trip)", icon: "link.circle.fill", content: shortUrl, color: .cyan)
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
        let trimmedLink = skyscannerLink.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedLink.isEmpty else {
            errorMessage = "Skyscanner URLを入力してください"
            showError = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Skyscannerリンク解析
                guard let info = await parseSkyscannerLinkAsync(trimmedLink) else {
                    await MainActor.run {
                        self.errorMessage = "URLを解析できませんでした"
                        self.showError = true
                        self.isLoading = false
                    }
                    return
                }
                
                // Skyscanner アフィリエイトURL生成
                let affiliateUrl = try await SkyscannerURLService.generateAffiliateURLDirectAsync(trimmedLink)
                let shortUrl = await shortenURLAsync(affiliateUrl) ?? affiliateUrl
                
                // パートナーURLの生成
                var tripShortUrl: String?
                var travelokaShortUrl: String?
                var kiwiShortUrl: String?
                
                if tripComEnabled {
                    if let tripUrl = generateTripURL(info: info) {
                        tripShortUrl = await generatePartnerAffiliateLink(url: tripUrl, campaignId: 121)
                    }
                }
                
                if travelokaEnabled {
                    if let travelokaUrl = generateTravelokaURL(info: info) {
                        travelokaShortUrl = await generatePartnerAffiliateLink(url: travelokaUrl, campaignId: 632)
                    }
                }
                
                if kiwiComEnabled {
                    if let kiwiUrl = generateKiwiURL(info: info) {
                        kiwiShortUrl = await generatePartnerAffiliateLink(url: kiwiUrl, campaignId: 3791)
                    }
                }
                
                // シェアテキスト生成
                let shareText = generateShareText(
                    isRoundTrip: info.isRoundTrip,
                    tripShortUrl: tripShortUrl,
                    travelokaShortUrl: travelokaShortUrl,
                    kiwiShortUrl: kiwiShortUrl,
                    skyscannerShortUrl: shortUrl
                )
                
                await MainActor.run {
                    self.flightInfo = info
                    self.generatedURL = affiliateUrl
                    self.shortenedURL = shortUrl
                    self.tripShortenedURL = tripShortUrl
                    self.travelokaShortenedURL = travelokaShortUrl
                    self.kiwiShortenedURL = kiwiShortUrl
                    self.shareText = shareText
                    self.isLoading = false
                    
                    // 履歴に保存
                    self.historyManager.addRecord(
                        departureCode: info.departure,
                        arrivalCode: info.arrival,
                        outboundDate: info.departureDate,
                        returnDate: info.returnDate,
                        shortenedURL: shortUrl,
                        affiliateURL: affiliateUrl,
                        isRoundTrip: info.isRoundTrip,
                        tripShortUrl: tripShortUrl,
                        travelokaShortUrl: travelokaShortUrl,
                        kiwiShortUrl: kiwiShortUrl,
                        shareText: shareText
                    )
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
    
    private func generateTripURL(info: SkyscannerFlightInfo) -> String? {
        let baseURL = "https://jp.trip.com/flights/showfarefirst"
        let isRoundTrip = info.isRoundTrip
        let rdateValue = isRoundTrip ? formatDateForTrip(info.returnDate ?? info.departureDate) : formatDateForTrip(info.departureDate)
        
        // 空港コードの処理
        func formatCode(_ code: String) -> String {
            let upper = code.uppercased()
            if upper == "CSHA" { return "sha" } // CSHAはSHAに変換
            return String(upper.prefix(3)).lowercased() // 常に3レターに変換
        }
        
        let departure = formatCode(info.departure)
        let arrival = formatCode(info.arrival)
        
        // URLコンポーネントの順序を重視
        let urlString = "\(baseURL)?dcity=\(departure)&acity=\(arrival)&ddate=\(formatDateForTrip(info.departureDate))&rdate=\(rdateValue)&triptype=\(isRoundTrip ? "rt" : "ow")&class=y&lowpricesource=searchform&quantity=1&searchboxarg=t&nonstoponly=off&locale=ja-JP&curr=JPY"
        
        return urlString
    }
    
    private func generateTravelokaURL(info: SkyscannerFlightInfo) -> String? {
        let isRoundTrip = info.isRoundTrip
        let baseURL = "https://www.traveloka.com/ja-jp/flight"
        let endpoint = isRoundTrip ? "fulltwosearch" : "fullsearch"
        
        // 特殊な変換マッピング
        let customMapping: [String: String] = [
            "TPET": "TAIA",
            "BJSA": "BEIA",
            "TYOA": "TYOA",
            "CSHA": "SHAA",
            "BKKT": "BKKA",
            "NYCA": "NEWA",
            "SELA": "SEOA"
        ]
        
        // 空港コードの処理
        func formatCode(_ code: String) -> String {
            let upper = code.uppercased()
            
            // カスタムマッピングがある場合は適用
            if let mapped = customMapping[upper] {
                return mapped
            }
            
            // 4レターで末尾がAならそのまま、それ以外で4レターなら3レターに
            if upper.count == 4 && !upper.hasSuffix("A") {
                return String(upper.prefix(3))
            }
            return upper
        }
        
        let departure = formatCode(info.departure)
        let arrival = formatCode(info.arrival)
        
        let depDate = formatDateForTraveloka(info.departureDate)
        let retDate = isRoundTrip ? formatDateForTraveloka(info.returnDate ?? info.departureDate) : "NA"
        
        // URLコンポーネントの順序を重視
        let urlString = "\(baseURL)/\(endpoint)?ap=\(departure).\(arrival)&dt=\(depDate).\(retDate)&ps=1.0.0&sc=ECONOMY&funnelSource=SEO-Default-SearchForm"
        
        return urlString
    }

    private func generateKiwiURL(info: SkyscannerFlightInfo) -> String? {
        // 空港コードの処理
        func formatCode(_ code: String) -> String {
            let upper = code.uppercased()
            if upper == "CSHA" { return "SHA" } // CSHAはSHAに変換
            return String(upper.prefix(3)) // 常に3レターに変換
        }
        
        let departure = formatCode(info.departure)
        let arrival = formatCode(info.arrival)
        let departDate = info.departureDate // yyyy-mm-dd
        
        var urlString = "https://www.kiwi.com/deep?from=\(departure)&to=\(arrival)&departure=\(departDate)"
        
        if info.isRoundTrip, let returnDate = info.returnDate {
            urlString += "&return=\(returnDate)"
        }
        
        return urlString
    }
    
    private func generateShareText(
        isRoundTrip: Bool,
        tripShortUrl: String?,
        travelokaShortUrl: String?,
        kiwiShortUrl: String?,
        skyscannerShortUrl: String
    ) -> String {
        var text = ""
        
        // パートナーリンクを追加
        if let kiwiUrl = kiwiShortUrl {
            text += "✈️kiwiで予約\n\(kiwiUrl)\n\n"
        }

        if let tripUrl = tripShortUrl {
            text += "✈️Tripで予約\n\(tripUrl)\n\n"
        }
        
        if let travelokaUrl = travelokaShortUrl {
            text += "✈️トラベロカで予約\n\(travelokaUrl)\n\n"
        }
        
        // Skyscanner
        let tripTypeLabel = isRoundTrip ? "往復" : "片道"
        text += "🔍️スカイスキャナーで検索\n\(tripTypeLabel): \(skyscannerShortUrl)\n\n"
        
        // パートナー選択がない場合のみ楽天モバイルを表示
        if tripShortUrl == nil && travelokaShortUrl == nil && kiwiShortUrl == nil {
            text += "📲楽天モバイル\n"
            text += "🌏海外データ2GB/月\n"
            text += "▽乗換で1.4万、新規で1.1万ptゲット\n"
            text += "https://x.gd/6LqKk\n\n"
        }
        
        text += "💳️セゾンプラチナビジネス\n"
        text += "✅PP無料付帯\n"
        text += "▽特別招待ー初年度無料＆アマギフ1.2万\n"
        text += "https://x.gd/TYSba"
        
        return text
    }
    
    private func formatDateForTrip(_ dateStr: String) -> String {
        if dateStr.count == 10 && dateStr.contains("-") { return dateStr }
        if dateStr.count == 6 { return "20\(dateStr.prefix(2))-\(dateStr.dropFirst(2).prefix(2))-\(dateStr.suffix(2))" }
        return dateStr
    }
    
    private func formatDateForTraveloka(_ dateStr: String) -> String {
        let parts = dateStr.components(separatedBy: "-")
        if parts.count == 3 {
            let y = parts[0]
            let m = Int(parts[1]) ?? 1
            let d = parts[2]
            return "\(d)-\(m)-\(y)"
        }
        return dateStr
    }
    
    private func pasteFromClipboard() {
        if let content = UIPasteboard.general.string {
            skyscannerLink = content
        }
    }
    
    private func copyToClipboard(_ content: String) {
        UIPasteboard.general.string = content
    }
    
    private func parseSkyscannerLinkAsync(_ link: String) async -> SkyscannerFlightInfo? {
        return await SkyscannerURLService.parseSkyscannerLinkAsync(link)
    }
    
    private func shortenURLAsync(_ url: String) async -> String? {
        return await SkyscannerURLService.shortenURLAsync(url)
    }
    
    private func generatePartnerAffiliateLink(url: String, campaignId: Int) async -> String? {
        let result = try? await TravelPayoutsAffiliateService.generateAffiliateLink(from: url)
        return result?.partnerURL
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
            return "トラベロカ"
        case 121:
            return "Trip"
        case 3791:
            return "kiwi"
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
        } else if url.lowercased().contains("kiwi.com") {
            return 3791
        }
        return nil
    }
    
    static func generateAffiliateLink(from url: String, shorten: Bool = true) async throws -> (partnerURL: String, campaignId: Int) {
        guard !url.isEmpty else {
            throw TravelPayoutsError.invalidURL
        }
        
        guard !apiKey.isEmpty else {
            throw TravelPayoutsError.missingAPIKey
        }
        
        guard let campaignId = getCampaignId(from: url) else {
            throw TravelPayoutsError.invalidPartner
        }
        
        // Kiwi.com の場合は提供されたカスタムリンク形式を使用
        if campaignId == 3791 {
            let encodedUrl = url.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? url
            let partnerURL = "https://c111.travelpayouts.com/click?shmarker=\(marker)&promo_id=3791&source_type=customlink&type=click&custom_url=\(encodedUrl)"
            return (partnerURL: partnerURL, campaignId: campaignId)
        }
        
        guard let requestURL = URL(string: baseURL) else {
            throw TravelPayoutsError.invalidURL
        }
        
        let linkRequest = LinkRequest(url: url, sub_id: nil)
        let createRequest = CreateLinksRequest(
            trs: trs,
            marker: marker,
            shorten: shorten,
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

// MARK: - UI Helpers
struct CompactToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack(spacing: 4) {
                Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(configuration.isOn ? .blue : .gray)
                configuration.label
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(configuration.isOn ? .primary : .secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(configuration.isOn ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
