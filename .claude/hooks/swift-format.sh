#!/bin/bash
# PostToolUse hook (Edit|Write) — auto-formats/lints Swift files after Claude edits them.
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ "$FILE" != *.swift ]] && exit 0

if [ -f ".swiftformat" ] && command -v swiftformat &>/dev/null; then
  swiftformat "$FILE" 2>/dev/null || true
fi

if [ -f ".swiftlint.yml" ] && command -v swiftlint &>/dev/null; then
  swiftlint --fix --path "$FILE" 2>/dev/null || true
fi

exit 0
