import Foundation

extension JSONDecoder {
    static let planka: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = ISO8601Formatters.fractional.date(from: string) { return date }
            if let date = ISO8601Formatters.standard.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date from '\(string)'")
        }
        return decoder
    }()
}

/// Canonical PLANKA wire-format date formatters, shared by both the decoder
/// (above) and `CardPatch` encoding so the read and write sides never desync.
enum ISO8601Formatters {
    nonisolated(unsafe) static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) static let standard: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
