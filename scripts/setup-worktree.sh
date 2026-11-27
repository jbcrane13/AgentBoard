#!/usr/bin/env bash
# Prepare an AgentBoard worktree: check the tools the repo needs, then enable the codex-review
# gate. Rerunnable and noninteractive. It never installs tools, regenerates the committed Xcode
# project, builds, runs tests, touches credentials, changes branches, or pulls or pushes.
#
# AgentBoard.xcodeproj is generated from project.yml but committed, and a fresh checkout already
# has it. Regenerating it here can rewrite tracked files when the local XcodeGen differs from the
# one that wrote them, so setup leaves it alone: run `xcodegen generate` after editing project.yml
# and commit the result.
set -euo pipefail

fail() {
  printf 'setup-worktree: %s\n' "$*" >&2
  exit 1
}

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

missing_tools=()
for tool in xcodebuild xcodegen swiftlint swiftformat; do
  command -v "$tool" >/dev/null 2>&1 || missing_tools+=("$tool")
done
if [ "${#missing_tools[@]}" -gt 0 ]; then
  echo "Install Xcode, then run: brew install xcodegen swiftlint swiftformat" >&2
  fail "missing required tools: ${missing_tools[*]}"
fi

# The automated codex-review gate must be active in every worktree. The shared script lives
# outside the repo; SKIP_REVIEW_GATE=1 skips it on hosts without Codex.
gate_script="$HOME/.claude/scripts/enable-review-gate.sh"
if [ "${SKIP_REVIEW_GATE:-0}" = 1 ]; then
  printf 'setup-worktree: skipping the codex-review gate (SKIP_REVIEW_GATE=1)\n'
elif [ -x "$gate_script" ]; then
  "$gate_script" "$repo_root"
else
  fail "missing $gate_script, which enables the codex-review gate; restore it or set SKIP_REVIEW_GATE=1 on a host without Codex"
fi

printf 'setup-worktree: ready. Next: swiftlint lint --strict; run xcodegen generate after any project.yml edit\n'
