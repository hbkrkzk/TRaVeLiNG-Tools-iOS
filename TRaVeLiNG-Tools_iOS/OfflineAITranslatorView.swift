//
//  OfflineAITranslatorView.swift
//  TRaVeLiNG-Tools-iOS
//
//  Created with guidance from Pre-Babel-Lens
//

import SwiftUI
import FoundationModels
import AVFoundation
import Speech

// MARK: - Text-to-Speech Manager

class TTSManager: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = TTSManager()
    
    private let synthesizer = AVSpeechSynthesizer()
    var isPlaying = false
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    func speak(_ text: String, language: Language) {
        // Stop any ongoing speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
        
        let utterance = AVSpeechUtterance(string: text)
        let bcp47 = getBCP47Identifier(for: language.id)
        utterance.voice = AVSpeechSynthesisVoice(language: bcp47)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        isPlaying = true
        synthesizer.speak(utterance)
    }
    
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            isPlaying = false
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isPlaying = false
    }
}

// MARK: - Speech Recognizer

class SpeechRecognizer: ObservableObject {
    @Published var isRecording = false
    @Published var errorMessage: String?
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }
    
    func startRecording(languageCode: String, onUpdate: @escaping (String) -> Void) {
        stopRecording()
        
        let bcp47 = getBCP47Identifier(for: languageCode)
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: bcp47))
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            self.errorMessage = "音声認識が利用できません"
            return
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            self.errorMessage = "マイクの設定に失敗しました"
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    onUpdate(text)
                }
            }
            if error != nil {
                DispatchQueue.main.async {
                    self.stopRecording()
                }
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
            self.isRecording = true
            self.errorMessage = nil
        } catch {
            self.errorMessage = "録音開始に失敗しました"
            self.stopRecording()
        }
    }
    
    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        recognitionRequest?.endAudio()
        
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }
}

// MARK: - Keyboard Helper

#if canImport(UIKit)
import UIKit

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

// MARK: - Language Models

struct Language: Identifiable, Hashable {
    let id: String
    let name: String
    let nativeName: String
    let flag: String
}

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

// MARK: - Language Code Mapping for API

/// Converts local language codes to supported API language codes
func apiLanguageCode(_ localCode: String) -> String {
    switch localCode {
    case "zh":
        return "zh" // Chinese (Simplified)
    case "pt":
        return "pt" // Portuguese
    default:
        return localCode
    }
}

/// Converts base code to full BCP-47 for speech services
func getBCP47Identifier(for langCode: String) -> String {
    switch langCode {
    case "ja": return "ja-JP"
    case "en": return "en-US"
    case "zh": return "zh-CN"
    case "zh-HK": return "zh-HK"
    case "zh-TW": return "zh-TW"
    case "ko": return "ko-KR"
    case "es": return "es-ES"
    case "fr": return "fr-FR"
    case "de": return "de-DE"
    case "it": return "it-IT"
    case "pt": return "pt-BR"
    case "ru": return "ru-RU"
    case "ar": return "ar-SA"
    case "hi": return "hi-IN"
    case "th": return "th-TH"
    case "vi": return "vi-VN"
    case "id": return "id-ID"
    case "ms": return "ms-MY"
    case "mn": return "mn-MN"
    case "kk": return "kk-KZ"
    case "uz": return "uz-UZ"
    case "ky": return "ky-KG"
    case "tg": return "tg-TJ"
    case "tk": return "tk-TM"
    default: return langCode
    }
}

/// Offline AI Translator tool view
struct OfflineAITranslatorView: View {
    // MARK: - State Properties
    
    @State private var sourceText: String = ""
    @State private var translatedText: String = ""
    @State private var pronunciationText: String = ""
    @State private var sourceLanguage: Language = supportedLanguages.first { $0.id == "en" } ?? supportedLanguages[0]
    @State private var targetLanguage: Language = supportedLanguages.first { $0.id == "ja" } ?? supportedLanguages[0]
    @State private var isTranslating = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var detectedLanguage: Language?
    @State private var translationHistory: [TranslationEntry] = []
    @State private var isPlaying = false
    @State private var baseRecordingText = ""
    
    // Model State
    @State private var session: LanguageModelSession?
    @State private var translationTask: Task<Void, Never>?
    @State private var model = SystemLanguageModel.default
    
    // Speech & TTS
    private let ttsManager = TTSManager.shared
    @StateObject private var speechRecognizer = SpeechRecognizer()
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // Language Selector
                    languageSelectorBar
                    
                    // Source Text Area
                    sourceTextSection
                    
                    // Divider
                    Divider()
                        .padding(.vertical, 12)
                    
                    // Target Text Area
                    targetTextSection
                }
                .padding()
                
                // Floating Translate Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: handleTranslate) {
                            Image(systemName: isTranslating ? "stop.circle.fill" : "arrow.triangle.2.circlepath")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(16)
                        }
                        .background(isTranslating ? Color.red : Color.blue)
                        .clipShape(Circle())
                        .disabled(sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTranslating)
                        .opacity(sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTranslating ? 0.5 : 1.0)
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Offline AI Translator")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar { toolbarContent }
            .alert("エラー", isPresented: $showErrorAlert) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .onReceive(speechRecognizer.$errorMessage) { msg in
                if let msg = msg {
                    showError(message: msg)
                    speechRecognizer.errorMessage = nil
                }
            }
        }
        .onAppear {
            loadTranslationHistory()
        }
    }
    
    // MARK: - Subviews
    
    private var languageSelectorBar: some View {
        HStack(spacing: 12) {
            // Source Language
            Menu {
                ForEach(supportedLanguages) { lang in
                    Button(action: { sourceLanguage = lang }) {
                        HStack {
                            Text(lang.flag)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lang.name)
                                    .font(.body.weight(.semibold))
                                Text(lang.nativeName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if lang.id == sourceLanguage.id {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } label: {
                VStack(spacing: 2) {
                    Text(sourceLanguage.flag)
                        .font(.title3)
                    VStack(spacing: 0) {
                        Text(sourceLanguage.name)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.primary)
                        Text(sourceLanguage.nativeName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Swap Button
            Button(action: swapLanguages) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }
            
            // Target Language
            Menu {
                ForEach(supportedLanguages) { lang in
                    Button(action: { targetLanguage = lang }) {
                        HStack {
                            Text(lang.flag)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lang.name)
                                    .font(.body.weight(.semibold))
                                Text(lang.nativeName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if lang.id == targetLanguage.id {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } label: {
                VStack(spacing: 2) {
                    Text(targetLanguage.flag)
                        .font(.title3)
                    VStack(spacing: 0) {
                        Text(targetLanguage.name)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.primary)
                        Text(targetLanguage.nativeName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.bottom, 12)
    }
    
    private var sourceTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("ソーステキスト", systemImage: "text.bubble")
                    .font(.headline)
                Spacer()
                if let detected = detectedLanguage {
                    Text("\(detected.flag) \(detected.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Button(action: toggleRecording) {
                    HStack(spacing: 6) {
                        Image(systemName: speechRecognizer.isRecording ? "stop.fill" : "mic.fill")
                            .frame(width: 14, height: 14)
                        Text(speechRecognizer.isRecording ? "録音停止" : "音声入力")
                            .font(.caption.weight(.semibold))
                    }
                    .frame(height: 20)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(speechRecognizer.isRecording ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
            }
            
            TextEditor(text: $sourceText)
                .font(.system(.body, design: .default))
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
                .onChange(of: sourceText) {
                    detectSourceLanguage()
                }
            
            // Character count
            HStack {
                Spacer()
                Text("\(sourceText.count) 文字")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var targetTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("翻訳結果", systemImage: "text.quote")
                    .font(.headline)
                Spacer()
                if !translatedText.isEmpty {
                    Button(action: {
                        if ttsManager.isPlaying {
                            ttsManager.stop()
                            isPlaying = false
                        } else {
                            ttsManager.speak(translatedText, language: targetLanguage)
                            isPlaying = true
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: isPlaying ? "stop.fill" : "speaker.wave.2")
                                .frame(width: 14, height: 14)
                            Text(isPlaying ? "停止" : "再生")
                                .font(.caption.weight(.semibold))
                        }
                        .frame(height: 20)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    
                    Button(action: copyTranslatedText) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.doc")
                                .frame(width: 14, height: 14)
                            Text("コピー")
                                .font(.caption.weight(.semibold))
                        }
                        .frame(height: 20)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: .constant(translatedText))
                    .font(.system(.body, design: .default))
                    .frame(minHeight: 100)
                    .background(Color.clear)
                    .disabled(true)
                
                if !pronunciationText.isEmpty {
                    Divider()
                    Text(pronunciationText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                        .padding(.horizontal, 4)
                }
            }
            .padding(4)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
            
            HStack {
                Spacer()
                Text("\(translatedText.count) 文字")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
#if os(iOS)
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: clearAll) {
                Image(systemName: "trash")
            }
        }
#endif
    }
    
    // MARK: - Actions
    
    private func toggleRecording() {
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
        } else {
            if ttsManager.isPlaying { ttsManager.stop() }
            
            speechRecognizer.requestAuthorization { authorized in
                if authorized {
                    let current = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
                    baseRecordingText = current.isEmpty ? "" : current + " "
                    
                    speechRecognizer.startRecording(languageCode: sourceLanguage.id) { newText in
                        sourceText = baseRecordingText + newText
                    }
                } else {
                    showError(message: "音声認識とマイクへのアクセスが許可されていません。設定アプリから許可してください。")
                }
            }
        }
    }
    
    private func handleTranslate() {
        if isTranslating {
            stopTranslation()
        } else {
            if speechRecognizer.isRecording { speechRecognizer.stopRecording() }
            guard model.isAvailable else {
                showError(message: "言語モデルが利用できません")
                return
            }
            hideKeyboard()
            translate()
        }
    }
    
    private func translate() {
        guard !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isTranslating = true
        translatedText = ""
        
        translationTask = Task {
            do {
                if session == nil {
                    session = LanguageModelSession(instructions: createTranslationInstruction())
                }
                
                guard let currentSession = session else {
                    showError(message: "セッションを作成できませんでした")
                    isTranslating = false
                    return
                }
                
                let sourceLangName = sourceLanguage.nativeName
                let targetLangName = targetLanguage.nativeName
                let sourceLangEn = sourceLanguage.name
                let targetLangEn = targetLanguage.name
                
                let translationPrompt = """
                Translate the following text from \(sourceLangEn) to \(targetLangEn).
                Return exactly two lines:
                Line 1: Only the translated text.
                Line 2: Only the alphabet pronunciation (romanization/pinyin) of the translated text. If the target language naturally uses the Latin alphabet, leave Line 2 empty.
                Do not include any explanations, labels, or additional commentary.
                
                Text to translate:
                \(sourceText)
                """
                
                let response = try await currentSession.respond(
                    to: translationPrompt,
                    options: GenerationOptions(temperature: 0.2)
                )
                
                let responseContent = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                var lines = responseContent.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                
                let translatedContent = lines.first?
                    .replacingOccurrences(of: "**", with: "")
                    .replacingOccurrences(of: "##", with: "") ?? ""
                
                let rawPronunciation = lines.count > 1 ? lines.dropFirst().joined(separator: " ") : ""
                let cleanPronunciation = rawPronunciation
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "**", with: "")
                    .replacingOccurrences(of: "##", with: "")
                
                translatedText = translatedContent
                pronunciationText = cleanPronunciation
                saveTranslationHistory()
            } catch is CancellationError {
                // User cancelled
            } catch {
                let errorMsg = error.localizedDescription
                if errorMsg.contains("unsupported language") {
                    showError(message: "申し訳ありません。この言語ペアはまだサポートされていません。別の言語を選択してください。")
                } else {
                    showError(message: "翻訳エラー: \(errorMsg)")
                }
            }
            
            isTranslating = false
            translationTask = nil
        }
    }
    
    private func stopTranslation() {
        translationTask?.cancel()
        isTranslating = false
    }
    
    private func swapLanguages() {
        let temp = sourceLanguage
        sourceLanguage = targetLanguage
        targetLanguage = temp
        translatedText = ""
    }
    
    private func detectSourceLanguage() {
        guard !sourceText.isEmpty else {
            detectedLanguage = nil
            return
        }
        
        if let code = detectLanguageCode(sourceText),
           let detected = getLanguageByCode(code) {
            detectedLanguage = detected
        }
    }
    
    private func copyTranslatedText() {
        UIPasteboard.general.string = translatedText
    }
    
    private func clearAll() {
        sourceText = ""
        translatedText = ""
        pronunciationText = ""
        detectedLanguage = nil
    }
    
    private func showError(message: String) {
        self.errorMessage = message
        self.showErrorAlert = true
        self.isTranslating = false
    }
    
    private func createTranslationInstruction() -> String {
        return """
        あなたは専門的な翻訳者です。
        入力されたテキストを指定された言語に正確かつ自然に翻訳してください。
        翻訳文のみを返してください。前置きや説明は一切不要です。
        """
    }
    
    // MARK: - History
    
    private func saveTranslationHistory() {
        let entry = TranslationEntry(
            source: sourceText,
            translated: translatedText,
            sourceLang: sourceLanguage.id,
            targetLang: targetLanguage.id,
            pronunciation: pronunciationText.isEmpty ? nil : pronunciationText
        )
        translationHistory.append(entry)
        
        if translationHistory.count > 50 {
            translationHistory.removeFirst()
        }
        
        do {
            let data = try JSONEncoder().encode(translationHistory)
            UserDefaults.standard.set(data, forKey: "translator_history")
        } catch {
            print("Failed to save translation history: \(error)")
        }
    }
    
    private func loadTranslationHistory() {
        guard let data = UserDefaults.standard.data(forKey: "translator_history") else {
            return
        }
        
        do {
            translationHistory = try JSONDecoder().decode([TranslationEntry].self, from: data)
        } catch {
            print("Failed to load translation history: \(error)")
        }
    }
}

#Preview {
    OfflineAITranslatorView()
}
