import Foundation

enum AIServiceFactory {
    @MainActor
    static func makeDefaultService() -> any InterviewAIProviding {
        DeepSeekInterviewAIService(model: currentModel())
    }

    static func currentProviderName() -> String {
        currentDeepSeekKey() == nil ? "未配置 DeepSeek" : "DeepSeek V4"
    }

    static func currentModel() -> String {
        UserDefaults.standard.string(forKey: "deepseek.model") ?? DeepSeekModel.flash.rawValue
    }

    static func currentDeepSeekKey() -> String? {
        if let key = SecureAPIKeyStore.loadDeepSeekKey() {
            return key
        }
        return nil
    }
}
