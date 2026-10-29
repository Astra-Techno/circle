#!/usr/bin/env bash
# Run from any directory. Uses the existing private Android signing identity.
set -euo pipefail
CIRCLE_REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$CIRCLE_REPO_DIR/mobile"
flutter build apk --release \
  --dart-define=CIRCLE_API_BASE_URL=https://circle.cloudkart24.com/api/v1 \
  --dart-define=CIRCLE_PUSH_ENABLED=true
