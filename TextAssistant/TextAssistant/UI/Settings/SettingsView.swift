import SwiftUI

struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var showAPIKey = false
    @State private var isSaved = false
    @State private var selectedModel: LLMModel = .geminiFlash
    @State private var personalContext: String = ""
    @State private var isContextSaved = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("OpenRouter API Key")
                        .font(.headline)

                    HStack {
                        if showAPIKey {
                            TextField("sk-or-...", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("sk-or-...", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                        }

                        Button(action: { showAPIKey.toggle() }) {
                            Image(systemName: showAPIKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                    }

                    HStack {
                        Button("Save") {
                            saveAPIKey()
                        }
                        .disabled(apiKey.isEmpty)

                        if isSaved {
                            Text("Saved!")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }

                        Spacer()

                        Link("Get API Key", destination: URL(string: "https://openrouter.ai/keys")!)
                            .font(.caption)
                    }
                }
            } header: {
                Text("API Configuration")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Trigger Hotkey:")
                        Spacer()
                        Text("⌘⌥A")
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    Text("Highlight text in any app and press the hotkey to open the assistant.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Keyboard Shortcut")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Model", selection: $selectedModel) {
                        ForEach(LLMModel.allCases) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    .onChange(of: selectedModel) { _ in
                        SecureStorage.shared.saveModel(selectedModel)
                    }

                    Text(selectedModel.rawValue)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("LLM Model")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tell the assistant about yourself:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextEditor(text: $personalContext)
                        .font(.body)
                        .frame(height: 100)
                        .border(Color.secondary.opacity(0.3), width: 1)

                    HStack {
                        Button("Save Context") {
                            savePersonalContext()
                        }

                        if isContextSaved {
                            Text("Saved!")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }

                        Spacer()

                        Text("\(personalContext.count) chars")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Personal Context")
            } footer: {
                Text("Example: \"I'm a software engineer working on iOS apps. I prefer Swift and SwiftUI. My name is John.\"")
                    .font(.caption)
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: TextCaptureService.shared.hasAccessibilityPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(TextCaptureService.shared.hasAccessibilityPermission ? .green : .orange)

                        Text(TextCaptureService.shared.hasAccessibilityPermission ? "Accessibility: Granted" : "Accessibility: Required")
                    }

                    if !TextCaptureService.shared.hasAccessibilityPermission {
                        Button("Grant Permission") {
                            TextCaptureService.shared.requestAccessibilityPermission()
                        }

                        Text("Required to capture selected text from other apps.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Permissions")
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 550)
        .onAppear {
            apiKey = SecureStorage.shared.getAPIKey() ?? ""
            selectedModel = SecureStorage.shared.getModel()
            personalContext = SecureStorage.shared.getPersonalContext() ?? ""
        }
    }

    private func saveAPIKey() {
        if SecureStorage.shared.saveAPIKey(apiKey) {
            isSaved = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isSaved = false
            }
        }
    }

    private func savePersonalContext() {
        SecureStorage.shared.savePersonalContext(personalContext)
        isContextSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isContextSaved = false
        }
    }
}
