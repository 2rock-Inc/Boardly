//
//  LoginViewModelTests.swift
//  BoardlyTests
//
//  Pure gating logic for the login screen: whether the password form and/or the
//  SSO button are shown, driven by the instance's advertised OIDC config.
//

import Foundation
import Testing
import BoardlyKit
@testable import Boardly

@Suite("LoginViewModel — OIDC gating")
@MainActor
struct LoginViewModelTests {
    private func oidc(enforced: Bool) throws -> Bootstrap.OIDCConfig {
        let json = #"{"authorizationUrl":"https://idp.example.com/auth?nonce=abc","endSessionUrl":null,"isEnforced":\#(enforced)}"#
        return try JSONDecoder().decode(Bootstrap.OIDCConfig.self, from: Data(json.utf8))
    }

    @Test("no OIDC advertised → password form only, no SSO button")
    func noOIDC() {
        let vm = LoginViewModel()
        #expect(vm.showsPasswordForm == true)
        #expect(vm.showsSSO == false)
    }

    @Test("optional OIDC → both password form and SSO button")
    func optionalOIDC() throws {
        let vm = LoginViewModel()
        vm.oidc = try oidc(enforced: false)
        #expect(vm.showsPasswordForm == true)
        #expect(vm.showsSSO == true)
    }

    @Test("enforced OIDC → SSO only, password form hidden")
    func enforcedOIDC() throws {
        let vm = LoginViewModel()
        vm.oidc = try oidc(enforced: true)
        #expect(vm.showsPasswordForm == false)
        #expect(vm.showsSSO == true)
    }
}
