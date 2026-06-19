import Foundation
import Security

enum SecureAPIKeyStoreError: LocalizedError {
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            return "保存 API Key 失败（Keychain 状态：\(status)）。"
        }
    }
}

enum SecureAPIKeyStore {
    private static let service = "com.example.interviewcoach.deepseek"
    private static let account = "deepseek-api-key"

    static func saveDeepSeekKey(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let data = Data(trimmed.utf8)
        try deleteDeepSeekKey(ignoringMissing: true)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecureAPIKeyStoreError.unexpectedStatus(status)
        }
    }

    static func loadDeepSeekKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func hasDeepSeekKey() -> Bool {
        loadDeepSeekKey() != nil
    }

    static func deleteDeepSeekKey() throws {
        try deleteDeepSeekKey(ignoringMissing: false)
    }

    private static func deleteDeepSeekKey(ignoringMissing: Bool) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || (ignoringMissing && status == errSecItemNotFound) else {
            throw SecureAPIKeyStoreError.unexpectedStatus(status)
        }
    }
}
