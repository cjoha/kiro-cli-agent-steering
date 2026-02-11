#!/bin/bash
# Guard script for steering-generator agent.
# Called as a preToolUse hook on fs_write.
# Reads the tool input JSON from stdin, extracts the target path,
# and exits non-zero if the file already exists (blocking the write).

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('path',''))" 2>/dev/null)

if [ -z "$FILE_PATH" ]; then
  echo "ERROR: Could not determine target file path. Write blocked for safety."
  exit 1
fi

if [ -f "$FILE_PATH" ]; then
  echo "BLOCKED: '$FILE_PATH' already exists. This agent cannot overwrite existing steering files. Please rename or remove the existing file first, or use a different filename."
  exit 1
fi

echo "OK: '$FILE_PATH' does not exist. Write permitted."
exit 0
