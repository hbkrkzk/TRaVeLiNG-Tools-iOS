//
//  TranslationLanguages.swift
//  TRaVeLiNG-Tools-iOS
//
//  Created with guidance from Pre-Babel-Lens
//

import Foundation
import SwiftUI

// MARK: - Language Models

struct Language: Identifiable, Hashable {
    let id: String
    let name: String
    let nativeName: String
    let flag: String
}

// MARK: - Supported Languages

let supportedLanguages: [Language] = [
    Language(id: "en", name: "English", nativeName: "English", flag: "🇺🇸"),
    Language(id: "ja", name: "Japanese", nativeName: "日本語", flag: "🇯🇵"),
    Language(id: "zh", name: "Chinese (Simplified)", nativeName: "简体中文", flag: "🇨🇳"),
    Language(id: "zh-HK", name: "Chinese (Traditional, Hong Kong)", nativeName: "繁體中文 (香港)", flag: "🇭🇰"),
    Language(id: "zh-TW", name: "Chinese (Traditional, Taiwan)", nativeName: "繁體中文 (台灣)", flag: "🇹🇼"),
    Language(id: "ko", name: "Korean", nativeName: "한국어", flag: "🇰🇷"),
    Language(id: "vi", name: "Vietnamese", nativeName: "Tiếng Việt", flag: "🇻🇳"),
    Language(id: "id", name: "Indonesian", nativeName: "Bahasa Indonesia", flag: "🇮🇩"),
    Language(id: "ms", name: "Malay", nativeName: "Bahasa Melayu", flag: "🇲🇾"),
    Language(id: "th", name: "Thai", nativeName: "ไทย", flag: "🇹🇭"),
    Language(id: "es", name: "Spanish", nativeName: "Español", flag: "🇪🇸"),
    Language(id: "fr", name: "French", nativeName: "Français", flag: "🇫🇷"),
    Language(id: "de", name: "German", nativeName: "Deutsch", flag: "🇩🇪"),
    Language(id: "it", name: "Italian", nativeName: "Italiano", flag: "🇮🇹"),
    Language(id: "pt", name: "Portuguese", nativeName: "Português", flag: "🇵🇹"),
    Language(id: "ru", name: "Russian", nativeName: "Русский", flag: "🇷🇺"),
    Language(id: "mn", name: "Mongolian", nativeName: "Монгол хэл", flag: "🇲🇳"),
    Language(id: "kk", name: "Kazakh", nativeName: "Қазақ тілі", flag: "🇰🇿"),
    Language(id: "uz", name: "Uzbek", nativeName: "Oʻzbek tili", flag: "🇺🇿"),
    Language(id: "ky", name: "Kyrgyz", nativeName: "Кыргызча", flag: "🇰🇬"),
    Language(id: "tg", name: "Tajik", nativeName: "Тоҷикӣ", flag: "🇹🇯"),
    Language(id: "tk", name: "Turkmen", nativeName: "Türkmen dili", flag: "🇹🇲"),
    Language(id: "ar", name: "Arabic", nativeName: "العربية", flag: "🇸🇦"),
    Language(id: "hi", name: "Hindi", nativeName: "हिन्दी", flag: "🇮🇳"),
]

// MARK: - Language Detection

func detectLanguageCode(_ text: String) -> String? {
    let tagger = NSLinguisticTagger(tagSchemes: [.language], options: 0)
    tagger.string = text
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    let tag = tagger.tag(at: 0, scheme: .language, tokenRange: nil, sentenceRange: nil)
    return tag?.rawValue
}

func getLanguageByCode(_ code: String) -> Language? {
    return supportedLanguages.first { $0.id == code }
}

// MARK: - Translation Entry

struct TranslationEntry: Identifiable, Codable {
    let id: UUID
    var source: String
    var translated: String
    var sourceLang: String
    var targetLang: String
    var timestamp: Date
    var pronunciation: String?
    
    init(source: String, translated: String, sourceLang: String, targetLang: String, pronunciation: String? = nil) {
        self.id = UUID()
        self.source = source
        self.translated = translated
        self.sourceLang = sourceLang
        self.targetLang = targetLang
        self.timestamp = Date()
        self.pronunciation = pronunciation
    }
}

#Preview {
    VStack(spacing: 16) {
        ForEach(supportedLanguages.prefix(5)) { lang in
            HStack {
                Text(lang.flag)
                    .font(.title2)
                VStack(alignment: .leading) {
                    Text(lang.name)
                        .font(.headline)
                    Text(lang.nativeName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(lang.id)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
    .padding()
}
