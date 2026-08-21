#!/bin/bash
#
# Build a self-contained AgentBoard Companion bundle that can be copied to and
# installed on any Mac — no Xcode, no toolchain, no repo checkout required on
# the target.
#
# Why this exists: AgentBoardCompanion is a `type: tool` target that links
# @rpath/AgentBoardCompanionKit.framework and @rpath/AgentBoardCore.framework,
# so the bare executable cannot run anywhere but the build machine. The binary
# already carries an @executable_path/../Frameworks rpath, so laying the
# frameworks out one level up from bin/ resolves them with no install_name_tool
# surgery.
#
# Usage:  scripts/package-companion.sh [output-dir]
# Output: <output-dir>/agentboard-companion.tar.gz
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-$REPO_ROOT/dist}"
STAGE="$OUT_DIR/agentboard-companion"
SCHEME="AgentBoardCompanion"

echo "==> Building $SCHEME (Release)"
DERIVED="$(mktemp -d)"
trap 'rm -rf "$DERIVED"' EXIT

xcodebuild \
    -project "$REPO_ROOT/AgentBoard.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED" \
    CODE_SIGN_IDENTITY='-' \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build >/dev/null

PRODUCTS="$DERIVED/Build/Products/Release"
BIN="$PRODUCTS/AgentBoardCompanion"

if [[ ! -x "$BIN" ]]; then
    echo "error: built binary not found at $BIN" >&2
    exit 1
fi

echo "==> Staging bundle"
rm -rf "$STAGE"
mkdir -p "$STAGE/bin" "$STAGE/Frameworks"
cp "$BIN" "$STAGE/bin/"

# Copy the exact @rpath framework closure. Verified: AgentBoardCompanionKit and
# AgentBoardCore, and Core links nothing further outside /usr/lib and /System.
for fw in AgentBoardCompanionKit AgentBoardCore; do
    src="$PRODUCTS/$fw.framework"
    if [[ ! -d "$src" ]]; then
        src="$PRODUCTS/PackageFrameworks/$fw.framework"
    fi
    if [[ ! -d "$src" ]]; then
        echo "error: $fw.framework not found under $PRODUCTS" >&2
        exit 1
    fi
    cp -R "$src" "$STAGE/Frameworks/"
done

cp "$REPO_ROOT/scripts/companion-install.sh" "$STAGE/install.sh"
chmod +x "$STAGE/install.sh" "$STAGE/bin/AgentBoardCompanion"

# Static closure check. Never *run* the binary here: the companion has no
# --help, it binds its port and loops forever, so executing it would hang the
# build and scribble state on the build machine.
echo "==> Verifying the staged @rpath closure"
verify_rpath_deps() {
    local macho="$1"
    otool -L "$macho" 2>/dev/null | awk '/@rpath\//{print $1}' | while read -r dep; do
        local rel="${dep#@rpath/}"
        local fw="${rel%%.framework/*}"
        if [[ ! -f "$STAGE/Frameworks/$fw.framework/Versions/A/$fw" ]]; then
            echo "error: $(basename "$macho") needs $fw.framework, missing from bundle" >&2
            exit 1
        fi
    done
}

verify_rpath_deps "$STAGE/bin/AgentBoardCompanion"
for fw in "$STAGE"/Frameworks/*.framework; do
    name="$(basename "$fw" .framework)"
    verify_rpath_deps "$fw/Versions/A/$name"
done

if ! otool -l "$STAGE/bin/AgentBoardCompanion" | grep -q "@executable_path/../Frameworks"; then
    echo "error: binary lacks the @executable_path/../Frameworks rpath the layout relies on" >&2
    exit 1
fi

echo "==> Creating tarball"
tar -czf "$OUT_DIR/agentboard-companion.tar.gz" -C "$OUT_DIR" agentboard-companion

echo
echo "Bundle: $OUT_DIR/agentboard-companion.tar.gz"
echo
echo "Install on the machine that runs Hermes:"
echo "  scp $OUT_DIR/agentboard-companion.tar.gz <host>:~/"
echo "  ssh <host> 'tar -xzf agentboard-companion.tar.gz && ./agentboard-companion/install.sh'"
