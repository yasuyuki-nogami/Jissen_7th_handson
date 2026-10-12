# 第7回ハンズオン：暗号・電子署名・HTTPS

このディレクトリは、第7回（6時間）のハンズオンを
**上から順にコマンドを実行すればなぞれる**ように作成したコマンド集です。

## ファイル構成

```
第7回ハンズオン/
├── README.md              … このファイル
├── 01_共通鍵暗号.md
├── 02_公開鍵暗号とSSH鍵.md
├── 03_ハッシュ.md
├── 04_電子署名.md
├── 05_証明書とPKI.md
├── 06_TLS_HTTPS.md
└── files/
    ├── ca/
    │   ├── Dockerfile          … 簡易CAコンテナ
    │   ├── openssl-ca.cnf      … CA用OpenSSL設定
    │   └── sign.sh             … CSRに署名するスクリプト
    ├── nginx/                  … 演習用Webサーバー（Dockerで起動）
    │   ├── docker-compose.yml
    │   ├── conf.d/
    │   │   ├── handson-http.conf   … HTTP(80)設定
    │   │   └── handson-ssl.conf    … HTTPS(443)設定
    │   ├── html/index.html         … 演習用ページ
    │   ├── extra/handson-redirect.conf … 6時間目のリダイレクト用
    │   └── ssl/                    … 証明書置き場（演習中に作成）
    └── san.cnf                 … SAN付きCSR用設定
```

## 前提環境

- Ubuntu 22.04 / 24.04 の Linux VM（一般ユーザー + sudo可）
- インストール済みであること:
  - openssl / openssh-client / openssh-server
  - docker（`docker compose` が使えること）
  - curl
- Webサーバー（Nginx）はDockerコンテナとして起動するため、
  VMへのNginxインストールは不要です。
  **VM側で80/443番ポートを使うサービスが動いていないこと**を確認してください。
  （もし素のNginx等が動いていたら `sudo systemctl stop nginx` で停止）
- 事前確認コマンド:

```bash
openssl version
ssh -V
docker --version
docker compose version
curl --version | head -1
```

## 進め方

- 各MDファイルの先頭から順にコマンドを実行してください。
- 各ステップは「目的 → コマンド → 確認ポイント」で構成しています。
- 作業ディレクトリは各時間の冒頭で `~/crypto-handson/NN_xxx` を作成して使います。
- 5時間目・6時間目は `files/` 以下の設定ファイルを使用します。
  事前にVMへこのディレクトリ一式をコピーしておいてください。

## 注意（改行コード）

WindowsからVMへファイルをコピーした場合、改行コードがCRLFになり
スクリプトや設定ファイルが正しく動かないことがあります。
VM側で以下を一度実行しておくと安全です。

```bash
find ~/crypto-handson/files -type f \( -name '*.sh' -o -name '*.cnf' -o -name '*.conf' \) \
  -exec sed -i 's/\r$//' {} +
```

（Docker CAコンテナ内のファイルはDockerfile側でCRLF除去済み）

## 注意

- 秘密鍵（`*.key`, `id_ed25519` など）は**絶対に他人へ渡さない・画面共有で表示しない**こと。
- 本演習のCAはVM内の学習用です。実運用では外部の信頼できるCAを使います。
- 演習終了後、信頼ストアへ登録したCA証明書は削除してください（05の最後に手順あり）。
