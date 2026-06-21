import Foundation

public protocol KeychainStoring: Sendable {
    func save(_ value: String, for key: String) throws
    func load(for key: String) throws -> String?
    func delete(for key: String) throws
}
