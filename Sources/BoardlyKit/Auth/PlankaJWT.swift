import Foundation

/// Minimal, dependency-free reader for the PLANKA access token (a JWT). Only
/// used to recover the current user's id for display (e.g. the header avatar) —
/// never for trust decisions; the server validates the token on every request.
public enum PlankaJWT {
    /// Extract the user id from the token's payload, trying the claim names
    /// PLANKA / Sails may use. Returns nil if the token isn't a decodable JWT.
    public static func userId(from token: String) -> String? {
        let segments = token.split(separator: ".")
        guard segments.count >= 2,
              let data = base64URLDecode(String(segments[1])),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        for key in ["subject", "sub", "userId", "id"] {
            if let value = json[key] {
                if let s = value as? String { return s }
                if let n = value as? Int { return String(n) }
            }
        }
        return nil
    }

    private static func base64URLDecode(_ string: String) -> Data? {
        var s = string.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s.append("=") }
        return Data(base64Encoded: s)
    }
}
