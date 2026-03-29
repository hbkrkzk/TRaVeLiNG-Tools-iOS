//
//  ShareViewController.swift
//  Skyscanner Link Share
//
//  Created by TRaVeLiNG on 2026/03/29.
//

import UIKit

class ShareViewController: UIViewController {
    private let appGroupsIdentifier = "group.com.traveling.tools"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        processSharedContent()
    }
    
    private func processSharedContent() {
        guard let extensionContext = extensionContext else {
            completeWithResult(success: false, message: "エラーが発生しました")
            return
        }
        
        guard let inputItems = extensionContext.inputItems as? [NSExtensionItem] else {
            completeWithResult(success: false, message: "リンクが見つかりません")
            return
        }
        
        for item in inputItems {
            if let attachments = item.attachments {
                for attachment in attachments {
                    if attachment.hasItemConformingToTypeIdentifier("public.url") {
                        attachment.loadItem(forTypeIdentifier: "public.url") { [weak self] (item, _) in
                            if let url = item as? NSURL {
                                DispatchQueue.main.async {
                                    self?.handleSkyscannerLink(url as URL)
                                }
                            }
                        }
                        return
                    }
                }
            }
        }
        
        completeWithResult(success: false, message: "Skyscannerリンクが見つかりません")
    }
    
    private func handleSkyscannerLink(_ url: URL) {
        let urlString = url.absoluteString
        print("🔗 受信URL: \(urlString)")
        
        // Skyscannerリンクのチェック
        guard urlString.contains("skyscanner") else {
            print("❌ Skyscannerリンクではありません")
            completeWithResult(success: false, message: "Skyscannerの公式リンクをご使用ください")
            return
        }
        
        print("✅ Skyscannerリンク検出")
        
        // ディープリンク（app.link）の場合、リダイレクト先を取得
        if urlString.contains("app.link") {
            print("🔗 ディープリンク検出、リダイレクト先を追跡中...")
            resolveDeepLink(url, attempts: 0)
        } else {
            parseAndProcessSkyscannerUrl(urlString)
        }
    }
    
    private func resolveDeepLink(_ url: URL, attempts: Int) {
        guard attempts < 5 else {
            print("❌ リダイレクト追跡回数上限に達しました")
            completeWithResult(success: false, message: "Skyscannerリンクの解析に失敗しました")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10
        
        // リダイレクト自動追跡を有効にしたセッション設定
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = false
        let session = URLSession(configuration: config)
        
        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ リダイレクト追跡エラー: \(error)")
                    self?.completeWithResult(success: false, message: "Skyscannerリンクの解析に失敗しました")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("🔍 HTTPレスポンス: \(httpResponse.statusCode)")
                    
                    // 最終URL も確認
                    if let finalUrl = httpResponse.url {
                        let finalUrlString = finalUrl.absoluteString
                        print("🔗 最終URL: \(finalUrlString)")
                        
                        // skyscanner.jp/skyscanner.net/skyscanner.com を含む場合は解析
                        if finalUrlString.contains("skyscanner.jp") || 
                           finalUrlString.contains("skyscanner.net") || 
                           finalUrlString.contains("skyscanner.com") {
                            self?.parseAndProcessSkyscannerUrl(finalUrlString)
                        } else {
                            // さらにリダイレクト可能性がある
                            if (300..<400).contains(httpResponse.statusCode) {
                                self?.resolveDeepLink(finalUrl, attempts: attempts + 1)
                            } else {
                                print("❌ 認識できないリダイレクト先")
                                self?.completeWithResult(success: false, message: "Skyscannerリンクの形式が認識できません")
                            }
                        }
                    }
                }
            }
        }.resume()
    }
    
    private func parseAndProcessSkyscannerUrl(_ urlString: String) {
        print("🔍 URL解析処理開始: \(urlString)")
        
        // URLの解析
        let urlService = SkyscannerURLService()
        guard let info = urlService.parseSkyscannerUrl(urlString) else {
            print("❌ URL解析失敗")
            // デバッグ用: URLの詳細情報を出力
            if let components = URLComponents(string: urlString) {
                print("🔍 URLComponents.scheme: \(components.scheme ?? "nil")")
                print("🔍 URLComponents.host: \(components.host ?? "nil")")
                print("🔍 URLComponents.path: \(components.path)")
                print("🔍 URLComponents.query: \(components.query ?? "nil")")
                print("🔍 URLComponents.queryItems: \(components.queryItems?.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&") ?? "nil")")
            }
            completeWithResult(success: false, message: "URLの解析に失敗しました")
            return
        }
        
        print("✅ URL解析成功: \(info.departure) → \(info.arrival), \(info.departureDate)")
        
        // アフィリエイトURL生成
        let affiliateUrl = info.isRoundTrip
            ? urlService.generateRoundtripUrl(departure: info.departure, arrival: info.arrival, departureDate: info.departureDate, returnDate: info.returnDate ?? "")
            : urlService.generateOneWayUrl(departure: info.departure, arrival: info.arrival, departureDate: info.departureDate)
        
        // 短縮化処理
        shortenURL(affiliateUrl, flightInfo: info)
    }
    
    private func shortenURL(_ url: String, flightInfo: SkyscannerFlightInfo) {
        print("🔗 短縮URL API呼び出し開始")
        print("📝 元のURL: \(url)")
        
        // xgd.io を使用
        shortenWithXgdIo(url, flightInfo: flightInfo)
    }
    
    private func shortenWithXgdIo(_ url: String, flightInfo: SkyscannerFlightInfo) {
        // 元アプリと同じ方式でURL短縮
        // App Groups から API key を取得、失敗時はデフォルト値を使用
        var apiKey = "7d2ad123799e3bdd05a3553b5d2f7968"
        if let defaults = UserDefaults(suiteName: "group.com.traveling.tools"),
           let savedKey = defaults.string(forKey: "xgd_io_api_key") {
            apiKey = savedKey
            print("✅ App Groups から API key を取得")
        } else {
            print("⚠️ App Groups に API key なし。デフォルト値を使用")
        }
        
        // メインアプリと同じエンコーディング処理
        let encodedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url
        let urlString = "https://xgd.io/V1/shorten?url=\(encodedUrl)&key=\(apiKey)"
        
        guard let requestUrl = URL(string: urlString) else {
            print("❌ xgd.io URL 生成失敗")
            completeWithResult(success: true, message: "URL生成完了（短縮失敗）", shortenedUrl: url, flightInfo: flightInfo)
            return
        }
        
        print("📡 xgd.io V1/shorten リクエストURL: \(requestUrl.absoluteString)")
        
        // メインアプリと同じように URLSession を使用してリクエスト送信
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.httpShouldSetCookies = false
        
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: requestUrl) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ URL shortening error: \(error.localizedDescription)")
                    self?.completeWithResult(success: true, message: "URL生成完了", shortenedUrl: url, flightInfo: flightInfo)
                    return
                }
                
                guard let data = data else {
                    print("❌ No data received from xgd.io")
                    self?.completeWithResult(success: true, message: "URL生成完了", shortenedUrl: url, flightInfo: flightInfo)
                    return
                }
                
                let responseString = String(data: data, encoding: .utf8) ?? ""
                print("📊 xgd.io response: \(responseString)")
                
                // xgd.io は小文字の shorturl キーで返す
                if let jsonData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let shortUrl = jsonData["shorturl"] as? String ?? jsonData["shortUrl"] as? String {
                    print("✅ Shortened URL: \(shortUrl)")
                    self?.completeWithResult(success: true, message: "変換完了！", shortenedUrl: shortUrl, flightInfo: flightInfo)
                    return
                }
                
                // Fallback: try to extract URL from plain text response
                if responseString.contains("http") {
                    let components = responseString.components(separatedBy: "\"")
                    for component in components {
                        if component.hasPrefix("http") {
                            print("✅ Extracted shortened URL: \(component)")
                            self?.completeWithResult(success: true, message: "変換完了！", shortenedUrl: component, flightInfo: flightInfo)
                            return
                        }
                    }
                }
                
                print("❌ Could not parse shortened URL from response")
                self?.completeWithResult(success: true, message: "URL生成完了", shortenedUrl: url, flightInfo: flightInfo)
            }
        }
        
        task.resume()
    }
    

    
    private func extractShortenedUrlFromResponse(_ response: String, fallbackUrl: String, flightInfo: SkyscannerFlightInfo) {
        // xgd.io / x.gd のレスポンスから短縮 URL を抽出
        // パターン: https://x.gd/xxx または https://xgd.io/xxx
        
        // x.gd パターンを優先検索
        if let range = response.range(of: "https://x.gd/") {
            let substring = response[range.lowerBound...]
            if let endIndex = substring.firstIndex(where: { $0 == "\"" || $0 == " " || $0 == "\n" || $0 == "," }) {
                let urlPart = String(substring[..<endIndex])
                print("✅ レスポンスから x.gd 短縮URL抽出: \(urlPart)")
                completeWithResult(success: true, message: "変換完了！", shortenedUrl: urlPart, flightInfo: flightInfo)
                return
            }
        }
        
        // xgd.io パターン
        if let range = response.range(of: "https://xgd.io/") {
            let substring = response[range.lowerBound...]
            if let endIndex = substring.firstIndex(where: { $0 == "\"" || $0 == " " || $0 == "\n" || $0 == "," }) {
                let urlPart = String(substring[..<endIndex])
                print("✅ レスポンスから xgd.io 短縮URL抽出: \(urlPart)")
                completeWithResult(success: true, message: "変換完了！", shortenedUrl: urlPart, flightInfo: flightInfo)
                return
            }
        }
        
        print("⚠️ レスポンスから URL を抽出できません")
        completeWithResult(success: true, message: "URL生成完了", shortenedUrl: fallbackUrl, flightInfo: flightInfo)
    }
    
    private func extractShortenedUrlFromHtml(_ html: String, fallbackUrl: String, flightInfo: SkyscannerFlightInfo) {
        // xgd.io / x.gd がHTMLを返した場合、短縮URLをテキストから抽出試行
        // パターン: https://x.gd/[code] または https://xgd.io/[code]
        
        // x.gd パターン優先
        if let range = html.range(of: "x.gd/") {
            let substring = html[range.lowerBound...]
            if let endIndex = substring.firstIndex(where: { $0 == "\"" || $0 == " " || $0 == "\n" || $0 == "}" }) {
                let code = String(substring[..<endIndex])
                let shortenedUrl = "https://\(code)"
                print("✅ HTMLから x.gd 短縮URL抽出: \(shortenedUrl)")
                completeWithResult(success: true, message: "変換完了！", shortenedUrl: shortenedUrl, flightInfo: flightInfo)
                return
            }
        }
        
        // xgd.io パターン
        if let range = html.range(of: "xgd.io/") {
            let substring = html[range.lowerBound...]
            if let codeRange = substring.range(of: #"(?<=xgd\.io/)[a-zA-Z0-9]+"#, options: .regularExpression) {
                let code = substring[codeRange]
                let shortenedUrl = "https://xgd.io/\(code)"
                print("✅ HTMLから xgd.io 短縮URL抽出: \(shortenedUrl)")
                completeWithResult(success: true, message: "変換完了！", shortenedUrl: shortenedUrl, flightInfo: flightInfo)
                return
            }
        }
        
        print("⚠️ 短縮URLを抽出できず")
        completeWithResult(success: true, message: "URL生成完了", shortenedUrl: fallbackUrl, flightInfo: flightInfo)
    }
    
    private func completeWithResult(success: Bool, message: String, shortenedUrl: String? = nil, flightInfo: SkyscannerFlightInfo? = nil) {
        // 事前に shareMessage を生成
        var shareMessage: String? = nil
        if success, let shortenedUrl = shortenedUrl, let flightInfo = flightInfo {
            shareMessage = generateShareMessage(shortenedUrl: shortenedUrl, flightInfo: flightInfo)
            // クリップボードにコピー
            UIPasteboard.general.string = shareMessage
        }
        
        let resultViewController = ResultViewController(
            success: success,
            message: message,
            shortenedUrl: shortenedUrl,
            shareMessage: shareMessage,
            flightInfo: flightInfo,
            completion: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        )
        
        addChild(resultViewController)
        view.addSubview(resultViewController.view)
        resultViewController.view.frame = view.bounds
        resultViewController.didMove(toParent: self)
    }
    
    private func generateShareMessage(shortenedUrl: String, flightInfo: SkyscannerFlightInfo) -> String {
        let template = flightInfo.isRoundTrip
            ? getDefaultRoundTripTemplate()
            : getDefaultOnewayTemplate()
        return template.replacingOccurrences(of: "{URL}", with: shortenedUrl)
    }
    
    private func getDefaultRoundTripTemplate() -> String {
        """
✈️スカイスキャナーで検索
往復: {URL}

📲楽天モバイル
🌏海外データ2GB/月
▽乗換で1.4万ptゲット
https://x.gd/6LqKk

💳️セゾンプラチナビジネス
✅PP無料付帯
▽特別招待ー初年度無料＆アマギフ1.2万
https://x.gd/TYSba
"""
    }
    
    private func getDefaultOnewayTemplate() -> String {
        """
✈️スカイスキャナーで検索
片道: {URL}

📲楽天モバイル
🌏海外データ2GB/月
▽乗換で1.4万ptゲット
https://x.gd/6LqKk

💳️セゾンプラチナビジネス
✅PP無料付帯
▽特別招待ー初年度無料＆アマギフ1.2万
https://x.gd/TYSba
"""
    }
    

}

// MARK: - Flight Info Model

struct SkyscannerFlightInfo {
    let departure: String
    let arrival: String
    let departureDate: String
    let returnDate: String?
    let isRoundTrip: Bool
}

// MARK: - Skyscanner URL Service (簡易版)

class SkyscannerURLService {
    func parseSkyscannerUrl(_ url: String) -> SkyscannerFlightInfo? {
        guard let components = URLComponents(string: url) else {
            print("❌ URLComponents 生成失敗: \(url)")
            return nil
        }
        
        // ホスト名確認
        let host = components.host?.lowercased() ?? ""
        guard host.contains("skyscanner") else {
            print("❌ Skyscannerホスト ではありません: \(host)")
            return nil
        }
        
        // path から flight 情報を抽出
        let pathComponents = components.path
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty }
        
        print("🔍 ホスト: \(host)")
        print("🔍 Path components: \(pathComponents)")
        print("🔍 Query items: \(components.queryItems?.map { $0.name + "=" + ($0.value ?? "") } ?? [])")
        
        // パターン1: /transport/flights/{dep}/{arr}/{date}(/{returnDate})?
        // 例: /transport/flights/NRT/YVR/20260421/20260428/config/...
        // または /transport/flights/NRT/YVR/20260421/config/... (片道)
        if pathComponents.count >= 5 && pathComponents[0] == "transport" && pathComponents[1] == "flights" {
            let departure = pathComponents[2]
            let arrival = pathComponents[3]
            let departureDate = pathComponents[4]
            
            // 日付フォーマットチェック
            guard isValidDateFormat(departureDate) else {
                print("❌ 出発日のフォーマットが無効: \(departureDate)")
                return nil
            }
            
            // returnDateの判定：次の要素が日付形式なら往復、そうでなければ片道
            var isRoundTrip = false
            var returnDate: String? = nil
            
            if pathComponents.count > 5 {
                let potentialReturnDate = pathComponents[5]
                if isValidDateFormat(potentialReturnDate) {
                    // 正しい日付形式 → 往復
                    isRoundTrip = true
                    returnDate = potentialReturnDate
                    print("✅ パターン1 解析成功 (往復) - \(departure)→\(arrival), \(departureDate)→\(returnDate ?? "")")
                } else {
                    // 日付形式ではない（"config"など）→ 片道
                    print("✅ パターン1 解析成功 (片道) - \(departure)→\(arrival), \(departureDate)")
                }
            }
            
            return SkyscannerFlightInfo(
                departure: departure,
                arrival: arrival,
                departureDate: departureDate,
                returnDate: returnDate,
                isRoundTrip: isRoundTrip
            )
        }
        
        // パターン2: query パラメータから抽出
        if let queryItems = components.queryItems {
            var queryDict: [String: String] = [:]
            for item in queryItems {
                queryDict[item.name] = item.value
            }
            
            if let departure = queryDict["from"] ?? queryDict["departure"],
               let arrival = queryDict["to"] ?? queryDict["arrival"],
               let departureDate = queryDict["outbound"] ?? queryDict["departureDate"] ?? queryDict["departure_date"] {
                
                if isValidDateFormat(departureDate) {
                    let returnDate = queryDict["inbound"] ?? queryDict["returnDate"] ?? queryDict["return_date"]
                    let isRoundTrip = returnDate != nil
                    
                    print("✅ パターン2 解析成功 (Query パラメータ) - \(departure)→\(arrival), \(departureDate)")
                    return SkyscannerFlightInfo(
                        departure: departure,
                        arrival: arrival,
                        departureDate: departureDate,
                        returnDate: returnDate,
                        isRoundTrip: isRoundTrip
                    )
                }
            }
        }
        
        print("❌ 既知のパターンと一致しません")
        return nil
    }
    
    private func isValidDateFormat(_ dateString: String) -> Bool {
        // YYYYMMDD フォーマット (8文字)
        if dateString.count == 8 && dateString.allSatisfy({ $0.isNumber }) {
            return true
        }
        
        // YYYY-MM-DD フォーマット (10文字)
        let pattern = "^\\d{4}-\\d{2}-\\d{2}$"
        if dateString.range(of: pattern, options: .regularExpression) != nil {
            return true
        }
        
        return false
    }
    
    // アフィリエイトパラメータ（メインアプリと統一）
    static let associateId = "AFF_TRA_19354_00001"
    static let campaignId = "6120265"
    static let utmSource = "6120265-現住所TRaVeLiNG"
    
    func generateRoundtripUrl(departure: String, arrival: String, departureDate: String, returnDate: String) -> String {
        let timestamp = String(Int(Date().timeIntervalSince1970 * 1000))
        
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.skyscanner.jp"
        components.path = "/transport/flights/\(departure.uppercased())/\(arrival.uppercased())/\(departureDate)/\(returnDate)/"
        
        components.queryItems = [
            URLQueryItem(name: "adultsv2", value: "1"),
            URLQueryItem(name: "cabinclass", value: "economy"),
            URLQueryItem(name: "childrenv2", value: ""),
            URLQueryItem(name: "ref", value: "home"),
            URLQueryItem(name: "rtn", value: "1"),
            URLQueryItem(name: "preferdirects", value: "false"),
            URLQueryItem(name: "outboundaltsenabled", value: "false"),
            URLQueryItem(name: "inboundaltsenabled", value: "false"),
            URLQueryItem(name: "associateid", value: SkyscannerURLService.associateId),
            URLQueryItem(name: "utm_medium", value: "affiliate"),
            URLQueryItem(name: "utm_source", value: SkyscannerURLService.utmSource),
            URLQueryItem(name: "utm_campaign", value: ""),
            URLQueryItem(name: "campaign_id", value: SkyscannerURLService.campaignId),
            URLQueryItem(name: "utm_content", value: "Online Tracking Link"),
            URLQueryItem(name: "adid", value: "1027991"),
            URLQueryItem(name: "click_timestamp", value: timestamp),
            URLQueryItem(name: "irmweb", value: ""),
            URLQueryItem(name: "irgwc", value: "1"),
            URLQueryItem(name: "afsrc", value: "1")
        ]
        
        return components.url?.absoluteString ?? ""
    }
    
    func generateOneWayUrl(departure: String, arrival: String, departureDate: String) -> String {
        let timestamp = String(Int(Date().timeIntervalSince1970 * 1000))
        
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.skyscanner.jp"
        components.path = "/transport/flights/\(departure.uppercased())/\(arrival.uppercased())/\(departureDate)/"
        
        components.queryItems = [
            URLQueryItem(name: "adultsv2", value: "1"),
            URLQueryItem(name: "cabinclass", value: "economy"),
            URLQueryItem(name: "childrenv2", value: ""),
            URLQueryItem(name: "ref", value: "home"),
            URLQueryItem(name: "rtn", value: "0"),
            URLQueryItem(name: "preferdirects", value: "false"),
            URLQueryItem(name: "outboundaltsenabled", value: "false"),
            URLQueryItem(name: "inboundaltsenabled", value: "false"),
            URLQueryItem(name: "associateid", value: SkyscannerURLService.associateId),
            URLQueryItem(name: "utm_medium", value: "affiliate"),
            URLQueryItem(name: "utm_source", value: SkyscannerURLService.utmSource),
            URLQueryItem(name: "utm_campaign", value: ""),
            URLQueryItem(name: "campaign_id", value: SkyscannerURLService.campaignId),
            URLQueryItem(name: "utm_content", value: "Online Tracking Link"),
            URLQueryItem(name: "adid", value: "1027991"),
            URLQueryItem(name: "click_timestamp", value: timestamp),
            URLQueryItem(name: "irmweb", value: ""),
            URLQueryItem(name: "irgwc", value: "1"),
            URLQueryItem(name: "afsrc", value: "1")
        ]
        
        return components.url?.absoluteString ?? ""
    }
}

// MARK: - Result View Controller

class ResultViewController: UIViewController {
    private let success: Bool
    private let message: String
    private let shortenedUrl: String?
    private let shareMessage: String?
    private let flightInfo: SkyscannerFlightInfo?
    private let completion: () -> Void
    
    init(success: Bool, message: String, shortenedUrl: String?, shareMessage: String?, flightInfo: SkyscannerFlightInfo?, completion: @escaping () -> Void) {
        self.success = success
        self.message = message
        self.shortenedUrl = shortenedUrl
        self.shareMessage = shareMessage
        self.flightInfo = flightInfo
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1.0)
        
        // ScrollView（全体container）
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // メインコンテナ
        let containerView = UIView()
        containerView.backgroundColor = .white
        containerView.layer.cornerRadius = 12
        containerView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(containerView)
        
        // ScrollView のコンテンツ制約
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            containerView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(lessThanOrEqualTo: scrollView.bottomAnchor, constant: -20),
            containerView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
        
        //内部 Stack View
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16)
        ])
        
        // アイコン（縦に伸びないよう固定）
        let iconImageView = UIImageView()
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 50, weight: .semibold, scale: .large)
        iconImageView.image = UIImage(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill", withConfiguration: symbolConfig)
        iconImageView.tintColor = success ? .systemGreen : .systemRed
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.heightAnchor.constraint(equalToConstant: 60).isActive = true
        iconImageView.widthAnchor.constraint(equalToConstant: 60).isActive = true
        iconImageView.contentMode = .scaleAspectFit
        
        // メッセージ
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 2
        
        // 情報表示（成功時のみ）
        var infoLabel: UILabel?
        if success, let flightInfo = flightInfo {
            let label = UILabel()
            label.text = "\(flightInfo.departure) → \(flightInfo.arrival)\n\(flightInfo.departureDate)"
            label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
            label.textColor = .gray
            label.textAlignment = .center
            label.numberOfLines = 2
            infoLabel = label
        }
        
        stackView.addArrangedSubview(iconImageView)
        stackView.addArrangedSubview(messageLabel)
        if let infoLabel = infoLabel {
            stackView.addArrangedSubview(infoLabel)
        }
        
        // コピーされた内容表示（成功時のみ）
        if success, let shareMessage = shareMessage {
            let contentContainer = UIView()
            contentContainer.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 1.0, alpha: 1.0)
            contentContainer.layer.cornerRadius = 8
            contentContainer.translatesAutoresizingMaskIntoConstraints = false
            
            let contentLabel = UILabel()
            contentLabel.text = shareMessage
            contentLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
            contentLabel.textColor = .darkGray
            contentLabel.numberOfLines = 0
            contentLabel.lineBreakMode = .byCharWrapping
            contentLabel.translatesAutoresizingMaskIntoConstraints = false
            
            contentContainer.addSubview(contentLabel)
            
            NSLayoutConstraint.activate([
                contentLabel.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 8),
                contentLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 8),
                contentLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -8),
                contentLabel.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -8)
            ])
            
            contentContainer.heightAnchor.constraint(lessThanOrEqualToConstant: 100).isActive = true
            
            stackView.addArrangedSubview(contentContainer)
        }
        
        // ボタンエリア（stackView の下）
        let buttonStackView = UIStackView()
        buttonStackView.axis = .horizontal
        buttonStackView.spacing = 12
        buttonStackView.distribution = .fillEqually
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(buttonStackView)
        
        NSLayoutConstraint.activate([
            buttonStackView.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 20),
            buttonStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            buttonStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            buttonStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])
        
        // 閉じるボタン
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("閉じる", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        closeButton.tintColor = .systemGray
        closeButton.layer.borderColor = UIColor.systemGray.cgColor
        closeButton.layer.borderWidth = 1
        closeButton.layer.cornerRadius = 8
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        
        // 履歴ボタン
        let historyButton = UIButton(type: .system)
        historyButton.setTitle("履歴を見る", for: .normal)
        historyButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        historyButton.tintColor = .white
        historyButton.backgroundColor = .systemBlue
        historyButton.layer.cornerRadius = 8
        historyButton.translatesAutoresizingMaskIntoConstraints = false
        historyButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        historyButton.addTarget(self, action: #selector(historyButtonTapped), for: .touchUpInside)
        
        buttonStackView.addArrangedSubview(closeButton)
        buttonStackView.addArrangedSubview(historyButton)
        
        containerView.addSubview(buttonStackView)
        
        NSLayoutConstraint.activate([
            buttonStackView.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 20),
            buttonStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            buttonStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            buttonStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])
        
        // コンテナのレイアウト制約
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16)
        ])
    }
    
    @objc private func closeButtonTapped() {
        completion()
    }
    
    @objc private func historyButtonTapped() {
        // App Groups にフラグを記録して、メインアプリ起動時に履歴ページを開く
        if let defaults = UserDefaults(suiteName: "group.com.traveling.tools") {
            defaults.set(true, forKey: "open_skyscanner_history")
            print("✅ 履歴ページ表示フラグを記録")
        }
        // 拡張機能を閉じる
        completion()
    }
}
