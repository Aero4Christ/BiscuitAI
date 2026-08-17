import Foundation

struct RequestContextBuilder {
    static func build(
        conversation: Conversation,
        systemPrompt: String,
        contextLength: Int?,
        maximumOutputTokens: Int
    ) -> [OpenRouterRequestMessage] {
        let maxPromptCharacters = max(
            ((contextLength ?? 32_768) - maximumOutputTokens) * 4,
            4_096
        )
        let systemMessage = OpenRouterRequestMessage(role: "system", content: systemPrompt)
        var requestMessages = [systemMessage]
        var usedCharacters = systemPrompt.utf8.count

        for message in conversation.messages.reversed() where !message.content.isEmpty {
            let messageCharacters = message.content.utf8.count + 32
            guard usedCharacters + messageCharacters <= maxPromptCharacters else { break }
            requestMessages.insert(
                OpenRouterRequestMessage(role: message.role.rawValue, content: message.content),
                at: 1
            )
            usedCharacters += messageCharacters
        }
        return requestMessages
    }
}
