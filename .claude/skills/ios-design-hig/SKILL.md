i---
name: ios-design-hig
description: Use this skill when designing or reviewing SwiftUI views for Boardly — covers Apple HIG conventions, SF Symbols, accessibility, and Dynamic Type rules specific to this app.
---

# Boardly Design Guidelines (HIG)

## Navigation
- `NavigationStack` for the projects -> boards -> board detail drill-down.
- The server profile switcher lives at the top of the projects list, not
  buried in Settings — it's a primary action for a multi-instance app.

## Visual language
- Use semantic colors (`Color.primary`, `.secondary`, system backgrounds),
  never hardcoded hex values, so light/dark mode and increased-contrast
  settings work for free.
- SF Symbols for all iconography (board, list, card, task, profile icons).
  Don't introduce custom icon assets unless SF Symbols has no reasonable
  equivalent.

## Accessibility (non-negotiable for v1)
- Every interactive element has a meaningful accessibilityLabel (icon-only
  buttons especially: "Add card", not "plus.circle").
- Support Dynamic Type up to at least `.accessibility3`; test layouts at the
  largest size, not just the default.
- Don't rely on color alone to convey state (e.g. task done/overdue) — pair
  with an icon or text.

## Common pitfalls to flag in review
- Hardcoded `Color(hex:)` instead of semantic colors
- Fixed-size frames that break at large Dynamic Type sizes
- Tap targets smaller than 44x44pt
- Missing accessibilityLabel on icon-only buttons
