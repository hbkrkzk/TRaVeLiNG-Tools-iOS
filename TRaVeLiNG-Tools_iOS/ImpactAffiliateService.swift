import Foundation

class ImpactAffiliateService {
    // MARK: - Impact.com API Configuration
    
    private static let (partnerID, apiKey, apiSecret, programID) = loadCredentials()
    private static let baseURL = "https://api.impact.com/Mediapartners"
    
    private static func loadCredentials() -> (String, String, String, String) {
        // Try to load from ImpactConfig.plist
        if let configPath = Bundle.main.path(forResource: "ImpactConfig", ofType: "plist"),
           let config = NSDictionary(contentsOfFile: configPath) as? [String: Any] {
            let partnerID = config["IMPACT_PARTNER_ID"] as? String ?? ""
            let apiKey = config["IMPACT_API_KEY"] as? String ?? ""
            let apiSecret = config["IMPACT_API_SECRET"] as? String ?? ""
            let programID = config["IMPACT_PROGRAM_ID"] as? String ?? ""
            if !apiKey.isEmpty && !apiSecret.isEmpty {
                return (partnerID, apiKey, apiSecret, programID)
            }
        }
        
        // Fallback to Info.plist
        if let partnerID = Bundle.main.infoDictionary?["IMPACT_PARTNER_ID"] as? String,
           let apiKey = Bundle.main.infoDictionary?["IMPACT_API_KEY"] as? String,
           let apiSecret = Bundle.main.infoDictionary?["IMPACT_API_SECRET"] as? String,
           !apiKey.isEmpty && !apiSecret.isEmpty {
            let programID = Bundle.main.infoDictionary?["IMPACT_PROGRAM_ID"] as? String ?? "13416"
            return (partnerID, apiKey, apiSecret, programID)
        }
        
        // Return empty credentials if nothing found
        return ("", "", "", "13416")
    }
    
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()
    
    // MARK: - Error Types
    
    enum ImpactError: LocalizedError {
        case invalidURL
        case networkError(Error)
        case invalidResponse
        case decodingError(Error)
        case apiError(String)
        case noTrackingURL
        case missingAPICredentials
        case authenticationFailed(statusCode: Int)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "無効なSkyscanner URLです"
            case .networkError(let error):
                return "ネットワークエラー: \(error.localizedDescription)"
            case .invalidResponse:
                return "無効なAPIレスポンスです"
            case .decodingError(let error):
                return "レスポンス解析エラー: \(error.localizedDescription)"
            case .apiError(let message):
                return "APIエラー: \(message)"
            case .noTrackingURL:
                return "トラッキングURLが返されませんでした"
            case .missingAPICredentials:
                return "API認証情報が設定されていません。ImpactConfig.plist または Info.plist に API キーを設定してください"
            case .authenticationFailed(let statusCode):
                if statusCode == 401 {
                    return "API認証エラー (401): APIキーが無効または期限切れの可能性があります。設定を確認してください"
                } else if statusCode == 403 {
                    return "API許可エラー (403): このAPIキーには必要な権限がありません"
                } else {
                    return "認証エラー: HTTPステータス \(statusCode)"
                }
            }
        }
    }
    
    // MARK: - Response Model
    
    private struct TrackingLinkResponse: Codable {
        let trackingURL: String?
        
        enum CodingKeys: String, CodingKey {
            case trackingURL = "TrackingURL"
        }
    }
    
    // MARK: - Main API Method
    
    /// Impact.com APIを使用してSkyscanner URLからトラッキングリンクを生成
    /// - Parameter skyscannerLink: Skyscanner のアフィリエイトURL
    /// - Returns: vanity形式のトラッキングURL (例: skyscanner.pxf.io/ZVVoQq)
    static func generateTrackingLink(skyscannerLink: String) async throws -> String {
        // Input validation
        guard !skyscannerLink.isEmpty else {
            throw ImpactError.invalidURL
        }
        
        // Check if API credentials are configured
        if apiKey.isEmpty || apiSecret.isEmpty {
            print("⚠️  API credentials not configured. Using fallback affiliate URL generation.")
            return generateFallbackAffiliateURL(skyscannerLink)
        }
        
        // URL encode the deep link
        guard let encodedLink = skyscannerLink.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw ImpactError.invalidURL
        }
        
        // Build API URL
        let urlString = "\(baseURL)/\(partnerID)/Programs/\(programID)/TrackingLinks?DeepLink=\(encodedLink)&Type=vanity"
        guard let url = URL(string: urlString) else {
            throw ImpactError.invalidURL
        }
        
        // Prepare request with authentication
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add Basic Authentication
        let credentials = "\(apiKey):\(apiSecret)"
        guard let credentialsData = credentials.data(using: .utf8) else {
            throw ImpactError.missingAPICredentials
        }
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        // Send request
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ImpactError.invalidResponse
            }
            
            // Check HTTP status
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                print("⚠️  API authentication failed with status \(httpResponse.statusCode). Using fallback affiliate URL generation.")
                throw ImpactError.authenticationFailed(statusCode: httpResponse.statusCode)
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = parseErrorResponse(data)
                throw ImpactError.apiError("HTTPステータス: \(httpResponse.statusCode) - \(errorMessage)")
            }
            
            // Parse response
            let decoder = JSONDecoder()
            let trackingResponse = try decoder.decode(TrackingLinkResponse.self, from: data)
            
            guard var trackingURL = trackingResponse.trackingURL, !trackingURL.isEmpty else {
                throw ImpactError.noTrackingURL
            }
            
            // xgd.io など他のサービスに渡すため、完全なURLにしておく
            if !trackingURL.hasPrefix("http") {
                trackingURL = "https://" + trackingURL
            }
            
            return trackingURL
        } catch let error as ImpactError {
            throw error
        } catch let error as DecodingError {
            throw ImpactError.decodingError(error)
        } catch {
            throw ImpactError.networkError(error)
        }
    }
    
    // MARK: - Fallback Method
    
    /// APIが利用できない場合のフォールバック実装
    /// Skyscanner pxf.io形式を使用：https://skyscanner.pxf.io/c/{campaignId}/{adId}/{programId}?u={encodedURL}
    private static func generateFallbackAffiliateURL(_ landingPageURL: String) -> String {
        let campaignId = "6120265"
        let adId = "1027991"
        let programId = "13416"
        
        guard let encodedURL = landingPageURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return landingPageURL
        }
        
        return "https://skyscanner.pxf.io/c/\(campaignId)/\(adId)/\(programId)?u=\(encodedURL)"
    }
    
    // MARK: - Helper Methods
    
    private static func parseErrorResponse(_ data: Data) -> String {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                return message
            }
        } catch {
            if let errorString = String(data: data, encoding: .utf8) {
                return errorString
            }
        }
        return "不明なエラー"
    }
}
