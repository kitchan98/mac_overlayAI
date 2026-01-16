import SwiftUI
import UniformTypeIdentifiers

struct OverlayView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var inputText: String
    @State private var isDropTargeted = false
    @State private var webSearchEnabled: Bool = SecureStorage.shared.isWebSearchEnabled()
    @State private var isInputHovered = false

    let onClose: () -> Void

    init(viewModel: ChatViewModel, initialText: String? = nil, onClose: @escaping () -> Void) {
        self.viewModel = viewModel
        self._inputText = State(initialValue: initialText ?? "")
        self.onClose = onClose
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // Messages or empty state
                if viewModel.messages.isEmpty {
                    emptyStateView
                } else {
                    messagesView
                }

                // Pending attachments
                if !viewModel.pendingAttachments.isEmpty {
                    pendingAttachmentsView
                        .padding(.bottom, 8)
                }

                // Input bar at bottom
                inputBar
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }

            // Floating close button
            closeButton
                .padding(8)
        }
        .frame(minWidth: 420, maxWidth: 600)
        .frame(minHeight: viewModel.messages.isEmpty ? 120 : 280)
        .background(VisualEffectBlur())
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .overlay(dropOverlay)
        .onDrop(of: [.fileURL, .image, .png, .jpeg, .pdf, .plainText], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("Ask anything")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.secondary.opacity(0.6))
            Text("Press Enter to send")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.4))
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    // MARK: - Messages View
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Typing indicator when loading
                    if viewModel.isLoading {
                        TypingIndicator()
                            .padding(.leading, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 40)
                .padding(.bottom, 12)
            }
            .onChange(of: viewModel.messages.count) { _ in
                if let lastMessage = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.isLoading) { _ in
                if let lastMessage = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Close Button
    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 20, height: 20)
                .background(Color.secondary.opacity(0.15))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Close (Esc)")
    }

    @ViewBuilder
    private var dropOverlay: some View {
        if isDropTargeted {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue, lineWidth: 2)
                )
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 32))
                        Text("Drop to attach")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.blue)
                )
        }
    }

    private var pendingAttachmentsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.pendingAttachments) { attachment in
                    attachmentPreview(attachment)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func attachmentPreview(_ attachment: Attachment) -> some View {
        HStack(spacing: 6) {
            if attachment.type == .image, let image = attachment.nsImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: attachment.type == .pdf ? "doc.fill" : "doc.text.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
            }

            Text(attachment.filename)
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundColor(.primary.opacity(0.8))

            Button(action: {
                withAnimation(.easeOut(duration: 0.15)) {
                    viewModel.removeAttachment(attachment)
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 14, height: 14)
                    .background(Color.secondary.opacity(0.2))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 6)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var placeholderText: String {
        viewModel.messages.isEmpty ? "Ask anything..." : "Ask a follow-up..."
    }

    private var isInputDisabled: Bool {
        viewModel.isLoading || viewModel.isFetchingTranscript
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            // Text input (expandable)
            ZStack(alignment: .leading) {
                if inputText.isEmpty {
                    Text(placeholderText)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(.leading, 4)
                }

                ChatTextEditor(text: $inputText, isDisabled: isInputDisabled, onSubmit: sendMessage)
                    .frame(minHeight: 18, maxHeight: 80)
            }

            // Web search toggle - simple icon
            Button(action: {
                webSearchEnabled.toggle()
                SecureStorage.shared.saveWebSearchEnabled(webSearchEnabled)
            }) {
                Image(systemName: "globe")
                    .font(.system(size: 14))
                    .foregroundColor(webSearchEnabled ? .blue : .secondary.opacity(0.4))
            }
            .buttonStyle(.plain)
            .help(webSearchEnabled ? "Web search enabled" : "Enable web search")

            // Send button
            Button(action: sendMessage) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(inputText.isEmpty ? .secondary.opacity(0.5) : .white)
                    .frame(width: 22, height: 22)
                    .background(inputText.isEmpty ? Color.secondary.opacity(0.15) : Color.blue)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(inputText.isEmpty || isInputDisabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.primary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.primary.opacity(isInputHovered ? 0.15 : 0.08), lineWidth: 1)
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isInputHovered = hovering
            }
        }
    }

    private func sendMessage() {
        guard (!inputText.isEmpty || !viewModel.pendingAttachments.isEmpty), !isInputDisabled else { return }

        let text = inputText
        inputText = ""

        Task {
            await viewModel.sendMessage(text)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            // Handle image types
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                    if let data = data {
                        // Convert to PNG for consistency
                        if let nsImage = NSImage(data: data),
                           let pngData = nsImage.pngData() {
                            let attachment = Attachment(
                                type: .image,
                                data: pngData,
                                filename: "image.png"
                            )
                            DispatchQueue.main.async {
                                viewModel.addAttachment(attachment)
                            }
                        }
                    }
                }
            }
            // Handle file URLs
            else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        self.loadFile(from: url)
                    }
                }
            }
        }
    }

    private func loadFile(from url: URL) {
        let filename = url.lastPathComponent
        let ext = url.pathExtension.lowercased()

        guard let data = try? Data(contentsOf: url) else { return }

        let attachmentType: Attachment.AttachmentType
        var processedData = data

        switch ext {
        case "png", "jpg", "jpeg", "gif", "webp", "heic":
            attachmentType = .image
            // Convert to PNG
            if let nsImage = NSImage(data: data), let pngData = nsImage.pngData() {
                processedData = pngData
            }
        case "pdf":
            attachmentType = .pdf
        case "txt", "md", "json", "swift", "py", "js", "ts", "html", "css", "xml", "yaml", "yml", "sh", "rb", "go", "rs", "c", "cpp", "h", "java", "kt":
            attachmentType = .text
        default:
            // Try to read as text
            if String(data: data, encoding: .utf8) != nil {
                attachmentType = .text
            } else {
                return // Unsupported file type
            }
        }

        let attachment = Attachment(
            type: attachmentType,
            data: processedData,
            filename: filename
        )

        DispatchQueue.main.async {
            viewModel.addAttachment(attachment)
        }
    }
}

extension NSImage {
    func pngData() -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct ChatTextEditor: NSViewRepresentable {
    @Binding var text: String
    var isDisabled: Bool
    var onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> ChatTextContainerView {
        let containerView = ChatTextContainerView()
        containerView.textView.delegate = context.coordinator
        containerView.textView.isEditable = !isDisabled
        containerView.textView.onSubmit = onSubmit

        // Auto-focus
        DispatchQueue.main.async {
            containerView.textView.window?.makeFirstResponder(containerView.textView)
        }

        return containerView
    }

    func updateNSView(_ containerView: ChatTextContainerView, context: Context) {
        if containerView.textView.string != text {
            containerView.textView.string = text
            containerView.invalidateIntrinsicContentSize()
        }
        containerView.textView.isEditable = !isDisabled
        containerView.textView.onSubmit = onSubmit
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ChatTextEditor

        init(_ parent: ChatTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            if let container = textView.superview?.superview as? ChatTextContainerView {
                container.invalidateIntrinsicContentSize()
            }
        }
    }
}

class ChatTextContainerView: NSView {
    let scrollView: NSScrollView
    let textView: ChatNSTextView

    override init(frame: NSRect) {
        scrollView = NSScrollView()
        textView = ChatNSTextView()

        super.init(frame: frame)

        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 0, height: 2)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0

        scrollView.documentView = textView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return NSSize(width: NSView.noIntrinsicMetric, height: 20)
        }

        layoutManager.ensureLayout(for: textContainer)
        let rect = layoutManager.usedRect(for: textContainer)
        let height = max(20, min(rect.height + textView.textContainerInset.height * 2, 100))
        return NSSize(width: NSView.noIntrinsicMetric, height: height)
    }
}

class ChatNSTextView: NSTextView {
    var onSubmit: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 && !event.modifierFlags.contains(.shift) {
            onSubmit?()
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var animationPhase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                    .opacity(animationPhase == index ? 1 : 0.5)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: false)) {
                startAnimation()
            }
        }
    }

    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}
