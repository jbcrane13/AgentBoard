#!/usr/bin/env bash
# Install git hooks for AgentBoard
# Usage: ./scripts/install-hooks.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

echo "Installing git hooks..."

# Copy the pre-commit-quality hook
cp "$SCRIPT_DIR/pre-commit-quality" "$HOOKS_DIR/pre-commit-quality"
chmod +x "$HOOKS_DIR/pre-commit-quality"

# Copy the pre-push-quality hook
cp "$SCRIPT_DIR/pre-push-quality" "$HOOKS_DIR/pre-push-quality"
chmod +x "$HOOKS_DIR/pre-push-quality"

# Update the main pre-commit hook to chain quality checks
if grep -q "pre-commit-quality" "$HOOKS_DIR/pre-commit" 2>/dev/null; then
    echo "  pre-commit already chains quality hooks"
else
    cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/usr/bin/env sh
# AgentBoard pre-commit hook
# Runs: quality checks (SwiftLint + SwiftFormat)

HOOK_DIR="$(dirname "$0")"

if [ -f "$HOOK_DIR/pre-commit-quality" ]; then
    "$HOOK_DIR/pre-commit-quality" "$@" || exit 1
fi
EOF
    chmod +x "$HOOKS_DIR/pre-commit"
    echo "  Updated pre-commit hook"
fi

# Update the main pre-push hook to chain quality checks
if grep -q "pre-push-quality" "$HOOKS_DIR/pre-push" 2>/dev/null; then
    echo "  pre-push already chains quality hooks"
else
    cat > "$HOOKS_DIR/pre-push" << 'EOF'
#!/usr/bin/env sh
# AgentBoard pre-push hook
# Runs: build verification

HOOK_DIR="$(dirname "$0")"

if [ -f "$HOOK_DIR/pre-push-quality" ]; then
    "$HOOK_DIR/pre-push-quality" "$@" || exit 1
fi
EOF
    chmod +x "$HOOKS_DIR/pre-push"
    echo "  Updated pre-push hook"
fi

echo "✓ Git hooks installed"
echo ""
echo "Pre-commit runs: SwiftLint → SwiftFormat"
echo "Pre-push runs: build verification"