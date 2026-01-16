import Foundation

enum LLMModel: String, CaseIterable, Identifiable {
    case geminiFlash = "google/gemini-2.5-flash-lite-preview-09-2025"
    case gptOss120b = "openai/gpt-oss-120b"
    case gpt5Nano = "openai/gpt-5-nano"
    case qwenCoder = "qwen/qwen3-coder"
    case grok41Fast = "x-ai/grok-4.1-fast"
    case deepseekV32 = "deepseek/deepseek-v3.2"
    case kimiK2Thinking = "moonshotai/kimi-k2-thinking"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .geminiFlash: return "Gemini 2.5 Flash Lite"
        case .gptOss120b: return "GPT OSS 120B"
        case .gpt5Nano: return "GPT-5 Nano"
        case .qwenCoder: return "Qwen3 Coder"
        case .grok41Fast: return "Grok 4.1 Fast"
        case .deepseekV32: return "DeepSeek V3.2"
        case .kimiK2Thinking: return "Kimi K2 Thinking"
        }
    }
}

final class SecureStorage {
    static let shared = SecureStorage()

    private let apiKeyKey = "openrouter_api_key"
    private let modelKey = "selected_model"
    private let defaults = UserDefaults.standard

    private init() {}

    func saveAPIKey(_ key: String) -> Bool {
        defaults.set(key, forKey: apiKeyKey)
        defaults.synchronize()
        return true
    }

    func getAPIKey() -> String? {
        let key = defaults.string(forKey: apiKeyKey)
        return key?.isEmpty == true ? nil : key
    }

    @discardableResult
    func deleteAPIKey() -> Bool {
        defaults.removeObject(forKey: apiKeyKey)
        defaults.synchronize()
        return true
    }

    var hasAPIKey: Bool {
        if let key = getAPIKey(), !key.isEmpty {
            return true
        }
        return false
    }

    // Model selection
    func saveModel(_ model: LLMModel) {
        defaults.set(model.rawValue, forKey: modelKey)
        defaults.synchronize()
    }

    func getModel() -> LLMModel {
        if let raw = defaults.string(forKey: modelKey),
           let model = LLMModel(rawValue: raw) {
            return model
        }
        return .geminiFlash // Default model
    }

    // Web search toggle
    private let webSearchEnabledKey = "web_search_enabled"

    func saveWebSearchEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: webSearchEnabledKey)
        defaults.synchronize()
    }

    func isWebSearchEnabled() -> Bool {
        return defaults.bool(forKey: webSearchEnabledKey)
    }

    // Personal context
    private let personalContextKey = "personal_context"

    func savePersonalContext(_ context: String) {
        defaults.set(context, forKey: personalContextKey)
        defaults.synchronize()
    }

    func getPersonalContext() -> String? {
        let context = defaults.string(forKey: personalContextKey)
        return context?.isEmpty == true ? nil : context
    }

    var hasPersonalContext: Bool {
        if let context = getPersonalContext(), !context.isEmpty {
            return true
        }
        return false
    }
}
