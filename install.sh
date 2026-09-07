#!/usr/bin/env bash
# weshp-order skill install/update script (macOS / Linux)
#
# Usage:
#   1. Install from the remote repository: bash install.sh   (clones automatically when not run inside a repo)
#   2. Install from within the repository:  bash install.sh
#   3. Use a custom repository:             WESHP_REPO_URL=<git-url> bash install.sh
set -euo pipefail

REPO_URL="${WESHP_REPO_URL:-https://github.com/hewen499/weshp-order.git}"
SKILL_NAME="weshp-order"
TARGET_DIR="${HOME}/.claude/skills/${SKILL_NAME}"

log() { echo "[weshp-order] $*"; }
die() { echo "[weshp-order][error] $*" >&2; exit 1; }

# ---------- 1. Locate the skill source: prefer the directory this script lives in, otherwise clone to a temp dir ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/SKILL.md" ]; then
  SRC_DIR="${SCRIPT_DIR}"
  log "Installing from: ${SRC_DIR}"
else
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "${TMP_DIR}"' EXIT
  log "Cloning repository: ${REPO_URL}"
  git clone --depth 1 "${REPO_URL}" "${TMP_DIR}" \
    || die "Clone failed. Check your network and repository permissions, or specify one: WESHP_REPO_URL=<git-url> bash install.sh"
  SRC_DIR="${TMP_DIR}"
  [ -f "${SRC_DIR}/SKILL.md" ] || SRC_DIR="${TMP_DIR}/skills/${SKILL_NAME}"
  [ -f "${SRC_DIR}/SKILL.md" ] || die "Skill not found in the repository; please verify the repository URL"
fi

# ---------- 2. Detect the runtime platform ----------
case "$(uname -sm)" in
  "Darwin arm64")   BIN="weshp-cli-darwin-arm64" ;;
  "Darwin x86_64")  BIN="weshp-cli-darwin-amd64" ;;
  "Linux x86_64")   BIN="weshp-cli-linux-amd64" ;;
  *) die "Unsupported platform: $(uname -sm) (see README.md for manual installation on Windows)" ;;
esac

# ---------- 3. Install files (overwriting update; user profile files profile.json / profiles/ are preserved) ----------
mkdir -p "${TARGET_DIR}/bin"
cp "${SRC_DIR}/SKILL.md" "${TARGET_DIR}/SKILL.md"
cp "${SRC_DIR}/bin/"* "${TARGET_DIR}/bin/"
if [ -f "${SRC_DIR}/README.md" ]; then
  cp "${SRC_DIR}/README.md" "${TARGET_DIR}/README.md"
fi
chmod +x "${TARGET_DIR}/bin/"*

# macOS: remove the quarantine attribute from downloaded files so Gatekeeper does not block the binary
if [ "$(uname)" = "Darwin" ] && command -v xattr >/dev/null 2>&1; then
  xattr -dr com.apple.quarantine "${TARGET_DIR}" 2>/dev/null || true
fi

# ---------- 4. Verify the installation ----------
if "${TARGET_DIR}/bin/${BIN}" --help >/dev/null 2>&1; then
  log "Install/update completed: ${TARGET_DIR}"
  log "Restart your Claude Code session, then invoke the skill with /weshp-order."
else
  die "Binary verification failed. Please check ${TARGET_DIR}/bin/${BIN}"
fi
