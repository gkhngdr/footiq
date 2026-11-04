#!/bin/bash
# Claude işi bitirmeden önce: Dart dosyası değiştiyse flutter analyze çalıştır.
# Hata/uyarı varsa (exit 2) Claude düzeltmeye devam eder.
cd "$CLAUDE_PROJECT_DIR" || exit 0
if git status --porcelain -- '*.dart' | grep -q .; then
  out=$(flutter analyze --no-pub 2>&1)
  if [ $? -ne 0 ]; then
    echo "$out" | tail -40 1>&2
    exit 2
  fi
fi
exit 0
