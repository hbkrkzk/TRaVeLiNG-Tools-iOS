import Foundation

class SkyscannerURLService {
    // アフィリエイトパラメータ
    static let associateId = "AFF_TRA_19354_00001"
    static let campaignId = "6120265"
    static let utmSource = "6120265-現住所TRaVeLiNG"
    static let affiliateCode = "6120265"
    
    // 正規表現パターンをキャッシュ（毎回のコンパイルを避ける）
    static let skyscannerUrlRegex = try! NSRegularExpression(
        pattern: "https://www\\.skyscanner\\.[a-z]+/transport/flights/[^\\s\"'<>]*",
        options: .caseInsensitive
    )
    
    static let hrefUrlRegex = try! NSRegularExpression(
        pattern: "href=\"([^\"]*skyscanner[^\"]*?)\"",
        options: .caseInsensitive
    )
    
    static let metaRefreshRegex1 = try! NSRegularExpression(
        pattern: "content=\"[0-9.]*;\\s*url=([^\"]+)\"",
        options: .caseInsensitive
    )
    
    static let metaRefreshRegex2 = try! NSRegularExpression(
        pattern: "content='[0-9.]*;\\s*url=([^']+)'",
        options: .caseInsensitive
    )
    
    static let openGraphRegex1 = try! NSRegularExpression(
        pattern: "property=\"og:url\"\\s+content=\"([^\"]+)\"",
        options: .caseInsensitive
    )
    
    static let openGraphRegex2 = try! NSRegularExpression(
        pattern: "property=\"og:url\"\\s+content='([^']+)'",
        options: .caseInsensitive
    )
    
    static let windowLocationRegex = try! NSRegularExpression(
        pattern: "window\\.location\\.href\\s*=\\s*[\"']([^\"']+)[\"']",
        options: .caseInsensitive
    )
    
    // MARK: - URL生成
    
    /// 往復フライト用のアフィリエイトURLを生成
    static func generateRoundtripUrl(
        departure: String,
        arrival: String,
        departDate: String,
        returnDate: String
    ) -> String {
        let timestamp = String(Int(Date().timeIntervalSince1970 * 1000))
        
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.skyscanner.jp"
        components.path = "/transport/flights/\(departure)/\(arrival)/\(departDate)/\(returnDate)/"
        
        components.queryItems = [
            URLQueryItem(name: "adultsv2", value: "1"),
            URLQueryItem(name: "cabinclass", value: "economy"),
            URLQueryItem(name: "childrenv2", value: ""),
            URLQueryItem(name: "ref", value: "home"),
            URLQueryItem(name: "rtn", value: "1"),
            URLQueryItem(name: "preferdirects", value: "false"),
            URLQueryItem(name: "outboundaltsenabled", value: "false"),
            URLQueryItem(name: "inboundaltsenabled", value: "false"),
            URLQueryItem(name: "associateid", value: associateId),
            URLQueryItem(name: "utm_medium", value: "affiliate"),
            URLQueryItem(name: "utm_source", value: utmSource),
            URLQueryItem(name: "utm_campaign", value: ""),
            URLQueryItem(name: "campaign_id", value: campaignId),
            URLQueryItem(name: "utm_content", value: "Online Tracking Link"),
            URLQueryItem(name: "adid", value: "1027991"),
            URLQueryItem(name: "click_timestamp", value: timestamp),
            URLQueryItem(name: "irmweb", value: ""),
            URLQueryItem(name: "irgwc", value: "1"),
            URLQueryItem(name: "afsrc", value: "1")
        ]
        
        return components.url?.absoluteString ?? ""
    }
    
    /// 片道フライト用のアフィリエイトURLを生成
    static func generateOneWayUrl(
        departure: String,
        arrival: String,
        departDate: String
    ) -> String {
        let timestamp = String(Int(Date().timeIntervalSince1970 * 1000))
        
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.skyscanner.jp"
        components.path = "/transport/flights/\(departure)/\(arrival)/\(departDate)/"
        
        components.queryItems = [
            URLQueryItem(name: "adultsv2", value: "1"),
            URLQueryItem(name: "cabinclass", value: "economy"),
            URLQueryItem(name: "childrenv2", value: ""),
            URLQueryItem(name: "ref", value: "home"),
            URLQueryItem(name: "rtn", value: "0"),
            URLQueryItem(name: "preferdirects", value: "false"),
            URLQueryItem(name: "outboundaltsenabled", value: "false"),
            URLQueryItem(name: "inboundaltsenabled", value: "false"),
            URLQueryItem(name: "associateid", value: associateId),
            URLQueryItem(name: "utm_medium", value: "affiliate"),
            URLQueryItem(name: "utm_source", value: utmSource),
            URLQueryItem(name: "utm_campaign", value: ""),
            URLQueryItem(name: "campaign_id", value: campaignId),
            URLQueryItem(name: "utm_content", value: "Online Tracking Link"),
            URLQueryItem(name: "adid", value: "1027991"),
            URLQueryItem(name: "click_timestamp", value: timestamp),
            URLQueryItem(name: "irmweb", value: ""),
            URLQueryItem(name: "irgwc", value: "1"),
            URLQueryItem(name: "afsrc", value: "1")
        ]
        
        return components.url?.absoluteString ?? ""
    }
    
    // MARK: - URL解析
    
    /// Skyscannerの共有リンク（リダイレクトを含む）を解析
    static func parseSkyscannerLink(_ urlString: String, completion: @escaping (SkyscannerFlightInfo?) -> Void) {
        // リダイレクトURLかどうか判定
        if urlString.contains("skyscanner.app.link") {
            // リダイレクトURLを解析
            resolveRedirectURL(urlString) { resolvedUrl in
                if let resolvedUrl = resolvedUrl {
                    completion(parseSkyscannerPath(resolvedUrl))
                } else {
                    completion(nil)
                }
            }
        } else {
            // 通常のSkyscannerページURLを解析
            completion(parseSkyscannerPath(urlString))
        }
    }
    
    /// リダイレクトURL (skyscanner.app.link) を解析して元のURLを取得
    private static func resolveRedirectURL(_ shortUrl: String, completion: @escaping (String?) -> Void) {
        print("🔗 Resolving redirect: \(shortUrl)")
        guard let url = URL(string: shortUrl) else {
            print("❌ Invalid URL")
            completion(nil)
            return
        }
        
        // URLSessionのデフォルト設定ではリダイレクトを自動追跡しない場合があるため、明示的に設定
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        
        let session = URLSession.shared
        
        let task = session.dataTask(with: request) { data, response, error in
            print("📊 HEAD Response Info:")
            if let error = error {
                print("  ❌ Error: \(error.localizedDescription)")
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("  Status Code: \(httpResponse.statusCode)")
                print("  URL: \(httpResponse.url?.absoluteString ?? "nil")")
                print("  Headers: \(httpResponse.allHeaderFields)")
                
                // Locationヘッダーを確認
                if let location = httpResponse.value(forHTTPHeaderField: "Location") {
                    print("  ✅ Location: \(location)")
                    // 相対URLの場合は絶対URLに変換
                    if let absoluteUrl = URL(string: location, relativeTo: url)?.absoluteString {
                        print("  Absolute URL: \(absoluteUrl)")
                        self.resolveRedirectURLRecursive(absoluteUrl, maxDepth: 5, completion: completion)
                        return
                    }
                }
            }
            
            // リダイレクトがない場合、または自動追跡されている場合
            if let finalUrl = (response as? HTTPURLResponse)?.url?.absoluteString {
                print("  Final URL: \(finalUrl)")
                
                // まだスキーマリンクの場合はGETで再試行
                if finalUrl.contains("skyscanner.app.link") {
                    print("  ⚠️ Still pointing to short URL, trying GET...")
                    self.resolveWithGET(url, completion: completion)
                } else {
                    completion(finalUrl)
                }
            } else {
                print("  ❌ No response URL found")
                self.resolveWithGET(url, completion: completion)
            }
        }
        
        task.resume()
    }
    
    private static func resolveWithGET(_ url: URL, completion: @escaping (String?) -> Void) {
        print("🔄 Trying GET request...")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        
        let session = URLSession.shared
        let task = session.dataTask(with: request) { data, response, error in
            print("📊 GET Response Info:")
            if let error = error {
                print("  ❌ Error: \(error.localizedDescription)")
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("  Status Code: \(httpResponse.statusCode)")
                print("  URL: \(httpResponse.url?.absoluteString ?? "nil")")
                
                // Locationヘッダーを確認
                if let location = httpResponse.value(forHTTPHeaderField: "Location") {
                    print("  ✅ Location: \(location)")
                    if let absoluteUrl = URL(string: location, relativeTo: url)?.absoluteString {
                        resolveRedirectURLRecursive(absoluteUrl, maxDepth: 5, completion: completion)
                        return
                    }
                }
                
                // HTMLレスポンスボディからリダイレクト情報を抽出
                if let data = data, let html = String(data: data, encoding: .utf8) {
                    print("  📄 Response body: \(data.count) bytes")
                    
                    // メタリフレッシュを探す
                    if let metaRefresh = extractMetaRefresh(html) {
                        print("  ✅ Meta refresh: \(metaRefresh)")
                        resolveRedirectURLRecursive(metaRefresh, maxDepth: 5, completion: completion)
                        return
                    }
                    
                    // Open Graph URLを探す
                    if let ogUrl = extractOpenGraphUrl(html) {
                        print("  ✅ OG URL: \(ogUrl)")
                        resolveRedirectURLRecursive(ogUrl, maxDepth: 5, completion: completion)
                        return
                    }
                    
                    // JavaScriptのwindow.locationを探す
                    if let jsUrl = extractJavaScriptUrl(html) {
                        print("  ✅ JS redirect: \(jsUrl)")
                        resolveRedirectURLRecursive(jsUrl, maxDepth: 5, completion: completion)
                        return
                    }
                    
                    // HTMLから直接SkyscannerのURLを探す
                    // Skyscanner URLをHTMLから直接抽出
                    if let skyscannerUrl = extractUrlFromHtml(html) {
                        print("  ✅ Skyscanner URL in HTML: \(skyscannerUrl)")
                        // HTMLから直接抽出したURLはCAPTCHAをバイパスできるため、直接返す
                        completion(skyscannerUrl)
                        return
                    }
                    
                    // hrefでSkyscannerへのリンクを探す
                    if let href = extractHrefUrl(html) {
                        print("  ✅ Href link: \(href)")
                        resolveRedirectURLRecursive(href, maxDepth: 5, completion: completion)
                        return
                    }
                }
            }
            
            if let finalUrl = (response as? HTTPURLResponse)?.url?.absoluteString {
                print("  Final URL: \(finalUrl)")
                completion(finalUrl)
            } else {
                print("  ❌ GET also failed")
                completion(nil)
            }
        }
        
        task.resume()
    }
    
    private static func extractMetaRefresh(_ html: String) -> String? {
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        
        if let match = metaRefreshRegex1.firstMatch(in: html, range: range) {
            if let range = Range(match.range(at: 1), in: html) {
                return String(html[range])
            }
        }
        
        if let match = metaRefreshRegex2.firstMatch(in: html, range: range) {
            if let range = Range(match.range(at: 1), in: html) {
                return String(html[range])
            }
        }
        
        return nil
    }
    
    private static func extractOpenGraphUrl(_ html: String) -> String? {
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        
        if let match = openGraphRegex1.firstMatch(in: html, range: range) {
            if let range = Range(match.range(at: 1), in: html) {
                return String(html[range])
            }
        }
        
        if let match = openGraphRegex2.firstMatch(in: html, range: range) {
            if let range = Range(match.range(at: 1), in: html) {
                return String(html[range])
            }
        }
        
        return nil
    }
    
    private static func extractJavaScriptUrl(_ html: String) -> String? {
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        
        if let match = windowLocationRegex.firstMatch(in: html, range: range) {
            if let range = Range(match.range(at: 1), in: html) {
                return String(html[range])
            }
        }
        
        return nil
    }
    
    private static func extractUrlFromHtml(_ html: String) -> String? {
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        
        if let match = skyscannerUrlRegex.firstMatch(in: html, range: range) {
            if let range = Range(match.range, in: html) {
                return String(html[range])
            }
        }
        return nil
    }
    
    private static func extractHrefUrl(_ html: String) -> String? {
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        if let match = hrefUrlRegex.firstMatch(in: html, range: range) {
            if let range = Range(match.range(at: 1), in: html) {
                var url = String(html[range])
                // HTMLエンティティをデコード
                url = url.replacingOccurrences(of: "&amp;", with: "&")
                url = url.replacingOccurrences(of: "&quot;", with: "\"")
                url = url.replacingOccurrences(of: "&#x27;", with: "'")
                return url
            }
        }
        return nil
    }
    
    private static func resolveRedirectURLRecursive(_ urlString: String, maxDepth: Int, completion: @escaping (String?) -> Void) {
        guard maxDepth > 0 else {
            print("❌ Max redirect depth reached")
            completion(nil)
            return
        }
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid recursive URL: \(urlString)")
            completion(nil)
            return
        }
        
        print("🔄 Following redirect (\(maxDepth) levels left): \(urlString.prefix(80))...")
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        
        let session = URLSession.shared
        let task = session.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                print("  Status: \(httpResponse.statusCode)")
                
                // Skyscannerに到達
                if let responseUrl = httpResponse.url?.absoluteString, responseUrl.contains("skyscanner.jp") {
                    print("  ✅ Reached skyscanner.jp")
                    completion(responseUrl)
                    return
                }
                
                // さらにリダイレクト
                if let location = httpResponse.value(forHTTPHeaderField: "Location") {
                    print("  → Redirect to: \(location.prefix(80))...")
                    if let absoluteUrl = URL(string: location, relativeTo: url)?.absoluteString {
                        resolveRedirectURLRecursive(absoluteUrl, maxDepth: maxDepth - 1, completion: completion)
                        return
                    }
                }
            }
            
            // HEADで情報が得られない場合、GETで試す
            self.resolveWithGET(url, completion: completion)
        }
        
        task.resume()
    }
    
    private static func formatDateToYYMMDD(_ dateString: String) -> String {
        if dateString.count == 8 {
            return String(dateString.dropFirst(2))
        }
        return dateString
    }
    
    /// URLパスからSkyscanner情報を抽出
    private static func parseSkyscannerPath(_ urlString: String) -> SkyscannerFlightInfo? {
        print("🔍 Parsing URL: \(urlString)")
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL")
            return nil
        }
        print("📍 Host: \(url.host ?? "nil")")
        print("📍 Path: \(url.path)")
        
        guard url.host?.contains("skyscanner") == true else {
            print("❌ Not a Skyscanner URL")
            return nil
        }
        
        let pathComponents = url.path.split(separator: "/").map(String.init)
        print("📍 Path components: \(pathComponents)")
        
        // パターン1: /transport/flights/DEP/ARR/DATE/ または /transport/flights/DEP/ARR/DATE/RETURNDATE/
        if pathComponents.count >= 5, pathComponents[0] == "transport", pathComponents[1] == "flights" {
            let departure = pathComponents[2].lowercased()
            let arrival = pathComponents[3].lowercased()
            let departDate = pathComponents[4]
            
            let formattedDepartDate = formatDateToYYMMDD(departDate)
            print("✅ Extracted: \(departure) -> \(arrival) on \(formattedDepartDate)")
            
            // パターン2: /config/... 形式をチェック（往路のみ）
            if pathComponents.count >= 6 && pathComponents[5] == "config" {
                print("✅ One-way flight (config pattern)")
                return SkyscannerFlightInfo(
                    departure: departure,
                    arrival: arrival,
                    departureDate: formattedDepartDate,
                    returnDate: nil,
                    isRoundTrip: false
                )
            }
            
            // パターン3: 通常の往復
            if pathComponents.count >= 6 && !pathComponents[5].isEmpty && pathComponents[5] != "config" {
                let returnDate = pathComponents[5]
                let formattedReturnDate = formatDateToYYMMDD(returnDate)
                print("✅ Return date: \(formattedReturnDate)")
                
                return SkyscannerFlightInfo(
                    departure: departure,
                    arrival: arrival,
                    departureDate: formattedDepartDate,
                    returnDate: formattedReturnDate,
                    isRoundTrip: true
                )
            } else {
                print("✅ One-way flight")
                return SkyscannerFlightInfo(
                    departure: departure,
                    arrival: arrival,
                    departureDate: formattedDepartDate,
                    returnDate: nil,
                    isRoundTrip: false
                )
            }
        }
        
        // パターン4: クエリパラメータ式
        if let query = url.query {
            print("📍 Query parameters: \(query)")
            if let departure = extractQueryParam(query, "departure") ?? extractQueryParam(query, "from"),
               let arrival = extractQueryParam(query, "arrival") ?? extractQueryParam(query, "to"),
               let departDate = extractQueryParam(query, "departDate") ?? extractQueryParam(query, "outboundDate") {
                
                let formattedDepartDate = formatDateToYYMMDD(departDate)
                print("✅ Extracted: \(departure) -> \(arrival) on \(formattedDepartDate)")
                
                if let returnDate = extractQueryParam(query, "returnDate") ?? extractQueryParam(query, "inboundDate") {
                    let formattedReturnDate = formatDateToYYMMDD(returnDate)
                    return SkyscannerFlightInfo(
                        departure: departure,
                        arrival: arrival,
                        departureDate: formattedDepartDate,
                        returnDate: formattedReturnDate,
                        isRoundTrip: true
                    )
                } else {
                    return SkyscannerFlightInfo(
                        departure: departure,
                        arrival: arrival,
                        departureDate: formattedDepartDate,
                        returnDate: nil,
                        isRoundTrip: false
                    )
                }
            }
        }
        
        print("❌ Couldn't match any pattern. Components: \(pathComponents)")
        return nil
    }
    
    private static func extractQueryParam(_ query: String, _ name: String) -> String? {
        let components = query.split(separator: "&").map(String.init)
        for component in components {
            let parts = component.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 && parts[0] == name {
                return parts[1].removingPercentEncoding ?? parts[1]
            }
        }
        return nil
    }
    
    // MARK: - URL Shortening
    
    func shortenURL(_ url: String, completion: @escaping (String?) -> Void) {
        let apiKey = "7d2ad123799e3bdd05a3553b5d2f7968"
        let encodedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url
        let urlString = "https://xgd.io/V1/shorten?url=\(encodedUrl)&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL for xgd.io API")
            completion(nil)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ URL shortening error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("❌ No data received from xgd.io")
                completion(nil)
                return
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? ""
            print("📊 xgd.io response: \(responseString)")
            
            // xgd.io returns JSON with "shortUrl" field
            // Example: {"shortUrl":"https://xgd.io/abc123","originalUrl":"..."}
            if let jsonData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let shortUrl = jsonData["shortUrl"] as? String {
                print("✅ Shortened URL: \(shortUrl)")
                completion(shortUrl)
                return
            }
            
            // Fallback: try to extract URL from plain text response
            if responseString.contains("http") {
                let components = responseString.components(separatedBy: "\"")
                for component in components {
                    if component.hasPrefix("http") {
                        print("✅ Extracted shortened URL: \(component)")
                        completion(component)
                        return
                    }
                }
            }
            
            print("❌ Could not parse shortened URL from response")
            completion(nil)
        }
        
        task.resume()
    }
}

// MARK: - Data Models

struct SkyscannerFlightInfo {
    let departure: String
    let arrival: String
    let departureDate: String
    let returnDate: String?
    let isRoundTrip: Bool
}
