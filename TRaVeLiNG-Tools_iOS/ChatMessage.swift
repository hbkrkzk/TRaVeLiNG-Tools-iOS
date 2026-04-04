//
//  ChatMessage.swift
//  TRaVeLiNG-Tools-iOS
//
//  Created with guidance from Apple Intelligence Chat
//

import SwiftUI

// MARK: - Chat Role

enum ChatRole: String, Codable {
    case user
    case assistant
}

// MARK: - Chat Message Model

struct ChatMessage: Identifiable, Equatable, Codable {
    let id: UUID
    var role: ChatRole
    var text: String
    
    init(role: ChatRole, text: String) {
        self.id = UUID()
        self.role = role
        self.text = text
    }
}

// MARK: - Message View Component

struct MessageView: View {
    let message: ChatMessage
    let isResponding: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .assistant {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(width: 28, height: 28)
                    .padding(.top, 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.text)
                        .textSelection(.enabled)
                    
                    if isResponding && message.text.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { index in
                                Circle()
                                    .fill(.secondary)
                                    .frame(width: 4)
                                    .opacity(Double(index) * 0.3 + 0.4)
                                    .animation(
                                        Animation.easeInOut(duration: 0.6)
                                            .repeatForever()
                                            .delay(Double(index) * 0.1),
                                        value: isResponding
                                    )
                            }
                        }
                        .frame(height: 20)
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                Spacer()
            } else {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 0) {
                    Text(message.text)
                        .textSelection(.enabled)
                }
                .padding(12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.gray)
                    .frame(width: 28, height: 28)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    VStack(spacing: 16) {
        MessageView(
            message: ChatMessage(role: .assistant, text: "こんにちは！何かお手伝いできることがありますか？"),
            isResponding: false
        )
        MessageView(
            message: ChatMessage(role: .user, text: "こんにちは。今日のスケジュールを教えてください"),
            isResponding: false
        )
        MessageView(
            message: ChatMessage(role: .assistant, text: ""),
            isResponding: true
        )
    }
    .padding()
}

// MARK: - Chat Session

struct ChatSession: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var messages: [ChatMessage]
    
    init(id: UUID = UUID(), title: String = "新規チャット", createdAt: Date = Date(), updatedAt: Date = Date(), messages: [ChatMessage] = []) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }
}
