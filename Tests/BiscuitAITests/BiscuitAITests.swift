import Foundation
import XCTest
@testable import BiscuitAI

final class BiscuitAITests: XCTestCase {
    func testConversationStoreRoundTripsAtomically() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BiscuitAITests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("conversations.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = ConversationStore(fileURL: fileURL)
        let original = Conversation(
            title: "Test chat",
            messages: [ChatMessage(role: .user, content: "Hello Biscuit")]
        )

        try store.save([original])
        XCTAssertEqual(try store.load(), [original])
    }

    func testMissingConversationStoreLoadsAsEmpty() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("BiscuitAI-missing-\(UUID().uuidString).json")
        XCTAssertEqual(try ConversationStore(fileURL: fileURL).load(), [])
    }

    func testContextBuilderKeepsSystemPromptAndNewestMessages() {
        let conversation = Conversation(
            title: "Long chat",
            messages: [
                ChatMessage(role: .user, content: String(repeating: "old ", count: 1_500)),
                ChatMessage(role: .assistant, content: "old answer"),
                ChatMessage(role: .user, content: "Newest question")
            ]
        )

        let messages = RequestContextBuilder.build(
            conversation: conversation,
            systemPrompt: "Be helpful.",
            contextLength: 256,
            maximumOutputTokens: 128
        )

        XCTAssertEqual(messages.first?.role, "system")
        XCTAssertEqual(messages.first?.content, "Be helpful.")
        XCTAssertEqual(messages.last?.content, "Newest question")
        XCTAssertFalse(messages.contains(where: { $0.content.count > 100 }))
    }

    func testOpenRouterErrorDecodesNumericAndStringCodes() throws {
        let numeric = try JSONDecoder().decode(
            OpenRouterErrorResponse.self,
            from: Data(#"{"error":{"code":401,"message":"Invalid key"}}"#.utf8)
        )
        let string = try JSONDecoder().decode(
            OpenRouterErrorResponse.self,
            from: Data(#"{"error":{"code":"server_error","message":"Provider failed"}}"#.utf8)
        )

        XCTAssertEqual(numeric.error.code, "401")
        XCTAssertEqual(string.error.code, "server_error")
    }

    func testGeneratedImageMessageRoundTrips() throws {
        let imageData = Data([0, 1, 2, 3, 4])
        let original = ChatMessage(
            role: .assistant,
            content: "Generated image",
            imageData: imageData,
            imageMimeType: "image/png"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: encoded)

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.imageData, imageData)
        XCTAssertEqual(decoded.imageMimeType, "image/png")
    }

    func testImageResponseDecodesBase64Payload() throws {
        let response = try JSONDecoder().decode(
            OpenRouterImageResponse.self,
            from: Data(#"{"data":[{"b64_json":"AAEC","media_type":"image/png"}]}"#.utf8)
        )

        XCTAssertEqual(response.data.count, 1)
        XCTAssertEqual(Data(base64Encoded: response.data[0].b64JSON), Data([0, 1, 2]))
        XCTAssertEqual(response.data[0].mediaType, "image/png")
    }
}
