---
name: test-coverage
description: Use this skill when asked to check or improve test coverage for Boardly or BoardlyKit, or before merging a PR that touches networking/auth code.
---

# Running Test Coverage

## BoardlyKit (Swift package)

    swift test --enable-code-coverage
    xcrun llvm-cov report \
      .build/debug/BoardlyKitPackageTests.xctest/Contents/MacOS/BoardlyKitPackageTests \
      -instr-profile .build/debug/codecov/default.profdata

## Boardly (app target)

    xcodebuild test \
      -project Boardly.xcodeproj -scheme Boardly \
      -destination 'platform=iOS Simulator,name=iPhone 17' \
      -enableCodeCoverage YES

## Priorities
Coverage on BoardlyKit (networking/auth/model layer) matters far more than
on SwiftUI Views. Prioritize:
1. API client request/response handling and error mapping
2. Keychain storage wrapper
3. Model decoding against `Reference/planka-openapi.json` fixtures

Don't chase coverage percentage on Views — prefer a couple of integration
tests over snapshot-testing every screen in v1.
