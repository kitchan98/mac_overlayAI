import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    @State private var showCopied = false
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                if message.isSelectedText {
                    Label("Selected Text", systemImage: "text.quote")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary.opacity(0.7))
                }

                // Show image attachments
                if !message.attachments.isEmpty {
                    attachmentsView
                }

                if message.role == .assistant {
                    // Clean markdown for assistant
                    MarkdownContentView(content: message.content)
                        .textSelection(.enabled)
                } else {
                    // User message bubble
                    Text(message.content)
                        .font(.system(size: 14))
                        .textSelection(.enabled)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Copy button - show on hover
                if !message.content.isEmpty && (isHovered || showCopied) {
                    Button(action: copyToClipboard) {
                        HStack(spacing: 3) {
                            Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 9, weight: .medium))
                            Text(showCopied ? "Copied" : "Copy")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(showCopied ? .green : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)
        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopied = false
        }
    }

    @ViewBuilder
    private var attachmentsView: some View {
        VStack(alignment: .trailing, spacing: 6) {
            ForEach(message.attachments) { attachment in
                if attachment.type == .image, let image = attachment.nsImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 220, maxHeight: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: attachment.type == .pdf ? "doc.fill" : "doc.text.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                        Text(attachment.filename)
                            .font(.system(size: 12))
                            .foregroundColor(.primary.opacity(0.8))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

}

// MARK: - Markdown Content View with Table Support
struct MarkdownContentView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parseContent().enumerated()), id: \.offset) { _, block in
                switch block {
                case .text(let text):
                    Text(parseInlineMarkdown(text))
                        .textSelection(.enabled)
                case .table(let table):
                    TableView(table: table)
                case .codeBlock(let code, let language):
                    CodeBlockView(code: code, language: language)
                }
            }
        }
    }

    private func parseContent() -> [ContentBlock] {
        var blocks: [ContentBlock] = []
        var currentText = ""
        var inCodeBlock = false
        var codeBlockContent = ""
        var codeLanguage: String? = nil
        var inTable = false
        var tableLines: [String] = []

        let lines = content.components(separatedBy: "\n")

        for line in lines {
            // Check for code block
            if line.hasPrefix("```") {
                if inCodeBlock {
                    // End code block
                    if !currentText.isEmpty {
                        blocks.append(.text(currentText.trimmingCharacters(in: .whitespacesAndNewlines)))
                        currentText = ""
                    }
                    blocks.append(.codeBlock(codeBlockContent.trimmingCharacters(in: .newlines), codeLanguage))
                    codeBlockContent = ""
                    codeLanguage = nil
                    inCodeBlock = false
                } else {
                    // Start code block
                    if !currentText.isEmpty {
                        blocks.append(.text(currentText.trimmingCharacters(in: .whitespacesAndNewlines)))
                        currentText = ""
                    }
                    inCodeBlock = true
                    let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    codeLanguage = lang.isEmpty ? nil : lang
                }
                continue
            }

            if inCodeBlock {
                codeBlockContent += (codeBlockContent.isEmpty ? "" : "\n") + line
                continue
            }

            // Check for table row
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.hasPrefix("|") && trimmedLine.hasSuffix("|") {
                if !inTable {
                    // Start table
                    if !currentText.isEmpty {
                        blocks.append(.text(currentText.trimmingCharacters(in: .whitespacesAndNewlines)))
                        currentText = ""
                    }
                    inTable = true
                }
                tableLines.append(line)
            } else {
                if inTable {
                    // End table
                    if let table = parseTable(tableLines) {
                        blocks.append(.table(table))
                    }
                    tableLines = []
                    inTable = false
                }
                currentText += (currentText.isEmpty ? "" : "\n") + line
            }
        }

        // Handle remaining content
        if inTable && !tableLines.isEmpty {
            if let table = parseTable(tableLines) {
                blocks.append(.table(table))
            }
        } else if !currentText.isEmpty {
            blocks.append(.text(currentText.trimmingCharacters(in: .whitespacesAndNewlines)))
        }

        return blocks
    }

    private func parseTable(_ lines: [String]) -> ParsedTable? {
        guard lines.count >= 2 else { return nil }

        var rows: [[String]] = []
        var separatorIndex: Int? = nil

        for (index, line) in lines.enumerated() {
            let cells = line
                .trimmingCharacters(in: .whitespaces)
                .dropFirst()  // Remove leading |
                .dropLast()   // Remove trailing |
                .components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }

            // Check if this is a separator row (contains only -, :, and spaces)
            let isSeparator = cells.allSatisfy { cell in
                cell.allSatisfy { $0 == "-" || $0 == ":" || $0 == " " } && cell.contains("-")
            }

            if isSeparator {
                separatorIndex = index
            } else {
                rows.append(cells)
            }
        }

        guard !rows.isEmpty else { return nil }

        let headers = separatorIndex == 1 ? rows.first : nil
        let dataRows = separatorIndex == 1 ? Array(rows.dropFirst()) : rows

        return ParsedTable(headers: headers, rows: dataRows)
    }

    private func parseInlineMarkdown(_ text: String) -> AttributedString {
        if let attributed = try? AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return attributed
        }
        return AttributedString(text)
    }
}

enum ContentBlock {
    case text(String)
    case table(ParsedTable)
    case codeBlock(String, String?)
}

struct ParsedTable {
    let headers: [String]?
    let rows: [[String]]
}

struct TableView: View {
    let table: ParsedTable

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            if let headers = table.headers {
                HStack(spacing: 0) {
                    ForEach(Array(headers.enumerated()), id: \.offset) { index, header in
                        Text(header)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if index < headers.count - 1 {
                            Rectangle()
                                .fill(Color.primary.opacity(0.1))
                                .frame(width: 1)
                        }
                    }
                }
                .background(Color.primary.opacity(0.06))
            }

            // Data rows
            ForEach(Array(table.rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { cellIndex, cell in
                        Text(cell)
                            .font(.system(size: 12))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if cellIndex < row.count - 1 {
                            Rectangle()
                                .fill(Color.primary.opacity(0.08))
                                .frame(width: 1)
                        }
                    }
                }
                .background(rowIndex % 2 == 1 ? Color.primary.opacity(0.02) : Color.clear)

                if rowIndex < table.rows.count - 1 {
                    Rectangle()
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 1)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}

struct CodeBlockView: View {
    let code: String
    let language: String?
    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with language and copy button
            HStack {
                Text(language ?? "code")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: copyCode) {
                    HStack(spacing: 3) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9))
                        Text(isCopied ? "Copied" : "Copy")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(isCopied ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.08))

            // Code content
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    private func copyCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isCopied = false
        }
    }
}
