import BoardlyKit
import Foundation

/// User-facing localized copy for an error. BoardlyKit stays UI-string-free and
/// surfaces typed `PlankaAPIError`s / codes; the app owns the wording so it can be
/// localized through the String Catalog. System errors (URLSession, etc.) are
/// already localized by the OS, so their `localizedDescription` is used as-is.
func localizedErrorMessage(_ error: Error) -> String {
    guard let apiError = error as? PlankaAPIError else {
        return error.localizedDescription
    }
    switch apiError {
    case .unauthorized:
        return String(localized: "Unauthorized — please log in again.")
    case .forbidden:
        return String(localized: "You don’t have permission to do this.")
    case .notFound:
        return String(localized: "The requested item was not found.")
    case .conflict:
        return String(localized: "This conflicts with the current state. Refresh and try again.")
    case .invalidParams:
        return String(localized: "The server rejected the request.")
    case let .serverError(code):
        return String(localized: "Server error (\(code)).")
    case .networkError:
        return String(localized: "A network error occurred. Check your connection.")
    case .decodingError:
        return String(localized: "Couldn’t read the server’s response.")
    case .invalidURL:
        return String(localized: "The server address is invalid.")
    case .instanceUnreachable:
        return String(localized: "Couldn’t reach the PLANKA server. Check the address and try again.")
    case .keychainFailure:
        return String(localized: "A Keychain error occurred.")
    }
}
