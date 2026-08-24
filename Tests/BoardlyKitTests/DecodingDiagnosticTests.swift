import Foundation
import Testing
@testable import BoardlyKit

@Suite("Decoding diagnostics")
struct DecodingDiagnosticTests {
    private struct Member: Decodable {
        let id: String
        let role: String
        let isDeactivated: Bool
    }

    private struct Payload: Decodable {
        let included: Included
        struct Included: Decodable {
            let users: [Member]
        }
    }

    private func diagnose(_ json: String) -> String {
        do {
            _ = try JSONDecoder().decode(Payload.self, from: Data(json.utf8))
            return "decoded without error"
        } catch {
            return error.decodingDiagnostic
        }
    }

    @Test("a missing key names the key and where it sits")
    func missingKey() {
        // The exact shape of the failure that costs an afternoon otherwise: one element of
        // a sideloaded collection is short a field.
        let diagnosis = diagnose(#"""
        {"included":{"users":[{"id":"1","role":"admin","isDeactivated":false},
                              {"id":"2","isDeactivated":false}]}}
        """#)
        #expect(diagnosis == "missing key 'role' at included.users[1]")
    }

    @Test("a type mismatch names the expected type and where")
    func typeMismatch() {
        let diagnosis = diagnose(#"""
        {"included":{"users":[{"id":"1","role":"admin","isDeactivated":"nope"}]}}
        """#)
        #expect(diagnosis.hasPrefix("expected Bool at included.users[0].isDeactivated"))
    }

    @Test("a null in a non-optional field is reported as such")
    func nullValue() {
        let diagnosis = diagnose(#"""
        {"included":{"users":[{"id":"1","role":null,"isDeactivated":false}]}}
        """#)
        #expect(diagnosis.hasPrefix("null where non-optional String expected at included.users[0].role"))
    }

    @Test("a failure at the top level says so rather than naming nothing")
    func rootLevel() {
        #expect(diagnose(#"{}"#) == "missing key 'included' at the root object")
    }

    @Test("non-decoding errors keep their own description")
    func passesThroughOtherErrors() {
        let error = PlankaAPIError.instanceUnreachable
        #expect(error.decodingDiagnostic == error.localizedDescription)
    }
}
