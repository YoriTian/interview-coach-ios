import Foundation

enum AIServiceFactory {
    private static let modelKey = "deepseek.model"
    private static let proDefaultMigrationKey = "deepseek.model.pro-default.v1"

    @MainActor
    static func makeDefaultService() -> any InterviewAIProviding {
        DeepSeekInterviewAIService(model: currentModel())
    }

    static func currentProviderName() -> String {
        guard currentDeepSeekKey() != nil else { return "未配置 DeepSeek" }
        let model = DeepSeekModel(rawValue: currentModel()) ?? .pro
        return model == .pro ? "V4 Pro 深度思考" : "V4 Flash 快速模式"
    }

    static func currentModel() -> String {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: proDefaultMigrationKey) {
            defaults.set(true, forKey: proDefaultMigrationKey)
            defaults.set(DeepSeekModel.pro.rawValue, forKey: modelKey)
        }
        return defaults.string(forKey: modelKey) ?? DeepSeekModel.pro.rawValue
    }

    static func currentDeepSeekKey() -> String? {
        if let key = SecureAPIKeyStore.loadDeepSeekKey() {
            return key
        }
        return nil
    }
}
