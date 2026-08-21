import BoardlyKit
import Foundation

/// User-facing localized copy for an error. BoardlyKit stays UI-string-free and
/// surfaces typed `PlankaAPIError`s / codes; the app owns the wording so it can be
/// localized through the String Catalog. System errors (URLSession, etc.) are
/// already localized by the OS, so their `localizedDescription` is used as-is.
/// Copy for a refused sign-in. PLANKA distinguishes several restrictions and only one of
/// them is actionable in-app, so each gets its own wording — telling someone to "contact
/// your administrator" when the fix is to press the SSO button helps nobody. The raw
/// message of an `.unknown` reason is never shown: BoardlyKit logs it, the user gets copy
/// we actually wrote.
func localizedRestrictionMessage(_ reason: AuthRestriction.Reason) -> String {
    switch reason {
    case .termsAcceptanceRequired:
        String(localized: "You need to accept this server’s terms before signing in.")
    case .useSingleSignOn:
        String(localized: "This server only allows single sign-on. Use the SSO button instead.")
    case .adminLoginRequired:
        String(localized: "This server hasn’t been set up yet. An administrator has to sign in first.")
    case .unknown:
        String(localized: "Sign-in is restricted on this server. Check with your administrator.")
    }
}

func localizedErrorMessage(_ error: Error) -> String {
    guard let apiError = error as? PlankaAPIError else {
        return error.localizedDescription
    }
    switch apiError {
    case .unauthorized:
        return String(localized: "Unauthorized — please log in again.")
    case .forbidden:
        return String(localized: "You don’t have permission to do this.")
    case let .authRestriction(restriction):
        return localizedRestrictionMessage(restriction.reason)
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
