#!/usr/bin/env python3
"""
Boardly_UIChecker — heuristic UI-consistency scanner (triage aid, not authoritative).

Flags the recurring defects the 15-agent audit found:
  • raw SwiftUI colors (Color.red/.orange/.yellow/... ) that bypass tokens
  • Color(hex:) outside the allowed data files
  • Capsule() shapes (buttons/chips should be RoundedRectangle 15/11)
  • .font(.system(size:)) applied to Text (should use .sans/.mono tokens)
  • icon-only Image(systemName:) inside a Button with no .accessibilityLabel nearby

Run:  python3 Audit/Boardly_UIChecker.py
Exit: 0 always (advisory). Add --strict to exit 1 when findings exist.
"""
import re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
APP = ROOT / "Boardly" / "Boardly"
ALLOW_HEX = {"PlankaGradient.swift", "PlankaLabelColor.swift"}  # PLANKA data palette, legit
SKIP = {"PreviewMock.swift"}

RAW_COLOR = re.compile(r"\.(red|orange|yellow|blue|green|pink|purple|gray|grey|brown|cyan|indigo|mint|teal)\b(?!\w)")
RAW_COLOR_CTX = re.compile(r"(foregroundStyle|foregroundColor|fill|tint|background|stroke|strokeBorder)\s*\(\s*\.(red|orange|yellow|blue|green|pink|purple|gray|grey|brown|cyan|indigo|mint)\b")
HEX = re.compile(r"Color\(hex:")
CAPSULE = re.compile(r"\bCapsule\(\)")
SYSFONT = re.compile(r"\.font\(\.system\(size:")
IMG_SYS = re.compile(r"Image\(systemName:")
A11Y = re.compile(r"accessibilityLabel")

findings = []


def add(f, ln, kind, text):
    findings.append((str(f.relative_to(ROOT)), ln, kind, text.strip()[:90]))


for f in sorted(APP.rglob("*.swift")):
    if f.name in SKIP:
        continue
    lines = f.read_text(encoding="utf-8").splitlines()
    body = "\n".join(lines)
    for i, line in enumerate(lines, 1):
        s = line.strip()
        if s.startswith("//"):
            continue
        if RAW_COLOR_CTX.search(line):
            add(f, i, "RAW_COLOR", line)
        if HEX.search(line) and f.name not in ALLOW_HEX:
            add(f, i, "HEX_COLOR", line)
        if CAPSULE.search(line):
            add(f, i, "CAPSULE", line)
        if SYSFONT.search(line) and (".sans" not in line):
            add(f, i, "SYSTEM_FONT", line)
    # icon-only buttons without an a11y label anywhere in the file (coarse ratio)
    icons, labels = len(IMG_SYS.findall(body)), len(A11Y.findall(body))
    if icons > 0 and labels == 0:
        add(f, 0, "NO_A11Y_LABEL", f"{icons} Image(systemName:) · 0 accessibilityLabel in file")

by_kind = {}
for f, ln, kind, text in findings:
    by_kind.setdefault(kind, []).append((f, ln, text))

TITLES = {
    "RAW_COLOR": "Raw SwiftUI color bypassing a token",
    "HEX_COLOR": "Color(hex:) outside the PLANKA data palette",
    "CAPSULE": "Capsule() — buttons=RoundedRectangle(15), chips=(11)",
    "SYSTEM_FONT": ".system(size:) — use .sans/.mono tokens (won't scale as intended)",
    "NO_A11Y_LABEL": "Icon buttons with no accessibilityLabel in the file",
}
print(f"Boardly UI checker — {len(findings)} advisory finding(s)\n")
for kind in ["HEX_COLOR", "RAW_COLOR", "CAPSULE", "SYSTEM_FONT", "NO_A11Y_LABEL"]:
    items = by_kind.get(kind, [])
    if not items:
        continue
    print(f"■ {kind} ({len(items)}) — {TITLES[kind]}")
    for f, ln, text in items[:20]:
        loc = f"{f}:{ln}" if ln else f
        print(f"    {loc}  {text}")
    if len(items) > 20:
        print(f"    … +{len(items) - 20} more")
    print()

if "--strict" in sys.argv and findings:
    sys.exit(1)
