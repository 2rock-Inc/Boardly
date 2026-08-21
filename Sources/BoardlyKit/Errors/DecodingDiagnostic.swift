import Foundation

extension DecodingError {
    /// A one-line diagnosis naming the field that failed and why.
    ///
    /// `localizedDescription` on a `DecodingError` is always the same sentence — "the data
    /// couldn't be read because it isn't in the correct format" — which says nothing about
    /// *which* field broke. Every detail needed to find it is sitting in the associated
    /// context, so it gets pulled out here: PLANKA's payloads drift between versions and
    /// editions, and "missing key 'role' at included.users[3]" turns an afternoon of
    /// guesswork into a one-line fix.
    ///
    /// Only the shape is reported — coding path, expected type, reason. Decoded values are
    /// never included, so nothing a user typed can reach the log through this.
    var diagnostic: String {
        switch self {
        case let .keyNotFound(key, context):
            "missing key '\(key.stringValue)' at \(Self.describe(context.codingPath))"
        case let .typeMismatch(type, context):
            "expected \(type) at \(Self.describe(context.codingPath))"
        case let .valueNotFound(type, context):
            "null where non-optional \(type) expected at \(Self.describe(context.codingPath))"
        case let .dataCorrupted(context):
            "corrupted value at \(Self.describe(context.codingPath)): \(context.debugDescription)"
        @unknown default:
            "unrecognised decoding failure"
        }
    }

    /// Renders a coding path the way it reads in JSON: `included.users[3].role`.
    private static func describe(_ path: [any CodingKey]) -> String {
        guard !path.isEmpty else { return "the root object" }
        return path.reduce(into: "") { rendered, key in
            if let index = key.intValue {
                rendered += "[\(index)]"
            } else {
                rendered += rendered.isEmpty ? key.stringValue : ".\(key.stringValue)"
            }
        }
    }
}

extension Error {
    /// The decoding diagnosis when this is a `DecodingError`, otherwise the usual
    /// description — so log sites can pass any error without branching.
    var decodingDiagnostic: String {
        (self as? DecodingError)?.diagnostic ?? localizedDescription
    }
}
