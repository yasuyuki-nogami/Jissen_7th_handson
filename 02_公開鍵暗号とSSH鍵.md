# 2時間目：公開鍵暗号とSSH鍵

テーマ：秘密にしたい鍵を相手へ渡さずに済む方法。
「以前使ったSSHの鍵」が公開鍵暗号の実例であることを確認します。

---

## Step 0. 作業ディレクトリ（確認用）

```bash
mkdir -p ~/crypto-handson/02_pubkey
cd ~/crypto-handson/02_pubkey
```

## Step 1. SSH鍵ペアを作る

```bash
ssh-keygen -t ed25519 -C "handson2026"
```

- 保存先: そのままEnter（`~/.ssh/id_ed25519`）
  - すでに同名の鍵がある場合は上書きしないよう、
    `~/.ssh/id_ed25519_handson` など別名を入力する
- パスフレーズ: 演習では空でもよい（Enter 2回）

✅ 確認: 「Your identification has been saved ...」と表示され、
randomart（図形）が出る。

## Step 2. 生成された鍵ペアを確認する

```bash
ls -la ~/.ssh
```

✅ 確認: 2つのファイルができている。

- `id_ed25519` … **秘密鍵**（自分だけが持つ。パーミッション600）
- `id_ed25519.pub` … **公開鍵**（相手に渡してよい）

## Step 3. 公開鍵の中身を見る

```bash
cat ~/.ssh/id_ed25519.pub
```

✅ 確認: `ssh-ed25519 AAAA...` という1行のテキスト。
これは**公開してよい**鍵。

⚠️ **秘密鍵（id_ed25519）は `cat` で表示しない・他人へ渡さない・
画面共有に映さない**こと。

## Step 4. 公開鍵をサーバーへ登録する

演習ではVM自身（localhost）へSSHします。
（sshdが動いていない場合: `sudo apt install -y openssh-server`）

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub localhost
```

初回は `yes` と、**ログインパスワード**を入力します。

✅ 確認: 「Number of key(s) added: 1」と表示される。
（実体は `~/.ssh/authorized_keys` に公開鍵が追記されただけ）

```bash
cat ~/.ssh/authorized_keys
```

## Step 5. 公開鍵認証でSSH接続する

```bash
ssh localhost
```

✅ 確認: **パスワードを聞かれずに**ログインできる。
→ サーバー側の「公開鍵」と手元の「秘密鍵」のペアで認証された。

```bash
exit
```

## Step 6. （任意）鍵ペアの対応関係を確認する

公開鍵のフィンガープリントを、秘密鍵側・公開鍵側それぞれから表示します。

```bash
ssh-keygen -lf ~/.ssh/id_ed25519
ssh-keygen -lf ~/.ssh/id_ed25519.pub
```

✅ 確認: 同じフィンガープリントが表示される → 2つはペアである。

---

## 今日わかったこと

- 鍵は「秘密鍵」「公開鍵」のペアでできている
- 公開鍵は配ってよい。秘密鍵は自分だけが持つ
- 普段使っているSSH公開鍵認証は、公開鍵暗号の実例だった

## でも、まだ問題が残る

> 暗号化しても、データが「途中で書き換えられていない」ことは
> どうやって確認する？
> → 3時間目「ハッシュ」へ
