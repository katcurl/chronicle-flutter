#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
ROOT="$(cd "$ROOT" && pwd)"

if [[ ! -f "$ROOT/pubspec.yaml" ]]; then
  echo "Chronicle Flutter project not found: $ROOT" >&2
  exit 66
fi

cd "$ROOT"
flutter create --platforms=windows,linux .

echo
echo "Desktop platform hosts are ready."
echo "Linux:  flutter run -d linux"
echo "Windows builds must run on Windows or a Windows GitHub Actions runner."
