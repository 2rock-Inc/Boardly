---
name: keychain-auth-review
description: Use this skill before merging any change that touches login, token storage, or the Keychain. Checklist-driven review of the PLANKA auth flow (POST /access-tokens to JWT to Keychain).
---

# Keychain / Auth Flow Review Checklist

Run through this checklist for any change touching authentication.

## Storage
- [ ] The JWT returned by `POST /access-tokens` is written to the Keychain,
      never to UserDefaults, a plist, or a file on disk.
- [ ] The Keychain item is scoped per server profile (account = server URL +
      username, not a single shared item).
- [ ] Keychain access control is at minimum
      `kSecAttrAccessibleAfterFirstUnlock` (or stricter) — never an `Always`
      variant.

## Network
- [ ] No URLSessionDelegate unconditionally trusts server certificates.
      Self-signed cert trust is per-profile and requires explicit user
      confirmation, never a global bypass.
- [ ] The Authorization / X-Api-Key header is never logged, including in
      debug builds.
- [ ] 401 responses route to that profile's login screen; they do not crash
      or silently retry forever.

## Lifecycle
- [ ] Logout removes the Keychain item for that profile only.
- [ ] Removing a server profile clears its token and any cached data tied
      to it.
- [ ] No token or password ever appears in a crash report, analytics event,
      or print/os_log statement.

If any box can't be checked, stop and flag it before merging.
