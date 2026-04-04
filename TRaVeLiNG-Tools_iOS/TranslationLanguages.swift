//
//  TranslationLanguages.swift
//  TRaVeLiNG-Tools-iOS
//
//  Created with guidance from Pre-Babel-Lens
//

import Foundation

// MARK: - Language Models

struct Language: Identifiable, Hashable {
    let id: String
    let name: String
    let nativeName: String
    let flag: String
}

// MARK: - Supported Languages

let supportedLanguages: [Language] = [
    Language(id: "ja", name: "Japanese", nativeName: "日本語", flag: "🇯🇵"),
    Language(id: "en", name: "English", nativeName: "English", flag: "🇺🇸"),
    Language(id: "zh", name: "Chinese (Simplified)", nativeName: "简体中文", flag: "🇨🇳"),
    Language(id: "ko", name: "Korean", nativeName: "한국어", flag: "🇰🇷"),
    Language(id: "es", name: "Spanish", nativeName: "Español", flag: "🇪🇸"),
    Language(id: "fr", name: "French", nativeName: "Français", flag: "🇫🇷"),
    Language(id: "de", name: "German", nativeName: "Deutsch", flag: "🇩🇪"),
    Language(id: "it", name: "Italian", nativeName: "Italiano", flag: "🇮🇹"),
    Language(id: "pt", name: "Portuguese", nativeName: "Português", flag: "🇵🇹"),
    Language(id: "ru", name: "Russian", nativeName: "Русский", flag: "🇷🇺"),
    Language(id: "ar", name: "Arabic", nativeName: "العربية", flag: "🇸🇦"),
    Language(id: "hi", name: "Hindi", nativeName: "हिन्दी", flag: "🇮🇳"),
    Language(id: "th", name: "Thai", nativeName: "ไทย", flag: "🇹🇭"),
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
    
    init(source: String, translated: String, sourceLang: String, targetLang: String) {
        self.id = UUID()
        self.source = source
        self.translated = translated
        self.sourceLang = sourceLang
        self.targetLang = targetLang
        self.timestamp = Date()
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
