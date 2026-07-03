import Foundation
import Security

public struct KeychainStore: KeychainStoring {
    private static let service = "com.rocquigny.boardly"

    public init() {}

    public func save(_ value: String, for key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw PlankaAPIError.keychainFailure(errSecParam)
        }

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: key,
        ]

        let status = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData: data] as CFDictionary)

        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw PlankaAPIError.keychainFailure(addStatus)
            }
        } else if status != errSecSuccess {
            throw PlankaAPIError.keychainFailure(status)
        }
    }

    public func load(for key: String) throws -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else {
            throw PlankaAPIError.keychainFailure(status)
        }
        return string
    }

    public func delete(for key: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: key,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PlankaAPIError.keychainFailure(status)
        }
    }
}
