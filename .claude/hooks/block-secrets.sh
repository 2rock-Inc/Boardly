#!/bin/bash
# PreToolUse hook (Edit|Write) — blocks Claude from touching known secret files.
# Exit code 2 blocks the action and returns this message to Claude.
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

PROTECTED_PATTERNS=(
  ".env"
  "Secrets.swift"
  "GoogleService-Info.plist"
  ".xcconfig"
  ".pem"
  ".p12"
  ".key"
  "credentials"
)

for pattern in "${PROTECTED_PATTERNS[@]}"; do
  if [[ "$FILE" == *"$pattern"* ]]; then
    echo "Blocked: '$FILE' matches protected pattern '$pattern'. Secrets must be entered manually, never read/written by Claude." >&2
    exit 2
  fi
done

exit 0
