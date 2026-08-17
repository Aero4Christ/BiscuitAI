import Combine
import Foundation

enum ReplyState: Equatable {
    case idle
    case streaming
    case failed(String)
    case cancelled
}

private extension ReplyState {
    var isRetryable: Bool {
        switch self {
        case .failed, .cancelled:
            return true
        case .idle, .streaming:
            return false
        }
    }
}

@MainActor
final class ChatStore: ObservableObject {
    @Published private(set) var conversations: [Conversation]
    @Published var selectedConversationID: UUID?
    @Published private(set) var isReplying = false
    @Published private(set) var activeConversationID: UUID?
    @Published private(set) var replyStates: [UUID: ReplyState] = [:]
    @Published var notice: AppNotice?

    private let legacyStorageKey = "biscuitai-conversations-v1"
    private let conversationStore: any ConversationPersisting
    private let client: any OpenRouterServicing
    private var replyTask: Task<Void, Never>?
    private var flushTask: Task<Void, Never>?
    private var pendingResponseText = ""

    init(
        conversationStore: any ConversationPersisting = ConversationStore(),
        client: any OpenRouterServicing = OpenRouterClient()
    ) {
        self.conversationStore = conversationStore
        self.client = client
        let fileConversations = try? conversationStore.load()
        let legacyConversations = UserDefaults.standard.data(forKey: legacyStorageKey)
            .flatMap { try? JSONDecoder().decode([Conversation].self, from: $0) } ?? []
        let loaded = fileConversations?.isEmpty == false ? fileConversations! : legacyConversations
        conversations = loaded.sorted { $0.updatedAt > $1.updatedAt }
        if fileConversations?.isEmpty != false, !legacyConversations.isEmpty {
            try? conversationStore.save(conversations)
        }
        selectedConversationID = conversations.first?.id
    }

    var currentMessages: [ChatMessage] {
        guard let id = selectedConversationID,
              let conversation = conversations.first(where: { $0.id == id }) else { return [] }
        return conversation.messages
    }

    var currentConversationTitle: String? {
        guard let id = selectedConversationID else { return nil }
        return conversations.first(where: { $0.id == id })?.title
    }

    func startNewChat() {
        selectedConversationID = nil
        notice = nil
    }

    func select(_ conversation: Conversation) {
        selectedConversationID = conversation.id
        notice = nil
    }

    func delete(_ conversation: Conversation) {
        if activeConversationID == conversation.id {
            cancelReply()
        }
        conversations.removeAll { $0.id == conversation.id }
        if selectedConversationID == conversation.id {
            selectedConversationID = conversations.first?.id
        }
        save()
    }

    func send(_ rawText: String, settings: SettingsStore) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isReplying else { return }
        guard settings.hasAPIKey else {
            notice = .init(title: "Let’s get set up", message: "Add an OpenRouter API key in Settings before sending your first message.")
            return
        }

        let conversationID = ensureConversation(using: text)
        append(ChatMessage(role: .user, content: text), to: conversationID)
        append(ChatMessage(role: .assistant, content: ""), to: conversationID)
        beginReply(in: conversationID, settings: settings)
    }

    func retry(conversationID: UUID? = nil, settings: SettingsStore) {
        guard !isReplying,
              let conversationID = conversationID ?? selectedConversationID,
              let index = conversations.firstIndex(where: { $0.id == conversationID }),
              replyStates[conversationID]?.isRetryable == true else { return }

        guard let lastMessage = conversations[index].messages.last,
              lastMessage.role == .assistant else { return }
        conversations[index].messages.removeLast()
        conversations[index].updatedAt = .now
        append(ChatMessage(role: .assistant, content: ""), to: conversationID)
        beginReply(in: conversationID, settings: settings)
    }

    func responseState(for conversationID: UUID?) -> ReplyState {
        guard let conversationID else { return .idle }
        return replyStates[conversationID] ?? .idle
    }

    private func beginReply(in conversationID: UUID, settings: SettingsStore) {
        guard !isReplying else { return }
        isReplying = true
        activeConversationID = conversationID
        replyStates[conversationID] = .streaming

        let contextLength = settings.availableModels.first(where: { $0.id == settings.selectedModel })?.contextLength
            ?? ModelOption.starterModels.first(where: { $0.id == settings.selectedModel })?.contextLength
        let maxTokens = min(4_096, max(256, (contextLength ?? 32_768) / 4))
        let messages = conversations
            .first(where: { $0.id == conversationID })
            .map {
                RequestContextBuilder.build(
                    conversation: $0,
                    systemPrompt: settings.systemPrompt,
                    contextLength: contextLength,
                    maximumOutputTokens: maxTokens
                )
            } ?? []
        let model = settings.selectedModel
        let temperature = settings.temperature
        let apiKey = settings.apiKey

        replyTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.client.streamChat(
                    apiKey: apiKey,
                    model: model,
                    messages: messages,
                    temperature: temperature,
                    maxTokens: maxTokens
                ) { token in
                    self.appendToken(token, to: conversationID)
                }
                try Task.checkCancellation()
                self.finishReply(in: conversationID)
            } catch is CancellationError {
                // Cancellation is represented by the explicit cancelled state below.
            } catch {
                if !Task.isCancelled {
                    self.failReply(error, in: conversationID)
                }
            }

            if self.activeConversationID == conversationID {
                self.isReplying = false
                self.activeConversationID = nil
                self.replyTask = nil
            }
        }
    }

    func cancelReply() {
        guard isReplying else { return }
        replyTask?.cancel()
        replyTask = nil
        flushTask?.cancel()
        flushTask = nil
        flushPendingResponse()
        pendingResponseText = ""
        isReplying = false
        if let activeConversationID {
            replyStates[activeConversationID] = .cancelled
        }
        activeConversationID = nil
        save()
    }

    private func ensureConversation(using firstMessage: String) -> UUID {
        if let selectedConversationID { return selectedConversationID }

        let title = firstMessage
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let shortenedTitle = title.count > 44 ? String(title.prefix(44)) + "…" : title
        let conversation = Conversation(title: shortenedTitle.isEmpty ? "Fresh chat" : shortenedTitle)
        conversations.insert(conversation, at: 0)
        selectedConversationID = conversation.id
        save()
        return conversation.id
    }

    private func append(_ message: ChatMessage, to conversationID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[index].messages.append(message)
        conversations[index].updatedAt = .now
        moveToFront(index)
        save()
    }

    private func appendToken(_ token: String, to conversationID: UUID) {
        guard activeConversationID == conversationID else { return }
        pendingResponseText += token
        guard flushTask == nil else { return }
        flushTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(60))
            guard !Task.isCancelled else { return }
            self?.flushPendingResponse()
        }
    }

    private func flushPendingResponse() {
        flushTask = nil
        guard !pendingResponseText.isEmpty,
              let index = conversations.firstIndex(where: { $0.id == activeConversationID }),
              let messageIndex = conversations[index].messages.indices.last,
              conversations[index].messages[messageIndex].role == .assistant else { return }
        conversations[index].messages[messageIndex].content += pendingResponseText
        conversations[index].updatedAt = .now
        pendingResponseText = ""
        moveToFront(index)
    }

    private func finishReply(in conversationID: UUID) {
        flushTask?.cancel()
        flushTask = nil
        flushPendingResponse()
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }),
              let messageIndex = conversations[index].messages.indices.last else { return }
        if conversations[index].messages[messageIndex].content.isEmpty {
            conversations[index].messages[messageIndex].content = "The oven went quiet before a reply arrived. Please try again."
        }
        replyStates[conversationID] = .idle
        save()
    }

    private func failReply(_ error: Error, in conversationID: UUID) {
        flushTask?.cancel()
        flushTask = nil
        flushPendingResponse()
        guard conversations.contains(where: { $0.id == conversationID }) else { return }
        replyStates[conversationID] = .failed(error.localizedDescription)
        save()
    }

    private func moveToFront(_ index: Int) {
        guard index != 0 else { return }
        let conversation = conversations.remove(at: index)
        conversations.insert(conversation, at: 0)
    }

    private func save() {
        do {
            try conversationStore.save(conversations)
        } catch {
            notice = .init(title: "Couldn’t save your chats", message: error.localizedDescription)
        }
    }
}

struct AppNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
