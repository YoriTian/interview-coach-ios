import SwiftUI

struct DeepSeekSettingsPanel: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var apiKey = ""
    @State private var selectedModel: DeepSeekModel = .flash
    @State private var hasSavedKey = false
    @State private var isTesting = false
    @State private var statusMessage: String?
    @State private var statusIsSuccess = false

    var body: some View {
        SurfacePanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 42, height: 42)
                        .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("DeepSeek V4")
                            .font(.system(size: 22, weight: .semibold))
                        Text("当前评分引擎：\(viewModel.activeAIProviderName)")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                Picker("模型", selection: $selectedModel) {
                    ForEach(DeepSeekModel.allCases) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedModel) { _, model in
                    UserDefaults.standard.set(model.rawValue, forKey: "deepseek.model")
                    viewModel.refreshAIService()
                }

                SecureField(hasSavedKey ? "已保存，可留空" : "粘贴 DeepSeek API Key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 15))
                    .padding(14)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                HStack(spacing: 12) {
                    Button(action: saveKey) {
                        Label("保存", systemImage: "checkmark.shield")
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button(action: clearKey) {
                        Label("清除", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!hasSavedKey)
                }

                Button(action: testConnection) {
                    Label(isTesting ? "测试中" : "测试连接", systemImage: "network")
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.bordered)
                .disabled(isTesting || currentKeyForTesting == nil)

                if let statusMessage {
                    Label(statusMessage, systemImage: statusIsSuccess ? "checkmark.circle" : "exclamationmark.triangle")
                        .font(.system(size: 14))
                        .foregroundStyle(statusIsSuccess ? .green : .orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("Key 会保存在本机 Keychain。正式上线建议改为后端代理，避免把平台密钥分发到用户设备。")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear(perform: refreshSavedState)
    }

    private var currentKeyForTesting: String? {
        let typed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty {
            return typed
        }
        return SecureAPIKeyStore.loadDeepSeekKey()
    }

    private func saveKey() {
        do {
            try SecureAPIKeyStore.saveDeepSeekKey(apiKey)
            apiKey = ""
            statusIsSuccess = true
            statusMessage = "已安全保存，后续评分会使用 \(selectedModel.displayName)。"
            refreshSavedState()
            viewModel.refreshAIService()
        } catch {
            statusIsSuccess = false
            statusMessage = error.localizedDescription
        }
    }

    private func clearKey() {
        do {
            try SecureAPIKeyStore.deleteDeepSeekKey()
            apiKey = ""
            statusIsSuccess = true
            statusMessage = "已清除 Key。AI 评分和教练会暂停，重新保存 Key 后恢复。"
            refreshSavedState()
            viewModel.refreshAIService()
        } catch {
            statusIsSuccess = false
            statusMessage = error.localizedDescription
        }
    }

    private func testConnection() {
        guard let key = currentKeyForTesting else { return }
        isTesting = true
        statusMessage = nil

        Task {
            do {
                let evaluation = try await DeepSeekConnectionTester().test(apiKey: key, model: selectedModel)
                statusIsSuccess = true
                statusMessage = "连接成功，测试评分 \(evaluation.overallScore) 分。"
            } catch {
                statusIsSuccess = false
                statusMessage = error.localizedDescription
            }
            isTesting = false
        }
    }

    private func refreshSavedState() {
        selectedModel = DeepSeekModel(rawValue: AIServiceFactory.currentModel()) ?? .flash
        hasSavedKey = SecureAPIKeyStore.hasDeepSeekKey()
    }
}
