import Foundation
import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var pendingAttachments: [Attachment] = []
    @Published var isFetchingTranscript = false

    private var conversationHistory: [OpenRouterService.Message] = []
    private var selectedText: String?
    private var youtubeContext: YouTubeService.VideoInfo?

    func startConversation(with text: String?) {
        selectedText = text
        messages = []
        conversationHistory = []
        error = nil
        youtubeContext = nil

        // Check if the selected text contains a YouTube URL
        if let text = text, !text.isEmpty {
            Task {
                if let videoId = await YouTubeService.shared.detectYouTubeURL(in: text) {
                    // Automatically fetch YouTube transcript
                    await handleYouTubeFromSelection(text: text, videoId: videoId)
                    return
                }

                // Not a YouTube URL - proceed with normal conversation
                await setupNormalConversation(with: text)
            }
        } else {
            // No selected text - general assistant mode
            setupEmptyConversation()
        }
    }

    private func setupEmptyConversation() {
        var systemPrompt = "You are a helpful assistant. Be concise and helpful in your responses."

        if let personalContext = SecureStorage.shared.getPersonalContext(), !personalContext.isEmpty {
            systemPrompt += "\n\nHere is some information about the user:\n\(personalContext)"
        }

        conversationHistory.append(
            OpenRouterService.Message(role: "system", content: systemPrompt)
        )
    }

    private func setupNormalConversation(with text: String) async {
        var systemPrompt = "You are a helpful assistant. Be concise and helpful in your responses."

        if let personalContext = SecureStorage.shared.getPersonalContext(), !personalContext.isEmpty {
            systemPrompt += "\n\nHere is some information about the user:\n\(personalContext)"
        }

        systemPrompt += """

        The user has selected some text and will ask you questions about it. Here is the selected text:

        ---
        \(text)
        ---
        """

        conversationHistory.append(
            OpenRouterService.Message(role: "system", content: systemPrompt)
        )

        messages.append(
            ChatMessage(role: .user, content: text, isSelectedText: true)
        )
    }

    private func handleYouTubeFromSelection(text: String, videoId: String) async {
        // Show the YouTube URL as selected text
        messages.append(
            ChatMessage(role: .user, content: text, isSelectedText: true)
        )

        // Show fetching status
        isFetchingTranscript = true
        let statusMessageId = UUID()
        messages.append(ChatMessage(id: statusMessageId, role: .assistant, content: "Fetching YouTube transcript..."))

        do {
            let videoInfo = try await YouTubeService.shared.fetchVideoInfo(videoId: videoId)
            youtubeContext = videoInfo

            // Remove status message
            messages.removeAll { $0.id == statusMessageId }
            isFetchingTranscript = false

            // Build system prompt with transcript
            var systemPrompt = """
            You are a helpful assistant analyzing a YouTube video. The user has shared a YouTube video with you.

            Video Title: \(videoInfo.title)
            Video ID: \(videoInfo.videoId)

            Here is the complete transcript of the video:

            ---
            \(videoInfo.transcript)
            ---

            Please provide a detailed summary of this video. After the summary, the user may ask follow-up questions about the content.
            """

            if let personalContext = SecureStorage.shared.getPersonalContext(), !personalContext.isEmpty {
                systemPrompt += "\n\nHere is some information about the user:\n\(personalContext)"
            }

            conversationHistory = [
                OpenRouterService.Message(role: "system", content: systemPrompt)
            ]

            let userRequest = "Please summarize this YouTube video: \(videoInfo.title)"
            conversationHistory.append(
                OpenRouterService.Message(role: "user", content: userRequest)
            )

            await streamResponse()

        } catch {
            messages.removeAll { $0.id == statusMessageId }
            isFetchingTranscript = false

            let errorMessage: String
            if let ytError = error as? YouTubeService.YouTubeError {
                errorMessage = ytError.errorDescription ?? "Unknown error"
            } else {
                errorMessage = error.localizedDescription
            }

            messages.append(
                ChatMessage(role: .assistant, content: "Could not fetch YouTube transcript: \(errorMessage)\n\nPlease make sure:\n- The video has subtitles/captions available\n- yt-dlp is installed (brew install yt-dlp)\n- The URL is a valid YouTube video")
            )
        }
    }

    func addAttachment(_ attachment: Attachment) {
        pendingAttachments.append(attachment)
    }

    func removeAttachment(_ attachment: Attachment) {
        pendingAttachments.removeAll { $0.id == attachment.id }
    }

    func sendMessage(_ text: String) async {
        let userMessage = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachments = pendingAttachments

        // Allow sending with just attachments (no text required)
        guard !userMessage.isEmpty || !attachments.isEmpty else { return }

        // Clear pending attachments
        pendingAttachments = []

        // Check for YouTube URLs in the message
        if let videoId = await YouTubeService.shared.detectYouTubeURL(in: userMessage) {
            await handleYouTubeMessage(userMessage: userMessage, videoId: videoId, attachments: attachments)
            return
        }

        // Build display text
        var displayText = userMessage
        if !attachments.isEmpty {
            let attachmentNames = attachments.map { $0.filename }.joined(separator: ", ")
            if displayText.isEmpty {
                displayText = "📎 \(attachmentNames)"
            } else {
                displayText += "\n📎 \(attachmentNames)"
            }
        }

        // Add user message
        conversationHistory.append(
            OpenRouterService.Message(role: "user", content: userMessage.isEmpty ? "Please analyze the attached file(s)." : userMessage)
        )
        messages.append(
            ChatMessage(role: .user, content: displayText, attachments: attachments)
        )

        await streamResponse(with: attachments)
    }

    private func handleYouTubeMessage(userMessage: String, videoId: String, attachments: [Attachment]) async {
        // Show user message with YouTube indicator
        messages.append(
            ChatMessage(role: .user, content: userMessage, attachments: attachments)
        )

        // Show fetching status
        isFetchingTranscript = true
        let statusMessageId = UUID()
        messages.append(ChatMessage(id: statusMessageId, role: .assistant, content: "Fetching YouTube transcript..."))

        do {
            // Fetch video info and transcript
            let videoInfo = try await YouTubeService.shared.fetchVideoInfo(videoId: videoId)
            youtubeContext = videoInfo

            // Remove status message
            messages.removeAll { $0.id == statusMessageId }
            isFetchingTranscript = false

            // Build system prompt with transcript context
            var systemPrompt = """
            You are a helpful assistant analyzing a YouTube video. The user has shared a YouTube video with you.

            Video Title: \(videoInfo.title)
            Video ID: \(videoInfo.videoId)

            Here is the complete transcript of the video:

            ---
            \(videoInfo.transcript)
            ---

            Please provide a detailed summary of this video. After the summary, the user may ask follow-up questions about the content.
            """

            // Add personal context if available
            if let personalContext = SecureStorage.shared.getPersonalContext(), !personalContext.isEmpty {
                systemPrompt += "\n\nHere is some information about the user:\n\(personalContext)"
            }

            // Reset conversation history with YouTube context
            conversationHistory = [
                OpenRouterService.Message(role: "system", content: systemPrompt)
            ]

            // Add the user's request to conversation
            let userRequest = "Please summarize this YouTube video: \(videoInfo.title)"
            conversationHistory.append(
                OpenRouterService.Message(role: "user", content: userRequest)
            )

            // Stream the summary response
            await streamResponse(with: attachments)

        } catch {
            // Remove status message and show error
            messages.removeAll { $0.id == statusMessageId }
            isFetchingTranscript = false

            let errorMessage: String
            if let ytError = error as? YouTubeService.YouTubeError {
                errorMessage = ytError.errorDescription ?? "Unknown error"
            } else {
                errorMessage = error.localizedDescription
            }

            messages.append(
                ChatMessage(role: .assistant, content: "Could not fetch YouTube transcript: \(errorMessage)\n\nPlease make sure:\n- The video has subtitles/captions available\n- yt-dlp is installed (brew install yt-dlp)\n- The URL is a valid YouTube video")
            )
        }
    }

    private func streamResponse(with attachments: [Attachment] = []) async {
        isLoading = true
        error = nil

        // Create placeholder for assistant message
        let messageId = UUID()
        messages.append(ChatMessage(id: messageId, role: .assistant, content: ""))

        var fullResponse = ""

        do {
            let stream: AsyncThrowingStream<String, Error>

            if attachments.isEmpty {
                stream = try await OpenRouterService.shared.streamChat(
                    messages: conversationHistory
                )
            } else {
                stream = try await OpenRouterService.shared.streamChatWithAttachments(
                    messages: conversationHistory,
                    attachments: attachments
                )
            }

            for try await chunk in stream {
                fullResponse += chunk
                // Update the message and force UI refresh
                if let index = messages.firstIndex(where: { $0.id == messageId }) {
                    messages[index] = ChatMessage(id: messageId, role: .assistant, content: fullResponse)
                }
            }

            // Add completed response to conversation history
            conversationHistory.append(
                OpenRouterService.Message(
                    role: "assistant",
                    content: fullResponse
                )
            )
        } catch {
            self.error = error.localizedDescription
            if let index = messages.firstIndex(where: { $0.id == messageId }) {
                messages[index] = ChatMessage(id: messageId, role: .assistant, content: "Error: \(error.localizedDescription)")
            }
        }

        isLoading = false
    }

    func clearConversation() {
        messages = []
        conversationHistory = []
        selectedText = ""
        error = nil
        youtubeContext = nil
        isFetchingTranscript = false
    }
}
