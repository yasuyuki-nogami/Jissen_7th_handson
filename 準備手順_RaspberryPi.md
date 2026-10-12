# 第7回ハンズオン Raspberry Pi 版 準備手順

## 推奨構成

- Raspberry Pi 4 / Pi 5（メモリ 2GB 以上を推奨。1GB でも動く想定〔未検証〕）
- **Raspberry Pi OS（64bit）**。デスクトップ版にしておくと、5時間目のブラウザの警告を Pi 上で体験できる
- microSD 16GB 以上、ネットワーク接続（Docker とイメージの取得に必要）

## 講師側の準備（SD カード1枚を作って複製する場合）

1. Raspberry Pi Imager で Raspberry Pi OS（64bit）を書き込む。Imager の詳細設定で、ユーザー名・パスワードを決めて **SSH を有効化** しておくと楽
2. Pi を起動し、リポジトリをホームに clone して setup を実行する
   ```bash
   sudo apt-get update && sudo apt-get install -y git
   cd ~ && git clone https://github.com/yasuyuki-nogami/Jissen_7th_handson.git
   cd Jissen_7th_handson
   bash setup_pi.sh
   sudo reboot
   ```
3. 再起動後、`docker ps` が sudo なしで動くことを確認する
4. この SD カードを台数分複製する（Win32 Disk Imager や `dd` などでイメージを吸い出して書き込む）

> 複製すると、全台の SSH ホスト鍵が同じになる。2時間目で使うのは localhost への接続だけなので演習には影響しない。ただ気になる場合は、各 Pi で `sudo rm /etc/ssh/ssh_host_* && sudo ssh-keygen -A && sudo systemctl restart ssh` を実行するとホスト鍵を作り直せる。

受講者に1台ずつ素の OS から setup させる場合は、2〜3 を受講者が自分でやる。

## setup_pi.sh がやること

WSL 版とほぼ同じ。違いは次のとおり。

| 項目 | 内容 |
|---|---|
| 前提チェック | Raspberry Pi OS（Debian 系）であること、64bit 版（arm64）か、メモリ 1GB 以上か |
| Docker | Docker 公式の **Debian 用** リポジトリから入れる（32bit 版 OS なら Raspbian 用） |
| sshd | パスワード認証を有効化して `systemctl enable --now ssh` で起動する。Pi OS は初期状態だと SSH が無効なので |
| その他 | 基本ツールのインストール、docker グループへの追加、ハンズオンファイルの配置と CRLF 変換、イメージの事前取得は WSL 版と同じ |

## 検証結果（こちらの環境）

Pi の実機は用意できなかったので、x86 の VM 上で **arm64 エミュレーション（QEMU）** を使い、Debian 12（bookworm, arm64）のコンテナで確認した。

| 確認したこと | 結果 |
|---|---|
| setup_pi.sh（Debian 12 arm64、systemd なし） | ✅ 正常終了（基本ツール、sshd、Docker 公式 Debian リポジトリからのインストール、docker グループ、ファイル配置） |
| CA コンテナ（alpine:3.20 arm64）のビルドと CA 署名 | ✅ 自動で Root CA を作成し、署名後の `openssl verify` が OK（エミュレーションで約8秒） |
| Nginx（nginx:1.27-alpine arm64） | ✅ `nginx -t` OK、TLS 1.3 / TLS_AES_256_GCM_SHA384、`SSL certificate verify ok` |
| 6時間目のリダイレクト（手順書どおり handson-http.conf を置き換え） | ✅ 301 → https://localhost/ |
| 1〜4時間目（openssl / ssh / sha256sum） | Pi でも同じパッケージで動くので、WSL 版（Ubuntu）での確認で代用 |

- エミュレーションの限界：arm64 コンテナの**中で** Docker デーモンを動かすと、QEMU 上でクラッシュした（Pi の問題ではなく QEMU の制約）。なので Docker 部分は、「setup_pi.sh で Docker のインストールと起動まで通ること」と「arm64 版の CA・Nginx コンテナで5〜6時間目が動くこと」の2つに分けて確認した。

- 未確認：Pi の実機、Raspberry Pi OS 固有のパッケージ構成、デスクトップ版ブラウザ（Chromium）での証明書警告。
- Chromium は OS の信頼ストア（update-ca-certificates）を見ない〔要確認〕。Pi のブラウザでも警告を消したい場合は、Chromium の設定から ca.crt を別途読み込ませる必要がある可能性がある。

## Pi で注意すること

- 5時間目の CA 鍵（RSA 4096bit）の生成は、Pi だと数秒〜数十秒かかることがある〔推測〕。止まって見えても待つよう伝える。
- 手順書 05 の **B-6 は先に修正しておく**（`cd ~/crypto-handson/05_pki` を追加）。
