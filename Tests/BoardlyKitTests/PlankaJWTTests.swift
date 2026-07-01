import Testing
import Foundation
@testable import BoardlyKit

@Suite("PlankaJWT")
struct PlankaJWTTests {

    private func token(payloadJSON: String) -> String {
        let payload = Data(payloadJSON.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "header.\(payload).signature"
    }

    @Test("reads the subject claim")
    func readsSubject() {
        #expect(PlankaJWT.userId(from: token(payloadJSON: #"{"subject":"u42"}"#)) == "u42")
    }

    @Test("falls back to other id claims")
    func fallbackClaims() {
        #expect(PlankaJWT.userId(from: token(payloadJSON: #"{"sub":"u7"}"#)) == "u7")
        #expect(PlankaJWT.userId(from: token(payloadJSON: #"{"userId":99}"#)) == "99")
    }

    @Test("returns nil for a non-JWT string")
    func nonJWT() {
        #expect(PlankaJWT.userId(from: "not-a-token") == nil)
        #expect(PlankaJWT.userId(from: "") == nil)
    }
}
