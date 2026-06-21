import Foundation

public enum PlankaAPIError: Error, @unchecked Sendable {
    case unauthorized
    case forbidden
    case notFound
    case conflict
    case invalidParams
    case serverError(Int)
    case networkError(any Error)
    case decodingError(any Error)
    case invalidURL
    case instanceUnreachable
    case keychainFailure(OSStatus)
}

extension PlankaAPIError: Equatable {
    public static func == (lhs: PlankaAPIError, rhs: PlankaAPIError) -> Bool {
        switch (lhs, rhs) {
        case (.unauthorized, .unauthorized): true
        case (.forbidden, .forbidden): true
        case (.notFound, .notFound): true
        case (.conflict, .conflict): true
        case (.invalidParams, .invalidParams): true
        case (.serverError(let l), .serverError(let r)): l == r
        case (.networkError, .networkError): true
        case (.decodingError, .decodingError): true
        case (.invalidURL, .invalidURL): true
        case (.instanceUnreachable, .instanceUnreachable): true
        case (.keychainFailure(let l), .keychainFailure(let r)): l == r
        default: false
        }
    }
}

extension PlankaAPIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unauthorized: "Unauthorized — please log in again."
        case .forbidden: "You don't have permission to perform this action."
        case .notFound: "The requested resource was not found."
        case .conflict: "A conflict occurred with the current state of the resource."
        case .invalidParams: "Invalid parameters were sent to the server."
        case .serverError(let code): "Server error (\(code))."
        case .networkError(let error): "Network error: \(error.localizedDescription)"
        case .decodingError(let error): "Failed to parse server response: \(error.localizedDescription)"
        case .invalidURL: "The server URL is invalid."
        case .instanceUnreachable: "Could not reach the PLANKA instance. Check the URL and try again."
        case .keychainFailure(let status): "Keychain operation failed (OSStatus \(status))."
        }
    }
}

extension PlankaAPIError {
    static func from(plankaCode: String) -> PlankaAPIError? {
        switch plankaCode {
        case "E_UNAUTHORIZED": .unauthorized
        case "E_FORBIDDEN": .forbidden
        case "E_NOT_FOUND": .notFound
        case "E_CONFLICT": .conflict
        case "E_MISSING_OR_INVALID_PARAMS": .invalidParams
        default: nil
        }
    }
}
