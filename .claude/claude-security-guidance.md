# Boardly Security Threat Model

Boardly is a native iOS client that connects to arbitrary self-hosted PLANKA
instances over HTTPS. There is no Boardly-owned backend; all sensitive data
lives on the user's own server. The main risks are credential handling,
transport security, and trusting servers Boardly doesn't control.

## Hard rules

- Tokens never touch UserDefaults, plists, logs, or crash reports. The JWT
  returned by `POST /access-tokens` must be stored exclusively in the iOS
  Keychain, scoped per server profile (one Keychain item per server URL +
  account).
- No blanket TLS bypass. Never implement a `URLSessionDelegate` that accepts
  all certificates unconditionally. Self-signed certificates must go through
  an explicit, per-server "trust this certificate" flow the user confirms —
  never a silent global bypass.
- No secrets in logs. Never log full request/response bodies for
  `/access-tokens`, or any header containing a token or password. Redact
  `Authorization` and `X-Api-Key` headers in any debug logging.
- Server URLs are untrusted input. Validate and normalize user-entered
  server URLs before use; never interpolate them into shell commands or
  unsanitized format strings.
- Multi-instance isolation. Credentials and cached data for one server
  profile must never leak into another profile's Keychain item or cache
  namespace.

## Out of scope for this threat model (not yet built)

- OIDC/SSO flows
- Server-side PLANKA security (outside Boardly's control)
- Real-time / Socket.IO transport
