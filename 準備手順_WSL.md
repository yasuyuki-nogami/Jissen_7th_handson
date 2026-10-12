# 第7回ハンズオン WSL 版 準備手順

## 受講者がやること（初回のみ）

1. **WSL と Ubuntu を入れる**（Windows の管理者権限が必要）
   PowerShell を「管理者として実行」で開いて、次を実行：
   ```powershell
   wsl --install -d Ubuntu-24.04
   ```
   再起動後に Ubuntu が起動したら、ユーザー名とパスワードを決める（このパスワードは2時間目の `ssh-copy-id` でも使う）。

2. **リポジトリを WSL 側に clone する**（Windows 側の `/mnt/c` ではなく、WSL のホームに置く）
   ```bash
   sudo apt-get update && sudo apt-get install -y git
   cd ~ && git clone https://github.com/yasuyuki-nogami/Jissen_7th_handson.git
   cd Jissen_7th_handson
   ```

3. **setup を実行**
   ```bash
   bash setup_wsl.sh
   ```

4. **Ubuntu を開き直す**（`exit` して、もう一度 Ubuntu を起動）
   docker を sudo なしで使えるようにするため。

## setup_wsl.sh がやること

| 項目 | 内容 |
|---|---|
| 前提チェック | Ubuntu 22.04 / 24.04 であること、root ではないこと、`files/` があること |
| 基本ツール | openssl / openssh-client / openssh-server / curl / xxd |
| sshd | パスワード認証を有効化（`/etc/ssh/sshd_config.d/50-handson.conf`）して起動 |
| Docker | Docker Engine を公式の apt リポジトリから入れて起動し、ユーザーを docker グループに追加。Docker Desktop の WSL 連携が入っていれば、インストールは省略 |
| ハンズオンファイル | `~/crypto-handson/files` にコピーして CRLF→LF に変換（README の sed 相当。既にあればバックアップを取ってから置き換え） |
| イメージ事前取得 | nginx:1.27-alpine / alpine:3.20 を先に取得（失敗しても警告だけで続行） |
| 確認 | 各ツールのバージョン表示、80/443 番ポートが使われていないかのチェック |

何度実行しても問題ない（2回目以降は Docker の再インストールなどをスキップする）。

## 毎回の授業のはじめ（systemd が無効な WSL の場合のみ）

setup の最後に「systemd が無効」と表示された人は、Ubuntu を起動するたびに次を実行：
```bash
sudo service ssh start; sudo service docker start
```
最近の WSL の Ubuntu は systemd が有効なことが多く、その場合は自動で起動するので不要〔受講者の環境で要確認〕。

## 検証結果（こちらの環境）

WSL の実機は用意できなかったので、素の Ubuntu コンテナで「systemd なし」の WSL に近い状態を作って確認した。

| 環境 | setup_wsl.sh | 1〜6時間目の主要コマンド |
|---|---|---|
| Ubuntu 22.04（systemd なし） | ✅ 正常終了 | ✅ 全項目 OK |
| Ubuntu 24.04（systemd なし） | ✅ 正常終了 | ✅ 全項目 OK |

- 1〜6時間目は、ssh-copy-id（パスワード入力）→ ssh localhost（鍵）、sudo なしの docker compose、CA 署名、信頼ストア登録後の `-k` なし curl、リダイレクトまで確認した。5時間目 B-6 は `cd ~/crypto-handson/05_pki` を入れた修正版で実行した。
- 未確認：WSL の実機、systemd が有効な WSL、Docker Desktop と併用する場合、Windows 側のブラウザからのアクセス。

## WSL で特に注意すること

- **作業は WSL 側（`~`）で行う**。`/mnt/c/...`（Windows 側）で作業すると、ファイルの権限が 777 に見えて ssh が秘密鍵を拒否する。動作も遅い。
- **5時間目の信頼ストア登録が効くのは WSL の中だけ**。Windows のブラウザで https://localhost を開くと、警告は消えないまま。ブラウザでも警告を消したい場合は、`ca.crt` を Windows 側の「信頼されたルート証明機関」に別途登録する必要がある（終わったら削除させること）。
- **Windows 側で 80/443 番ポートを使っているソフト**（IIS など）があると、Windows のブラウザから WSL の Nginx が見えないことがある〔推測〕。
- 手順書 05 の **B-6 は先に修正しておく**（`cd ~/crypto-handson/05_pki` を追加）。
