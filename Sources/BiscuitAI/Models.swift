import Foundation

enum ChatRole: String, Codable, CaseIterable {
    case system
    case user
    case assistant
}

enum AppAppearance: String, Codable, CaseIterable, Identifiable {
    case warmLight
    case dark

    var id: String { rawValue }
    var title: String { self == .warmLight ? "Light" : "Dark" }
    var symbolName: String { self == .warmLight ? "sun.max.fill" : "moon.stars.fill" }
}

struct APIKeyProfile: Identifiable, Codable, Hashable {
    let id: UUID
    var label: String
    let keychainAccount: String
    var selectedModel: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        label: String,
        keychainAccount: String,
        selectedModel: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.label = label
        self.keychainAccount = keychainAccount
        self.selectedModel = selectedModel
        self.createdAt = createdAt
    }
}

struct ChatMessage: Identifiable, Codable, Hashable {
    let id: UUID
    let role: ChatRole
    var content: String
    let createdAt: Date

    init(id: UUID = UUID(), role: ChatRole, content: String, createdAt: Date = .now) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

struct Conversation: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String, messages: [ChatMessage] = [], createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct ModelOption: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String?
    let contextLength: Int?
    let inputModalities: [String]
    let isFree: Bool

    init(
        id: String,
        name: String? = nil,
        description: String? = nil,
        contextLength: Int? = nil,
        inputModalities: [String] = ["text"],
        isFree: Bool = false
    ) {
        self.id = id
        self.name = name ?? id
        self.description = description
        self.contextLength = contextLength
        self.inputModalities = inputModalities
        self.isFree = isFree
    }

    static let starterModels: [ModelOption] = [
        .init(id: "openai/gpt-5.2", name: "OpenAI: GPT-5.2", description: "General-purpose chat and reasoning"),
        .init(id: "google/gemini-3.7-flash", name: "Google: Gemini 3.7 Flash", description: "Fast multimodal assistance", contextLength: 1_048_576, inputModalities: ["text", "image", "file", "audio", "video"]),
        .init(id: "x-ai/grok-4.6", name: "SpaceXAI: Grok 4.6", description: "Frontier coding, knowledge work, and STEM", contextLength: 500_000, inputModalities: ["text", "image", "file"]),
        .init(id: "deepseek/deepseek-v4-pro-0813", name: "DeepSeek: DeepSeek V4 Pro", description: "Large-scale reasoning and development", contextLength: 1_048_576),
        .init(id: "qwen/qwen3.8-27b", name: "Qwen: Qwen3.8 27B", description: "Open-weight vision and text workflows", contextLength: 262_144, inputModalities: ["text", "image", "video"]),
        .init(id: "nvidia/nemotron-3.5-lightning:free", name: "NVIDIA: Nemotron 3.5 Lightning (free)", description: "Fast open-weight model", contextLength: 1_000_000, isFree: true)
    ]
}

struct OpenRouterRequestMessage: Codable {
    let role: String
    let content: String
}

struct OpenRouterChatRequest: Codable {
    let model: String
    let messages: [OpenRouterRequestMessage]
    let stream: Bool
    let temperature: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model, messages, stream, temperature
        case maxTokens = "max_tokens"
    }
}

struct StreamChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable {
            let content: String?
        }
        let delta: Delta
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case delta
            case finishReason = "finish_reason"
        }
    }

    let choices: [Choice]
    let error: OpenRouterAPIError?
}

struct OpenRouterAPIError: Decodable, LocalizedError {
    let code: String?
    let message: String

    var errorDescription: String? { message }

    enum CodingKeys: String, CodingKey {
        case code, message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        message = try container.decode(String.self, forKey: .message)

        if let stringCode = try? container.decode(String.self, forKey: .code) {
            code = stringCode
        } else if let integerCode = try? container.decode(Int.self, forKey: .code) {
            code = String(integerCode)
        } else {
            code = nil
        }
    }
}

struct OpenRouterErrorResponse: Decodable {
    let error: OpenRouterAPIError
}

struct ModelsResponse: Decodable {
    struct RemoteModel: Decodable {
        struct Architecture: Decodable {
            let inputModalities: [String]?

            enum CodingKeys: String, CodingKey {
                case inputModalities = "input_modalities"
            }
        }

        struct Pricing: Decodable {
            let prompt: String?
            let completion: String?
        }

        let id: String
        let name: String?
        let description: String?
        let contextLength: Int?
        let architecture: Architecture?
        let pricing: Pricing?

        enum CodingKeys: String, CodingKey {
            case id, name, description, architecture, pricing
            case contextLength = "context_length"
        }

        var asModelOption: ModelOption {
            let promptIsFree = pricing?.prompt == "0"
            let completionIsFree = pricing?.completion == "0"
            return ModelOption(
                id: id,
                name: name,
                description: description,
                contextLength: contextLength,
                inputModalities: architecture?.inputModalities ?? ["text"],
                isFree: promptIsFree && completionIsFree
            )
        }
    }

    let data: [RemoteModel]
}
