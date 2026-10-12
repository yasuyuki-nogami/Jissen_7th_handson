#!/bin/bash
# 演習用CA: CSRへ署名してサーバー証明書を発行するスクリプト
# 使い方（コンテナ内で実行）:
#   /ca/sign.sh /work/server.csr /work/server.crt
set -eu

CSR=${1:?usage: sign.sh <csr> <out-crt>}
OUT=${2:?usage: sign.sh <csr> <out-crt>}

CA_KEY=/ca/ca.key
CA_CRT=/ca/ca.crt

# --- 初回のみ: CA自身の鍵と自己署名証明書（Root CA証明書）を作る ---
if [ ! -f "$CA_KEY" ]; then
    echo "[CA] CA秘密鍵とCA証明書を新規作成します"
    openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 \
        -out "$CA_KEY"
    openssl req -x509 -new -key "$CA_KEY" \
        -days 365 -sha256 \
        -config /ca/openssl-ca.cnf \
        -out "$CA_CRT"
    # 受講者が取得できるよう、CA証明書を共有ディレクトリへも置く
    cp "$CA_CRT" /work/ca.crt
    echo "[CA] CA証明書を /work/ca.crt へ配置しました"
fi

# --- CSRへ署名してサーバー証明書を発行 ---
echo "[CA] CSRの内容:"
openssl req -in "$CSR" -noout -subject

openssl x509 -req -in "$CSR" \
    -CA "$CA_CRT" -CAkey "$CA_KEY" -CAcreateserial \
    -days 90 -sha256 \
    -extfile /ca/openssl-ca.cnf -extensions server_cert \
    -out "$OUT"

echo "[CA] 署名しました -> $OUT"
openssl x509 -in "$OUT" -noout -subject -issuer -dates
