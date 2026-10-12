#!/bin/bash
# 第7回ハンズオン 環境準備スクリプト（Raspberry Pi OS 64bit 用：Pi 4 / Pi 5 推奨）
# 使い方: このリポジトリのフォルダ（files/ がある場所）で
#   bash setup_pi.sh
set -eu

HANDSON_DIR="$HOME/crypto-handson"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

info() { echo -e "\n\033[1;34m[setup] $*\033[0m"; }
warn() { echo -e "\033[1;33m[注意] $*\033[0m"; }
fail() { echo -e "\033[1;31m[エラー] $*\033[0m"; exit 1; }

# ---- 0. 前提チェック ----
[ "$(id -u)" -ne 0 ] || fail "root ではなく、普段のユーザーで実行してください（sudo は中で使います）"
. /etc/os-release
[ "${ID:-}" = "debian" ] || [ "${ID:-}" = "raspbian" ] || fail "Raspberry Pi OS（Debian 系）用です（検出: ${PRETTY_NAME:-不明}）"
ARCH="$(dpkg --print-architecture)"
case "$ARCH" in
  arm64) ;;
  armhf) warn "32bit 版 OS です。64bit 版（arm64）を推奨します（Docker は 32bit 版でも動く想定）";;
  *) warn "想定外のアーキテクチャです: $ARCH";;
esac
MEM_MB=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo)
[ "$MEM_MB" -ge 900 ] || warn "メモリが ${MEM_MB}MB です。1GB 以上を推奨します"
[ -d "$SRC_DIR/files" ] || fail "$SRC_DIR/files が見つかりません。このリポジトリのフォルダ（files/ がある場所）で実行してください"

if [ "$(cat /proc/1/comm 2>/dev/null)" = "systemd" ]; then USE_SYSTEMD=1; else USE_SYSTEMD=0; fi
start_service() {  # $1 = サービス名
  if [ "$USE_SYSTEMD" = 1 ]; then sudo systemctl enable --now "$1"; else sudo service "$1" start; fi
}

info "sudo のパスワードを聞かれたら、Pi のユーザーのパスワードを入力してください"
sudo -v

# ---- 1. 基本ツール ----
info "1/5 基本ツールをインストール（openssl / ssh / curl / xxd）"
sudo apt-get update -y
XXD_PKG=vim-common; apt-cache show xxd >/dev/null 2>&1 && XXD_PKG=xxd
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  openssl openssh-client openssh-server curl ca-certificates gnupg "$XXD_PKG"

# ---- 2. sshd（2時間目 ssh-copy-id / ssh localhost 用）----
info "2/5 SSH サーバーを設定・起動"
sudo ssh-keygen -A >/dev/null
echo "PasswordAuthentication yes" | sudo tee /etc/ssh/sshd_config.d/50-handson.conf >/dev/null
sudo mkdir -p /run/sshd
start_service ssh

# ---- 3. Docker（5・6時間目用）----
info "3/5 Docker を準備"
if ! dpkg -s docker-ce >/dev/null 2>&1; then
  # 公式手順: https://docs.docker.com/engine/install/debian/ （32bit は /raspbian/）
  for p in docker.io docker-doc docker-compose podman-docker containerd runc; do
    sudo apt-get remove -y "$p" >/dev/null 2>&1 || true
  done
  sudo install -m 0755 -d /etc/apt/keyrings
  if [ "$ARCH" = "armhf" ]; then DOCKER_OS=raspbian; else DOCKER_OS=debian; fi
  sudo curl -fsSL "https://download.docker.com/linux/${DOCKER_OS}/gpg" -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${DOCKER_OS} ${VERSION_CODENAME} stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -y
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
start_service docker
sudo usermod -aG docker "$(id -un)"

# ---- 4. ハンズオンファイル ----
info "4/5 ハンズオンファイルを $HANDSON_DIR/files に配置"
mkdir -p "$HANDSON_DIR"
if [ -d "$HANDSON_DIR/files" ]; then
  mv "$HANDSON_DIR/files" "$HANDSON_DIR/files.bak.$(date +%Y%m%d%H%M%S)"
fi
cp -r "$SRC_DIR/files" "$HANDSON_DIR/files"
find "$HANDSON_DIR/files" -type f \( -name '*.sh' -o -name '*.cnf' -o -name '*.conf' -o -name '*.yml' -o -name 'Dockerfile' \) \
  -exec sed -i 's/\r$//' {} +

# 当日の待ち時間を減らすためイメージを先に取得
for img in nginx:1.27-alpine alpine:3.20; do
  sudo docker pull -q "$img" >/dev/null 2>&1 || warn "$img の事前取得に失敗しました（当日の docker compose up / build で自動取得されます）"
done

# ---- 5. 確認 ----
info "5/5 確認"
openssl version
ssh -V 2>&1
sudo docker --version
sudo docker compose version
if command -v ss >/dev/null && ss -ltn | grep -qE ':(80|443)\s'; then
  warn "80 / 443 番ポートを使っているプロセスがあります。5時間目の前に止めてください"
  ss -ltnp 2>/dev/null | grep -E ':(80|443)\s' || true
fi

cat <<MSG

==================== 準備完了 ====================
・ハンズオンの作業場所: $HANDSON_DIR
・ssh-copy-id のパスワード = この Pi のユーザーのパスワード

【必ず】docker を sudo なしで使えるように、一度ログインし直してください:
    デスクトップならログアウト→ログイン（または sudo reboot）、SSH なら exit → 再接続
MSG
if [ "$USE_SYSTEMD" = 0 ]; then
cat <<MSG

【注意】systemd が無効な環境なので、再起動後は、SSH と Docker が自動では起動しません。
次を実行してください:
    sudo service ssh start; sudo service docker start
MSG
fi
