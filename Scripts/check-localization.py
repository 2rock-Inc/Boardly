#!/usr/bin/env python3
"""Blocking localization guard (see CLAUDE.md › Localization).

Fails CI on:
  1. Catalog gaps  — any key missing its `fr` translation, or left `stale` /
     `needs_review` in Localizable.xcstrings.
  2. Divergent patterns that always leak — `Text(x.rawValue)` / `Text(x.label)`
     and inline `+"s"` plural hacks.

The "String copy param on a view component" case can't be detected reliably by
grep without false positives — it's caught by the accented-pseudolanguage pass
in the release checklist instead.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "Boardly/Boardly/Localizable.xcstrings"
APP_SOURCES = ROOT / "Boardly/Boardly"

errors: list[str] = []

# 1. Catalog completeness
catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
for key, entry in catalog["strings"].items():
    if not key:
        continue
    state = entry.get("extractionState")
    if state in ("stale", "needs_review"):
        errors.append(f"catalog: {key!r} is '{state}'")
    if "fr" not in entry.get("localizations", {}):
        errors.append(f"catalog: {key!r} has no French translation")

# 2. Divergent source patterns
ANTI_PATTERNS = [
    (re.compile(r"Text\(\s*[A-Za-z_][\w.]*\.rawValue\s*\)"),
     "Text(x.rawValue) — display a localizedName, not the raw value"),
    (re.compile(r"Text\(\s*[A-Za-z_][\w.]*\.label\s*\)"),
     "Text(x.label) — use a LocalizedStringResource localizedName"),
    (re.compile(r'\?\s*"s"\s*:\s*""|\?\s*""\s*:\s*"s"'),
     'inline +"s" plural hack — use a String Catalog plural (one/other)'),
]
for path in sorted(APP_SOURCES.rglob("*.swift")):
    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        for pattern, message in ANTI_PATTERNS:
            if pattern.search(line):
                errors.append(f"{path.relative_to(ROOT)}:{lineno}: {message}")

if errors:
    print("Localization guard FAILED:", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)
    sys.exit(1)

print(f"Localization guard passed ({len(catalog['strings'])} catalog keys, all localized).")
