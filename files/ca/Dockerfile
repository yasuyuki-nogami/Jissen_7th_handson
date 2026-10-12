# 演習用の簡易CA（認証局）コンテナ
# OpenSSL 3.x が入った最小イメージ
FROM alpine:3.20

RUN apk add --no-cache openssl bash

WORKDIR /ca
COPY openssl-ca.cnf /ca/openssl-ca.cnf
COPY sign.sh /ca/sign.sh
# Windows上で編集された場合のCRLF改行コードを除去してから実行権付与
RUN sed -i 's/\r$//' /ca/sign.sh /ca/openssl-ca.cnf && chmod +x /ca/sign.sh

# CSRの受け渡し用ディレクトリ（ホストとボリューム共有する）
VOLUME ["/work"]

CMD ["sleep", "infinity"]
