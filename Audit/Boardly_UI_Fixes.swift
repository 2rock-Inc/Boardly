//
//  Boardly_UI_Fixes.swift
//  Root-cause fixes from the 15-agent UI audit (2026-07-04).
//
//  HOW TO APPLY
//  ────────────
//  • Sections 1–4 are NET-NEW (tokens, modifiers, components) — drop them into
//    the DesignSystem folder as-is; they don't collide with anything.
//  • Section 5 lists IN-PLACE replacements (buttons, card shadow, sheet header,
//    colorsets) — apply them where indicated, they REPLACE existing code.
//
//  Fixing sections 1–5 raises almost every zone score, because most screens
//  inherit these foundation defects.
//

import SwiftUI

// ============================================================================
// MARK: - 1. Missing typography tokens  (P0 #3, P1 detail/sheet/section titles)

// ============================================================================
// The prototype's structural type scale had no Swift token. `boardlyTitle`
// (Manrope 26 bold) was wrongly used for screen titles (spec = 32 ExtraBold).

extension Font {
    /// Screen title — Manrope ExtraBold 32 (Projects / Search / Activity / Profile).
    static let boardlyScreenTitle = sans(32, .heavy, relativeTo: .largeTitle)
    /// Card-detail title — ExtraBold 23 (apply `.tracking(-0.46)` ≈ -0.02em at call site).
    static let boardlyDetailTitle = sans(23, .heavy, relativeTo: .title)
    /// Bottom-sheet title — ExtraBold 17.
    static let boardlySheetTitle = sans(17, .heavy, relativeTo: .headline)
    /// Section title — Bold 13.
    static let boardlySectionTitle = sans(13, .bold, relativeTo: .subheadline)
}

/// Mono uppercase label with the correct tracking — `Font` alone can't carry
/// letter-spacing/case, so the mono-label look must be applied as a modifier.
/// Replaces ad-hoc `.font(.boardlyMonoLabel).tracking(1.5)` scattered per screen.
struct BoardlyMonoLabelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.boardlyMonoLabel) // JetBrains Mono 11
            .textCase(.uppercase)
            .tracking(1.1) // ≈ .1em at 11pt (spec .1–.14em)
    }
}

extension View {
    /// Uppercase mono section label (Projects "FAVORIS", card-detail sections…).
    func boardlyMonoLabel() -> some View { modifier(BoardlyMonoLabelStyle()) }
}

// ============================================================================
// MARK: - 2. Missing / corrected color tokens  (P0 #5, #6)

// ============================================================================
// STOPGAP: these belong in Assets.xcassets as .colorset (light+dark). Defined
// here as sRGB literals so screens can stop hardcoding hex immediately.
// See Section 5 for the .colorset corrections that must ALSO be made.

extension Color {
    /// Destructive #B0413E — there is NO such token today; `labelRose` (#B05C72,
    /// an AVATAR color) is currently misused for Log Out / delete. (P0 #5)
    static let boardlyDestructive = Color(.sRGB, red: 0.690, green: 0.255, blue: 0.243, opacity: 1)
    /// Non-encrypted / warning amber (AddServer http warning uses raw `.orange`).
    static let boardlyWarning = Color(.sRGB, red: 0.753, green: 0.510, blue: 0.243, opacity: 1)

    /// Teal fill #E2EFEC — timer chip / tinted icon tiles (hardcoded per screen).
    static let boardlyTealFill = Color(.sRGB, red: 0.886, green: 0.937, blue: 0.925, opacity: 1)
    /// Neutral fill #ECEAE4 — search bar / count badge track / segmented track.
    static let boardlyNeutralFill = Color(.sRGB, red: 0.925, green: 0.918, blue: 0.894, opacity: 1)
    /// Muted #9A968D — placeholders / disabled meta.
    static let boardlyMuted = Color(.sRGB, red: 0.604, green: 0.588, blue: 0.553, opacity: 1)
    /// Empty ring #D4D0C8 — unchecked selection ring, "+Label" dashed border.
    static let boardlyEmptyRing = Color(.sRGB, red: 0.831, green: 0.816, blue: 0.784, opacity: 1)
    /// Grabber #CFCBC2 — sheet drag indicator.
    static let boardlyGrabber = Color(.sRGB, red: 0.812, green: 0.796, blue: 0.761, opacity: 1)

    /// Missing label palette entries (currently hardcoded on cards).
    /// labelPriority = amber darkened #C0823E → #9D6A33 so white text hits WCAG AA
    /// (3.23:1 → 4.62:1), hue preserved. (audit decision: darken)
    static let labelPriority = Color(.sRGB, red: 0.616, green: 0.416, blue: 0.200, opacity: 1) // #9D6A33
    static let labelBlocked = Color(.sRGB, red: 0.690, green: 0.255, blue: 0.243, opacity: 1) // #B0413E (4.9:1 ✓)
}

// ============================================================================
// MARK: - 3. Accessibility + hit-target helper  (P0 #1, a11y 45/100)

// ============================================================================
// App-wide: 0 accessibilityLabel, and icon-only buttons render ~17–22pt taps.

extension View {
    /// Guarantees a ≥44pt hit target and a VoiceOver label on an icon-only control.
    /// Usage: `Image(systemName: "chevron.left").boardlyTapTarget("Back")`
    func boardlyTapTarget(_ label: LocalizedStringKey, size: CGFloat = 44) -> some View {
        frame(minWidth: size, minHeight: size)
            .contentShape(Rectangle())
            .accessibilityLabel(Text(label))
    }
}

// ============================================================================
// MARK: - 4. Shared components that were missing / re-implemented per screen

// ============================================================================

/// Neutral chip (count badge, tags) — radius 11 (P1: no shared chip existed).
struct BoardlyChip<Label: View>: View {
    @ViewBuilder let label: Label var body: some View {
        label
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(Color.boardlyNeutralFill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

/// Tinted icon tile for settings rows — 30pt, radius 9, teal-fill bg (Profile). (P1)
struct BoardlyIconTile: View {
    let systemName: String
    var tint: Color = .accentColor
    var fill: Color = .boardlyTealFill
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: 30, height: 30)
            .background(fill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

/// Dashed "+ Label" pill — dashed #D4D0C8, muted text, radius 7. (spec/P1)
struct BoardlyAddLabelPill: View {
    let title: LocalizedStringKey
    var body: some View {
        Text(title)
            .font(.sans(10.5, .bold)).textCase(.uppercase)
            .foregroundStyle(Color.boardlyMuted)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.boardlyEmptyRing, style: StrokeStyle(lineWidth: 1, dash: [3])))
    }
}

/// Correct selection check — accent 24 filled + white check / unchecked ring
/// #D4D0C8. (P1: current SelectionToggle uses 22 + tertiary ring.)
struct BoardlySelectionCheck: View {
    let isOn: Bool
    var body: some View {
        ZStack {
            if isOn {
                Circle().fill(Color.accentColor)
                Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
            } else {
                Circle().strokeBorder(Color.boardlyEmptyRing, lineWidth: 2)
            }
        }
        .frame(width: 24, height: 24)
    }
}

/// Elevated card surface — the spec shadow instead of the hairline stroke that
/// `.boardlyCard` currently uses. (P0 #2) Prefer migrating `.boardlyCard` itself.
extension View {
    func boardlyElevatedCard(cornerRadius: CGFloat = 14) -> some View {
        background(Color.boardlySurface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
    }
}

// ============================================================================
// MARK: - 5. IN-PLACE replacements (apply where indicated)

// ============================================================================
/*
 ── BoardlyComponents.swift · button styles (P0 #4) ─────────────────────────
 REPLACE the `Capsule()` shape + padding-derived height with radius 15 / h54 /
 font 17 in BOTH BoardlyPrimaryButtonStyle and BoardlySecondaryButtonStyle:

     // primary
     configuration.label
         .font(.sans(17, .bold))
         .foregroundStyle(.white)
         .frame(maxWidth: .infinity, minHeight: 54)
         .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
     // secondary
     configuration.label
         .font(.sans(17, .semibold))
         .foregroundStyle(Color.boardlyInk)
         .frame(maxWidth: .infinity, minHeight: 54)
         .background(.clear)                                  // transparent, not surface
         .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
                     .strokeBorder(Color.boardlyBorder, lineWidth: 1))

 ── BoardlyComponents.swift · `.boardlyCard()` (P0 #2) ──────────────────────
 REPLACE `.overlay(RoundedRectangle(...).stroke(boardlySeparator, 0.5))`
 with the spec shadow:
     .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)

 ── BoardlyComponents.swift · SheetHeader (P1, all sheets) ──────────────────
 title font 16 bold → `.font(.boardlySheetTitle)` (17 ExtraBold);
 done/OK label → weight 700 (`.sans(16..17, .bold)`).
 Grabber: `Capsule().fill(Color.boardlyGrabber).frame(width: 36, height: 4)`.

 ── Card sheets · every sheet body (P1) ─────────────────────────────────────
 ADD `.presentationCornerRadius(26)` (CardLabels/Members/DueDate/Attachments/
 CardCustomFields/BoardCustomFields — EditProjectSheet already has it).

 ── Assets.xcassets · .colorset corrections (P0 #5, #6) ─────────────────────
 BoardlyBackground   : light #E7E5DF → #F4F2EE  ·  dark #0B0C0E → #1D1F24
 BoardlyTextSecondary: #76726B → #55524C   (real secondary; #76726B is tertiary)
 BoardlyTextTertiary : #A8A49C → #76726B   (was the muted tone)
 BoardlyInk (dark)   : #F4F1EB → #FFFFFF
 LabelGreen (WCAG)   : #6F8B57 → #637D4E  (white text 3.81:1 → 4.59:1, hue kept)
 + NEW colorsets: BoardlyDestructive #B0413E, BoardlyTealFill #E2EFEC,
   BoardlyNeutralFill #ECEAE4, LabelPriority #9D6A33 (amber darkened for AA),
   LabelBlocked #B0413E
   (then delete the Section-2 sRGB stopgaps and point the tokens at the assets).

 ── BoardView.swift · new-card & filters modals (P1 shell) ──────────────────
 Replace `.alert("New Card")` with a `.sheet` using the Boardly chrome; wrap the
 filters `Image` in a `Button` opening a FiltersSheet (same chrome).
 */
