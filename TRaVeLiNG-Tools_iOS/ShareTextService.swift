import Foundation

// MARK: - Share Text Model

struct ShareTextTemplate {
    let id: String
    let name: String
    let isRoundTrip: Bool
    let templateText: String
}

// MARK: - Share Text Service

class ShareTextService {
    static let shared = ShareTextService()
    
    private let roundTripKey = "shareText_roundtrip"
    private let onewayKey = "shareText_oneway"
    
    private let defaultRoundTripTemplate = """
✈️スカイスキャナーで検索
往復: {URL}

💳️セゾンプラチナビジネス
✅PP無料付帯
▽特別招待ー初年度無料＆アマギフ1.2万
https://x.gd/xdQok
"""
    
    private let defaultOnewayTemplate = """
✈️スカイスキャナーで検索
片道: {URL}

💳️セゾンプラチナビジネス
✅PP無料付帯
▽特別招待ー初年度無料＆アマギフ1.2万
https://x.gd/xdQok
"""
    
    // MARK: - Initialization
    
    init() {
        // Initialize defaults if not set (first launch only)
        if UserDefaults.standard.string(forKey: roundTripKey) == nil {
            UserDefaults.standard.set(defaultRoundTripTemplate, forKey: roundTripKey)
        }
        if UserDefaults.standard.string(forKey: onewayKey) == nil {
            UserDefaults.standard.set(defaultOnewayTemplate, forKey: onewayKey)
        }
    }
    
    // MARK: - Template Management
    
    func getRoundTripTemplate() -> String {
        return UserDefaults.standard.string(forKey: roundTripKey) ?? defaultRoundTripTemplate
    }
    
    func getOnewayTemplate() -> String {
        return UserDefaults.standard.string(forKey: onewayKey) ?? defaultOnewayTemplate
    }
    
    func setRoundTripTemplate(_ template: String) {
        UserDefaults.standard.set(template, forKey: roundTripKey)
    }
    
    func setOnewayTemplate(_ template: String) {
        UserDefaults.standard.set(template, forKey: onewayKey)
    }
    
    func resetToDefaults() {
        UserDefaults.standard.set(defaultRoundTripTemplate, forKey: roundTripKey)
        UserDefaults.standard.set(defaultOnewayTemplate, forKey: onewayKey)
    }
    
    // MARK: - Share Text Generation
    
    func generateShareText(
        isRoundTrip: Bool,
        shortenedURL: String
    ) -> String {
        let template = isRoundTrip ? getRoundTripTemplate() : getOnewayTemplate()
        let shareText = template.replacingOccurrences(of: "{URL}", with: shortenedURL)
        print("📝 Generated share text:\n\(shareText)")
        return shareText
    }
    
    /// パートナーアフィリエイト対応のシェアテキスト生成
    func generateShareTextWithPartner(
        isRoundTrip: Bool,
        partnerName: String,
        partnerURL: String,
        skycannerURL: String
    ) -> String {
        let template = isRoundTrip ? getRoundTripTemplate() : getOnewayTemplate()
        
        // パートナーリンク部分
        let partnerLine = """
✈️\(partnerName)で予約
\(partnerURL)

"""
        
        // スカイスキャナー部分を置き換え
        let replaceKey = "✈️スカイスキャナーで検索\n\(isRoundTrip ? "往復" : "片道"): {URL}"
        let skycannerLine = "✈️スカイスキャナーで検索\n\(isRoundTrip ? "往復" : "片道"): \(skycannerURL)"
        
        var shareText = template
        shareText = shareText.replacingOccurrences(of: replaceKey, with: partnerLine + skycannerLine)
        
        print("📝 Generated partner share text:\n\(shareText)")
        return shareText
    }
    
    // MARK: - Validation
    
    func validateTemplate(_ template: String) -> Bool {
        // Check if template contains {URL} placeholder
        return template.contains("{URL}")
    }
}
