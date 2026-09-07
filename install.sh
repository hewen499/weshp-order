#!/usr/bin/env bash
# weshp-order 技能一键安装/更新脚本（macOS / Linux）
#
# 用法：
#   1. 从远程仓库安装：bash install.sh            （脚本不在仓库内时自动克隆）
#   2. 在仓库内安装：  bash skills/weshp-order/install.sh
#   3. 指定仓库地址：  WESHP_REPO_URL=<git地址> bash install.sh
set -euo pipefail

REPO_URL="${WESHP_REPO_URL:-https://github.com/hewen499/weshp-order.git}"
SKILL_NAME="weshp-order"
TARGET_DIR="${HOME}/.claude/skills/${SKILL_NAME}"

log() { echo "[weshp-order] $*"; }
die() { echo "[weshp-order][错误] $*" >&2; exit 1; }

# ---------- 1. 定位技能源目录：优先使用脚本所在仓库，否则临时克隆 ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/SKILL.md" ]; then
  SRC_DIR="${SCRIPT_DIR}"
  log "使用脚本所在目录作为安装源：${SRC_DIR}"
else
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "${TMP_DIR}"' EXIT
  log "克隆仓库：${REPO_URL}"
  git clone --depth 1 "${REPO_URL}" "${TMP_DIR}" 2>/dev/null \
    || die "克隆失败，请检查网络与仓库权限；也可用环境变量指定仓库：WESHP_REPO_URL=<git地址> bash install.sh"
  SRC_DIR="${TMP_DIR}"
  [ -f "${SRC_DIR}/SKILL.md" ] || SRC_DIR="${TMP_DIR}/skills/${SKILL_NAME}"
  [ -f "${SRC_DIR}/SKILL.md" ] || die "仓库中未找到 ${SKILL_NAME} 技能，请确认仓库地址是否正确"
fi

# ---------- 2. 探测运行平台 ----------
case "$(uname -sm)" in
  "Darwin arm64")   BIN="weshp-cli-darwin-arm64" ;;
  "Darwin x86_64")  BIN="weshp-cli-darwin-amd64" ;;
  "Linux x86_64")   BIN="weshp-cli-linux-amd64" ;;
  *) die "不支持的平台：$(uname -sm)（Windows 请参考 README.md 手动安装）" ;;
esac

# ---------- 3. 安装文件（覆盖式更新，保留用户记忆文件 profile.json / profiles/）----------
mkdir -p "${TARGET_DIR}/bin"
cp "${SRC_DIR}/SKILL.md" "${TARGET_DIR}/SKILL.md"
cp "${SRC_DIR}/bin/"* "${TARGET_DIR}/bin/"
if [ -f "${SRC_DIR}/README.md" ]; then
  cp "${SRC_DIR}/README.md" "${TARGET_DIR}/README.md"
fi
chmod +x "${TARGET_DIR}/bin/"*

# macOS：清除网络下载带来的隔离标记，避免 Gatekeeper 拦截二进制执行
if [ "$(uname)" = "Darwin" ] && command -v xattr >/dev/null 2>&1; then
  xattr -dr com.apple.quarantine "${TARGET_DIR}" 2>/dev/null || true
fi

# ---------- 4. 验证安装结果 ----------
if "${TARGET_DIR}/bin/${BIN}" --help >/dev/null 2>&1; then
  log "安装/更新完成：${TARGET_DIR}"
  log "重启 Claude Code 会话后，即可通过 /weshp-order 使用。"
else
  die "二进制验证失败，请检查 ${TARGET_DIR}/bin/${BIN}"
fi
