import Foundation

protocol ConversationPersisting {
    func load() throws -> [Conversation]
    func save(_ conversations: [Conversation]) throws
}

struct ConversationStore: ConversationPersisting {
    enum StoreError: LocalizedError {
        case unavailable
        case encodingFailed
        case writeFailed(Error)

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "BiscuitAI could not locate its application-support folder."
            case .encodingFailed:
                return "BiscuitAI could not encode the conversation history."
            case .writeFailed(let error):
                return "BiscuitAI could not save conversation history: \(error.localizedDescription)"
            }
        }
    }

    private let fileURL: URL

    init(fileManager: FileManager = .default) {
        let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        self.fileURL = supportURL?
            .appendingPathComponent("BiscuitAI", isDirectory: true)
            .appendingPathComponent("conversations.json")
            ?? URL(fileURLWithPath: "/invalid/BiscuitAI/conversations.json")
    }

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func load() throws -> [Conversation] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([Conversation].self, from: data)
    }

    func save(_ conversations: [Conversation]) throws {
        guard fileURL.path != "/invalid/BiscuitAI/conversations.json" else {
            throw StoreError.unavailable
        }

        let directoryURL = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(conversations)
            try data.write(to: fileURL, options: [.atomic])
        } catch let error as StoreError {
            throw error
        } catch {
            throw StoreError.writeFailed(error)
        }
    }
}
