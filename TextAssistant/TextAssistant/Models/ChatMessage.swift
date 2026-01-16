import Foundation
import AppKit

struct Attachment: Identifiable, Equatable {
    let id: UUID
    let type: AttachmentType
    let data: Data
    let filename: String

    enum AttachmentType: Equatable {
        case image
        case pdf
        case text
    }

    var base64String: String {
        data.base64EncodedString()
    }

    var mimeType: String {
        switch type {
        case .image: return "image/png"
        case .pdf: return "application/pdf"
        case .text: return "text/plain"
        }
    }

    var nsImage: NSImage? {
        guard type == .image else { return nil }
        return NSImage(data: data)
    }

    init(id: UUID = UUID(), type: AttachmentType, data: Data, filename: String) {
        self.id = id
        self.type = type
        self.data = data
        self.filename = filename
    }
}

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: Role
    var content: String
    let isSelectedText: Bool
    let timestamp: Date
    var attachments: [Attachment]

    enum Role {
        case user
        case assistant
        case system
    }

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        isSelectedText: Bool = false,
        timestamp: Date = Date(),
        attachments: [Attachment] = []
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.isSelectedText = isSelectedText
        self.timestamp = timestamp
        self.attachments = attachments
    }
}
