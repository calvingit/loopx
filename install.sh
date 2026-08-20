#!/usr/bin/env bash
set -euo pipefail

# loopx 安装脚本
#
# 设计目标：
# 1. 不自动安装第三方依赖，只检查并提示缺失的 tmux / codex。
# 2. PREFIX 未指定时，优先安装到可写的 /usr/local/bin，否则回退到 ~/.local/bin。
# 3. 下载到临时文件后先执行 bash -n，再通过同目录临时文件 + mv 原子替换目标文件。
# 4. 安装完成后执行 loopx --help 做最小可执行性验证，并检查 PATH。

REPO="calvingit/loopx"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
SOURCE_URL="${RAW_BASE}/loopx"

info() { printf '[loopx] %s\n' "$*"; }
warn() { printf '[loopx] 警告：%s\n' "$*" >&2; }
die() { printf '[loopx] 错误：%s\n' "$*" >&2; exit 1; }

case "$(uname -s)" in
  Darwin|Linux) ;;
  *) die "当前仅支持 macOS 和 Linux。" ;;
esac

command -v bash >/dev/null 2>&1 || die "未找到 bash。"

choose_install_dir() {
  if [ -n "${PREFIX:-}" ]; then
    printf '%s/bin\n' "${PREFIX%/}"
    return
  fi

  if [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then
    printf '%s\n' /usr/local/bin
    return
  fi

  printf '%s/.local/bin\n' "$HOME"
}

INSTALL_DIR="$(choose_install_dir)"
TARGET="${INSTALL_DIR}/loopx"

if [ ! -d "$INSTALL_DIR" ]; then
  mkdir -p "$INSTALL_DIR" 2>/dev/null || die "无法创建安装目录：$INSTALL_DIR。可通过 PREFIX 指定其他目录。"
fi

[ -w "$INSTALL_DIR" ] || die "安装目录不可写：$INSTALL_DIR。可通过 PREFIX 指定其他目录。"

TMP_FILE="$(mktemp "${TMPDIR:-/tmp}/loopx.XXXXXX")"
TARGET_TMP="${TARGET}.tmp.$$"
cleanup() {
  rm -f "$TMP_FILE" "$TARGET_TMP"
}
trap cleanup EXIT INT TERM

download() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 10 "$SOURCE_URL" -o "$TMP_FILE"
  elif command -v wget >/dev/null 2>&1; then
    wget -q --timeout=10 --tries=3 -O "$TMP_FILE" "$SOURCE_URL"
  else
    die "需要 curl 或 wget 来下载 loopx。"
  fi
}

info "下载 ${SOURCE_URL}"
download

[ -s "$TMP_FILE" ] || die "下载结果为空。"
head -n 1 "$TMP_FILE" | grep -q '^#!/usr/bin/env bash$' || die "下载内容不是预期的 loopx 脚本。"
bash -n "$TMP_FILE" || die "下载的 loopx 未通过 bash 语法检查。"

cp "$TMP_FILE" "$TARGET_TMP"
chmod 755 "$TARGET_TMP"
mv -f "$TARGET_TMP" "$TARGET"

"$TARGET" --help >/dev/null || die "安装后的 loopx 无法正常执行 --help。"

info "已安装到：$TARGET"

case ":${PATH}:" in
  *":${INSTALL_DIR}:"*) ;;
  *) warn "$INSTALL_DIR 不在 PATH 中，请将它加入 PATH。" ;;
esac

missing=()
command -v tmux >/dev/null 2>&1 || missing+=(tmux)
command -v codex >/dev/null 2>&1 || missing+=(codex)

if [ "${#missing[@]}" -gt 0 ]; then
  warn "缺少运行依赖：${missing[*]}。loopx 已安装，但使用前需要先安装这些依赖。"
else
  info "依赖检查通过：tmux、codex"
fi

info "验证命令：loopx --help"
