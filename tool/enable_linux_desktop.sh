#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT"

flutter config --enable-linux-desktop
flutter create --platforms=linux .
flutter pub get
flutter analyze
flutter test

echo "Linux desktop platform is ready. Run: flutter run -d linux"
