# Security Policy

## Supported Versions

Boardly is in active development. Only the latest release on `main` receives
security fixes.

| Version  | Supported |
|----------|-----------|
| latest   | ✅        |
| < latest | ❌        |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, use one of the following channels:

1. **Preferred** — GitHub's private vulnerability reporting:
   [Report a vulnerability](https://github.com/2rock-Inc/Boardly/security/advisories/new)
2. **Alternative** — email `security@rocquigny.fr` (PGP available on request)

You should receive an acknowledgment within 72 hours. If the issue is confirmed:

- A fix will be prepared in a private fork
- A GitHub Security Advisory will be published
- Credit will be given to the reporter (unless anonymity is requested)

## Scope

In scope:

- The Boardly iOS app source code
- The `BoardlyKit` Swift package
- CI/CD workflows in this repository

Out of scope:

- The PLANKA server itself (report to [plankanban/planka](https://github.com/plankanban/planka))
- Third-party dependencies (report upstream first)

## Signed Commits

All commits on `main` and all release tags (`v*.*.*`) are cryptographically
signed and enforced by repository rulesets. Verify signatures with:

    git log --show-signature main
