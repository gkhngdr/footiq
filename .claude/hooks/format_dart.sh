#!/bin/bash
# Bir .dart dosyası düzenlenince dart format uygula.
f=$(jq -r '.tool_input.file_path // empty')
case "$f" in
  *.dart) [ -f "$f" ] && dart format "$f" >/dev/null 2>&1 ;;
esac
exit 0
