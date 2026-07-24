#!/usr/bin/env bash
# One-shot AgentBoard dev setup (macOS only).
# Installs required tooling, regenerates the Xcode project, and installs git hooks.
# Usage: ./scripts/setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "❌ AgentBoard builds only on macOS with Xcode 26.4. Detected: $(uname -s)."
    exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "❌ xcodebuild not found. Install Xcode 26.4+ and run: sudo xcode-select -s /Applications/Xcode.app"
    exit 1
fi

echo "==> Xcode: $(xcodebuild -version | head -1)"

if ! command -v brew >/dev/null 2>&1; then
    echo "❌ Homebrew not found. Install from https://brew.sh then re-run."
    exit 1
fi

echo "==> Installing tooling (xcodegen, swiftlint)"
brew install xcodegen swiftlint

echo "==> Generating Xcode project from project.yml"
xcodegen generate

echo "==> Installing git hooks"
"$SCRIPT_DIR/install-hooks.sh"

echo ""
echo "✓ Setup complete. Next:"
echo "  Build:  xcodebuild -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' -derivedDataPath ./DerivedData build CODE_SIGN_IDENTITY=\"\" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO"
echo "  Test:   xcodebuild test -project AgentBoard.xcodeproj -scheme AgentBoard -destination 'platform=macOS' -derivedDataPath ./DerivedData -only-testing:AgentBoardTests CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO"
echo "  Lint:   swiftlint --strict"
