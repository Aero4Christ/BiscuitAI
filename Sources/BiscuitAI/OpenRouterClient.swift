import Foundation

@MainActor
protocol OpenRouterServicing {
    func fetchModels(apiKey: String) async throws -> [ModelOption]
    func streamChat(
        apiKey: String,
        model: String,
        messages: [OpenRouterRequestMessage],
        temperature: Double,
        maxTokens: Int,
        onToken: @escaping (String) -> Void
    ) async throws
}

struct OpenRouterClient: OpenRouterServicing {
    private static let chatURL = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    private static let modelsURL = URL(string: "https://openrouter.ai/api/v1/models")!

    func fetchModels(apiKey: String) async throws -> [ModelOption] {
        var request = URLRequest(url: Self.modelsURL)
        request.timeoutInterval = 30
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("BiscuitAI", forHTTPHeaderField: "X-OpenRouter-Title")

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response, data: data)

        let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
        return decoded.data
            .map { $0.asModelOption }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func streamChat(
        apiKey: String,
        model: String,
        messages: [OpenRouterRequestMessage],
        temperature: Double,
        maxTokens: Int,
        onToken: @escaping (String) -> Void
    ) async throws {
        let payload = OpenRouterChatRequest(
            model: model,
            messages: messages,
            stream: true,
            temperature: temperature,
            maxTokens: maxTokens
        )

        var request = URLRequest(url: Self.chatURL)
        request.timeoutInterval = 120
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("BiscuitAI", forHTTPHeaderField: "X-OpenRouter-Title")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(payload)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OpenRouterError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            var body = Data()
            for try await line in bytes.lines {
                body.append(contentsOf: line.utf8)
                body.append(10)
            }
            throw Self.makeHTTPError(statusCode: http.statusCode, data: body)
        }

        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let dataString = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            if dataString == "[DONE]" { break }
            guard let data = dataString.data(using: .utf8) else { continue }
            guard let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data) else { continue }
            if let error = chunk.error {
                throw OpenRouterError.requestFailed(error.message)
            }
            for choice in chunk.choices {
                if choice.finishReason == "error" {
                    throw OpenRouterError.requestFailed("OpenRouter ended the response because the provider reported an error.")
                }
                if let content = choice.delta.content, !content.isEmpty {
                    onToken(content)
                }
            }
        }
    }

    private static func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw OpenRouterError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            throw makeHTTPError(statusCode: http.statusCode, data: data)
        }
    }

    private static func makeHTTPError(statusCode: Int, data: Data) -> OpenRouterError {
        if let response = try? JSONDecoder().decode(OpenRouterErrorResponse.self, from: data) {
            return .requestFailed(response.error.message)
        }
        let detail = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return .requestFailed(detail?.isEmpty == false ? detail! : "OpenRouter returned HTTP \(statusCode).")
    }
}

enum OpenRouterError: LocalizedError {
    case invalidResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server sent an invalid response."
        case .requestFailed(let message):
            return message
        }
    }
}
