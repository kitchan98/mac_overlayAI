import Foundation

actor OpenRouterService {
    static let shared = OpenRouterService()

    private let baseURL = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    private var apiKey: String {
        SecureStorage.shared.getAPIKey() ?? ""
    }

    // Simple text-only message
    struct Message: Codable {
        let role: String
        let content: String
    }

    // Multimodal content types
    struct TextContent: Codable {
        let type: String = "text"
        let text: String
    }

    struct ImageURL: Codable {
        let url: String
    }

    struct ImageContent: Codable {
        let type: String = "image_url"
        let image_url: ImageURL
    }

    enum ContentPart: Codable {
        case text(TextContent)
        case image(ImageContent)

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let content):
                try container.encode(content)
            case .image(let content):
                try container.encode(content)
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let text = try? container.decode(TextContent.self) {
                self = .text(text)
            } else {
                let image = try container.decode(ImageContent.self)
                self = .image(image)
            }
        }
    }

    struct MultimodalMessage: Codable {
        let role: String
        let content: [ContentPart]
    }

    struct ChatRequest: Codable {
        let model: String
        let messages: [Message]
        let stream: Bool
    }

    struct MultimodalChatRequest: Codable {
        let model: String
        let messages: [MultimodalMessage]
        let stream: Bool
    }

    struct StreamChoice: Codable {
        let delta: Delta?
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case delta
            case finishReason = "finish_reason"
        }
    }

    struct Delta: Codable {
        let content: String?
    }

    struct StreamResponse: Codable {
        let choices: [StreamChoice]
    }

    enum APIError: Error, LocalizedError {
        case noAPIKey
        case requestFailed(Int)
        case invalidResponse
        case networkError(Error)

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "No API key configured. Please add your OpenRouter API key in Settings."
            case .requestFailed(let code):
                return "Request failed with status code \(code)"
            case .invalidResponse:
                return "Invalid response from server"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            }
        }
    }

    func streamChat(
        messages: [Message],
        model: String? = nil
    ) async throws -> AsyncThrowingStream<String, Error> {
        var selectedModel = model ?? SecureStorage.shared.getModel().rawValue
        // Append :online suffix for web search if enabled
        if SecureStorage.shared.isWebSearchEnabled() && !selectedModel.hasSuffix(":online") {
            selectedModel += ":online"
        }
        guard !apiKey.isEmpty else {
            throw APIError.noAPIKey
        }

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("TextAssistant/1.0", forHTTPHeaderField: "X-Title")

        let body = ChatRequest(model: selectedModel, messages: messages, stream: true)
        request.httpBody = try JSONEncoder().encode(body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // Read error body for debugging
            var errorBody = ""
            for try await line in bytes.lines {
                errorBody += line
            }
            print("❌ API Error \(httpResponse.statusCode): \(errorBody)")
            print("❌ API Key (first 10 chars): \(String(apiKey.prefix(10)))...")
            print("❌ Model: \(selectedModel)")
            throw APIError.requestFailed(httpResponse.statusCode)
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let data = String(line.dropFirst(6))

                            if data == "[DONE]" {
                                continuation.finish()
                                return
                            }

                            if let chunk = parseSSEChunk(data) {
                                continuation.yield(chunk)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func parseSSEChunk(_ data: String) -> String? {
        guard let jsonData = data.data(using: .utf8) else { return nil }

        do {
            let response = try JSONDecoder().decode(StreamResponse.self, from: jsonData)
            return response.choices.first?.delta?.content
        } catch {
            return nil
        }
    }

    // Multimodal chat with images
    func streamChatWithAttachments(
        messages: [Message],
        attachments: [Attachment],
        model: String? = nil
    ) async throws -> AsyncThrowingStream<String, Error> {
        var selectedModel = model ?? SecureStorage.shared.getModel().rawValue
        // Append :online suffix for web search if enabled
        if SecureStorage.shared.isWebSearchEnabled() && !selectedModel.hasSuffix(":online") {
            selectedModel += ":online"
        }
        guard !apiKey.isEmpty else {
            throw APIError.noAPIKey
        }

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("TextAssistant/1.0", forHTTPHeaderField: "X-Title")

        // Convert messages to multimodal format
        var multimodalMessages: [MultimodalMessage] = []

        for (index, msg) in messages.enumerated() {
            var contentParts: [ContentPart] = []

            // Add text content
            if !msg.content.isEmpty {
                contentParts.append(.text(TextContent(text: msg.content)))
            }

            // Add attachments to the last user message
            if index == messages.count - 1 && msg.role == "user" {
                for attachment in attachments {
                    if attachment.type == .image {
                        let dataURL = "data:\(attachment.mimeType);base64,\(attachment.base64String)"
                        contentParts.append(.image(ImageContent(image_url: ImageURL(url: dataURL))))
                    } else if attachment.type == .text, let textContent = String(data: attachment.data, encoding: .utf8) {
                        contentParts.append(.text(TextContent(text: "File '\(attachment.filename)':\n\(textContent)")))
                    }
                }
            }

            multimodalMessages.append(MultimodalMessage(role: msg.role, content: contentParts))
        }

        let body = MultimodalChatRequest(model: selectedModel, messages: multimodalMessages, stream: true)
        request.httpBody = try JSONEncoder().encode(body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            var errorBody = ""
            for try await line in bytes.lines {
                errorBody += line
            }
            print("❌ API Error \(httpResponse.statusCode): \(errorBody)")
            print("❌ Model: \(selectedModel)")
            throw APIError.requestFailed(httpResponse.statusCode)
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let data = String(line.dropFirst(6))

                            if data == "[DONE]" {
                                continuation.finish()
                                return
                            }

                            if let chunk = parseSSEChunk(data) {
                                continuation.yield(chunk)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
