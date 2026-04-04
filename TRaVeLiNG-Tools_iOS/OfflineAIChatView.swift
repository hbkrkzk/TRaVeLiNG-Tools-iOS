//
//  OfflineAIChatView.swift
//  TRaVeLiNG-Tools-iOS
//
//  Created with guidance from Apple Intelligence Chat
//

import SwiftUI
import FoundationModels

/// Main chat interface view for Offline AI Chat tool
struct OfflineAIChatView: View {
    // MARK: - State Properties
    
    // UI State
    @State private var sessions: [ChatSession] = []
    @State private var currentSessionId: UUID?
    @State private var inputText: String = ""
    @State private var isResponding = false
    @State private var showSettings = false
    @State private var showHistoryList = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    private var currentSessionIndex: Int? {
        sessions.firstIndex(where: { $0.id == currentSessionId })
    }

    private var messages: [ChatMessage] {
        guard let index = currentSessionIndex else { return [] }
        return sessions[index].messages
    }
    
    // Model State
    @State private var session: LanguageModelSession?
    @State private var streamingTask: Task<Void, Never>?
    @State private var model = SystemLanguageModel.default
    
    // Settings
    @AppStorage("offlineChat_useStreaming") private var useStreaming = ChatAppSettings.useStreaming
    @AppStorage("offlineChat_temperature") private var temperature = ChatAppSettings.temperature
    @AppStorage("offlineChat_systemInstructions") private var systemInstructions = ChatAppSettings.systemInstructions
    
    // Haptics
#if os(iOS)
    private let hapticStreamGenerator = UISelectionFeedbackGenerator()
#endif
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Chat Messages ScrollView
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(messages) { message in
                                MessageView(message: message, isResponding: isResponding)
                                    .id(message.id)
                            }
                        }
                        .padding()
                        .padding(.bottom, 90)
                    }
                    .onChange(of: messages.count) {
                        scrollToBottom(with: proxy)
                    }
                    .onAppear {
                        loadChatHistory()
                    }
                }
                
                // Floating Input Field
                VStack {
                    Spacer()
                    inputField
                        .padding(20)
                }
            }
            .navigationTitle("Offline AI Chat")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar { toolbarContent }
            .sheet(isPresented: $showSettings) {
                OfflineAIChatSettings {
                    session = nil
                }
            }
            .sheet(isPresented: $showHistoryList) {
                ChatHistoryListView(sessions: $sessions, currentSessionId: $currentSessionId)
            }
            .alert("エラー", isPresented: $showErrorAlert) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Subviews
    
    /// Floating input field with send/stop button
    private var inputField: some View {
        ZStack {
            TextField("何か質問があれば入力してください", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .frame(minHeight: 22)
                .disabled(isResponding)
                .onSubmit {
                    if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        handleSendOrStop()
                    }
                }
                .padding(16)
            
            HStack {
                Spacer()
                Button(action: handleSendOrStop) {
                    Image(systemName: isResponding ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(isSendButtonDisabled ? Color.gray.opacity(0.6) : .blue)
                }
                .disabled(isSendButtonDisabled)
                .animation(.easeInOut(duration: 0.2), value: isResponding)
                .animation(.easeInOut(duration: 0.2), value: isSendButtonDisabled)
                .padding(.trailing, 8)
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var isSendButtonDisabled: Bool {
        return inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isResponding
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
#if os(iOS)
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: resetConversation) {
                Label("新規", systemImage: "square.and.pencil")
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack {
                Button(action: { showHistoryList = true }) {
                    Label("履歴", systemImage: "clock")
                }
                Button(action: { showSettings = true }) {
                    Label("設定", systemImage: "gearshape")
                }
            }
        }
#else
        ToolbarItem {
            Button(action: resetConversation) {
                Label("新規", systemImage: "square.and.pencil")
            }
        }
        ToolbarItem {
            Button(action: { showHistoryList = true }) {
                Label("履歴", systemImage: "clock")
            }
        }
        ToolbarItem {
            Button(action: { showSettings = true }) {
                Label("設定", systemImage: "gearshape")
            }
        }
#endif
    }
    
    // MARK: - Model Interaction
    
    private func handleSendOrStop() {
        if isResponding {
            stopStreaming()
        } else {
            guard model.isAvailable else {
                showError(message: "言語モデルが利用できません。理由: \(availabilityDescription(for: model.availability))")
                return
            }
            sendMessage()
        }
    }
    
    private func sendMessage() {
        if currentSessionId == nil {
            startNewSession(withTitle: String(inputText.prefix(20)))
        }

        // Auto-update title if it's "新規チャット"
        if let index = currentSessionIndex, sessions[index].title == "新規チャット" {
            let newTitle = String(inputText.prefix(20)).trimmingCharacters(in: .whitespacesAndNewlines)
            sessions[index].title = newTitle.isEmpty ? "チャット" : newTitle
        }

        isResponding = true
        let userMessage = ChatMessage(role: .user, text: inputText)
        
        if let index = currentSessionIndex {
            sessions[index].messages.append(userMessage)
            saveChatHistory()
            
            // Add empty assistant message for streaming
            sessions[index].messages.append(ChatMessage(role: .assistant, text: ""))
            sessions[index].updatedAt = Date()
            saveChatHistory()
        }
        
        let prompt = inputText
        inputText = ""
        
        streamingTask = Task {
            do {
                if session == nil { session = createSession() }
                
                guard let currentSession = session else {
                    showError(message: "セッションを作成できませんでした。")
                    isResponding = false
                    return
                }
                
                let options = GenerationOptions(temperature: temperature)
                
                if useStreaming {
                    let stream = currentSession.streamResponse(to: prompt, options: options)
                    for try await snapshot in stream {
#if os(iOS)
                        hapticStreamGenerator.selectionChanged()
#endif
                        updateLastMessage(with: snapshot.content)
                    }
                } else {
                    let response = try await currentSession.respond(to: prompt, options: options)
                    updateLastMessage(with: response.content)
                }
            } catch is CancellationError {
                // User cancelled generation
            } catch {
                showError(message: "エラーが発生しました: \(error.localizedDescription)")
            }
            
            isResponding = false
            streamingTask = nil
        }
    }
    
    private func stopStreaming() {
        streamingTask?.cancel()
    }
    
    @MainActor
    private func updateLastMessage(with text: String) {
        if let index = currentSessionIndex, !sessions[index].messages.isEmpty {
            let lastMessageIndex = sessions[index].messages.count - 1
            sessions[index].messages[lastMessageIndex].text = text
            sessions[index].updatedAt = Date()
            saveChatHistory()
        }
    }
    
    // MARK: - Session & Helpers
    
    private func createSession() -> LanguageModelSession {
        return LanguageModelSession(instructions: systemInstructions)
    }
    
    private func resetConversation() {
        stopStreaming()
        startNewSession()
    }
    
    private func startNewSession(withTitle title: String = "新規チャット") {
        let newSession = ChatSession(title: title)
        sessions.insert(newSession, at: 0)
        currentSessionId = newSession.id
        session = nil
        saveChatHistory()
    }
    
    private func availabilityDescription(for availability: SystemLanguageModel.Availability) -> String {
        switch availability {
        case .available:
            return "利用可能"
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return "デバイスが対応していません"
            case .appleIntelligenceNotEnabled:
                return "設定でApple Intelligenceが有効になっていません"
            case .modelNotReady:
                return "モデルアセットがダウンロードされていません"
            @unknown default:
                return "不明な理由"
            }
        @unknown default:
            return "不明な利用可能状態"
        }
    }
    
    @MainActor
    private func showError(message: String) {
        self.errorMessage = message
        self.showErrorAlert = true
        self.isResponding = false
    }
    
    // MARK: - Chat History Persistence
    
    private func scrollToBottom(with proxy: ScrollViewProxy) {
        guard let lastMessage = messages.last else { return }
        withAnimation {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
    
    private func saveChatHistory() {
        do {
            let data = try JSONEncoder().encode(sessions)
            UserDefaults.standard.set(data, forKey: "offlineChat_sessions")
        } catch {
            print("Failed to save chat sessions: \(error)")
        }
    }
    
    private func loadChatHistory() {
        // Try to load new format first
        if let data = UserDefaults.standard.data(forKey: "offlineChat_sessions"),
           let loadedSessions = try? JSONDecoder().decode([ChatSession].self, from: data) {
            sessions = loadedSessions
            if currentSessionId == nil {
                currentSessionId = sessions.first?.id
            }
            return
        }
        
        // Migrate old format
        if let data = UserDefaults.standard.data(forKey: "offlineChat_history"),
           let oldMessages = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            let migratedSession = ChatSession(title: "以前のチャット", messages: oldMessages)
            sessions = [migratedSession]
            currentSessionId = migratedSession.id
            saveChatHistory()
            UserDefaults.standard.removeObject(forKey: "offlineChat_history") // Cleanup old data
            return
        }
        
        // No history at all
        startNewSession()
    }
    
    private func clearChatHistory() {
        // Obsolete
    }
}

// MARK: - Chat History List View

struct ChatHistoryListView: View {
    @Binding var sessions: [ChatSession]
    @Binding var currentSessionId: UUID?
    @Environment(\.dismiss) private var dismiss
    
    // Auto-update timestamps formatted
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(sessions.sorted(by: { $0.updatedAt > $1.updatedAt })) { session in
                    Button(action: {
                        currentSessionId = session.id
                        dismiss()
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.title)
                                .font(.headline)
                                .foregroundColor(currentSessionId == session.id ? .blue : .primary)
                            
                            Text(dateFormatter.string(from: session.updatedAt))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let lastMessage = session.messages.last(where: { $0.role == .user }) {
                                Text(lastMessage.text)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            } else {
                                Text("メッセージがありません")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: deleteSessions)
            }
            .navigationTitle("チャット履歴")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
#else
            .toolbar {
                ToolbarItem {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
#endif
        }
    }
    
    private func deleteSessions(offsets: IndexSet) {
        let sortedSessions = sessions.sorted(by: { $0.updatedAt > $1.updatedAt })
        let idsToDelete = offsets.map { sortedSessions[$0].id }
        
        sessions.removeAll { idsToDelete.contains($0.id) }
        
        if let currentId = currentSessionId, idsToDelete.contains(currentId) {
            currentSessionId = sessions.first?.id
        }
    }
}

#Preview {
    OfflineAIChatView()
}
