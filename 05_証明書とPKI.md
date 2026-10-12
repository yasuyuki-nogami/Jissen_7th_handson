# 5時間目：証明書とPKI

テーマ：その公開鍵、本当にその人のもの？

前半で「自己署名証明書（俺俺証明書）＝警告が出る」を体験し、
後半で「CAに署名してもらった証明書＝警告が消える」を体験します。

> 本来CAはWebサーバーとは独立した外部の信頼できる認証局です。
> 今回は演習なので、同じVM内にDockerで簡易CAを作ります。

事前準備: `files/` ディレクトリ一式をVMの `~/crypto-handson/files` へ
コピーしておいてください。

---

## Part A. 自己署名証明書（俺俺証明書）

### Step A-0. 作業ディレクトリ作成

演習では自分自身（`localhost`）をWebサーバーとして使います。

```bash
mkdir -p ~/crypto-handson/05_pki
cd ~/crypto-handson/05_pki
```

### Step A-1. 自己署名証明書を作る

鍵と証明書を1コマンドで生成します（SAN付き）。

```bash
cp ~/crypto-handson/files/san.cnf .

openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout selfsigned.key \
  -out selfsigned.crt \
  -days 90 \
  -config san.cnf

ls -l selfsigned.key selfsigned.crt
```

### Step A-2. 証明書の中身を見る

```bash
openssl x509 -in selfsigned.crt -noout -subject -issuer -dates
```

✅ 確認: **Subject（誰の証明書か）と Issuer（誰が署名したか）が同じ**。
→「自分で自分を証明している」= 自己署名証明書。

### Step A-3. Nginx（Dockerコンテナ）にHTTPSを設定して起動する

WebサーバーはDockerコンテナとして動かします。
証明書・設定・コンテンツは `files/nginx/` からマウントされます。

```bash
cd ~/crypto-handson/files/nginx

# 証明書と秘密鍵を配置（コンテナへマウントされるディレクトリ）
mkdir -p ssl
cp ~/crypto-handson/05_pki/selfsigned.crt ssl/server.crt
cp ~/crypto-handson/05_pki/selfsigned.key ssl/server.key

# Webサーバー起動
docker compose up -d
docker ps
```

✅ 確認: `handson-web` コンテナが `Up` で、80/443ポートが公開されている。

```bash
# 設定の文法チェック（コンテナ内のnginxで実行）
docker compose exec web nginx -t
```

✅ 確認: `syntax is ok` / `test is successful`。

### Step A-4. アクセスして「警告」を体験する

```bash
curl https://localhost/
```

✅ 確認: `SSL certificate problem: self-signed certificate` という
**エラーになる**。curlはこの証明書を信頼していない。

```bash
# 検証をスキップすれば通信自体はできる（暗号化はされている）
curl -k https://localhost/ | head -5
```

ブラウザがあれば `https://localhost/` を開き、
「この接続ではプライバシーが保護されません」等の警告を確認する。

> 💡 暗号化は**されている**。信頼できないのは
> 「この公開鍵が本当にこのサーバーのものか、誰も保証していない」から。
> → そこで第三者の保証 = CA が必要になる。

---

## Part B. Docker簡易CAによる証明書発行

```
VM
├── Docker: handson-ca   ← 本来は外部にある認証局（今回は演習用）
└── Docker: handson-web  ← Webサーバー（Nginx）
```

### Step B-1. CAコンテナを起動する

```bash
cd ~/crypto-handson/files/ca

# CSR受け渡し用の共有ディレクトリ
mkdir -p ~/crypto-handson/05_pki/work

docker build -t handson-ca .
docker run -d --name handson-ca \
  -v ~/crypto-handson/05_pki/work:/work \
  handson-ca

docker ps
```

✅ 確認: `handson-ca` コンテナが `Up` になっている。

### Step B-2. サーバー側で秘密鍵とCSRを作る

CSR（証明書署名要求）=「この公開鍵に署名してください」という依頼書。
**秘密鍵はCAへ渡しません。** 渡すのはCSR（公開鍵入り）だけです。

```bash
cd ~/crypto-handson/05_pki

# サーバーの秘密鍵
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
  -out server.key

# CSRを作る
openssl req -new -key server.key -out server.csr -config san.cnf

# CSRの中身を確認
openssl req -in server.csr -noout -subject
```

✅ 確認: `subject=C=JP, O=DX Handson, CN=localhost`

### Step B-3. CSRをCAへ渡して署名してもらう

```bash
# CSRを共有ディレクトリへ（= CAへ送付するイメージ）
cp server.csr work/

# CAコンテナ内で署名を実行
docker exec handson-ca /ca/sign.sh /work/server.csr /work/server.crt

# 発行された証明書とCA証明書を受け取る
cp work/server.crt .
cp work/ca.crt .
ls -l server.crt ca.crt
```

✅ 確認: `[CA] 署名しました` と表示され、`server.crt`（サーバー証明書）と
`ca.crt`（CA証明書）が手に入る。

### Step B-4. 発行された証明書を確認する

```bash
openssl x509 -in server.crt -noout -subject -issuer -dates
openssl x509 -in server.crt -noout -ext subjectAltName
```

✅ 確認: 今度は **Subject と Issuer が違う**。
Issuer が `CN=DX Handson Root CA` = CAが署名した証明書。

```bash
# CA証明書を使えば検証が通ることも確認
openssl verify -CAfile ca.crt server.crt
```

✅ 確認: `server.crt: OK`

### Step B-5. Nginxの証明書を差し替える

自己署名証明書を、CAが発行した証明書へ置き換えて再読み込みします。

```bash
cp server.crt ~/crypto-handson/files/nginx/ssl/server.crt
cp server.key ~/crypto-handson/files/nginx/ssl/server.key

cd ~/crypto-handson/files/nginx
docker compose exec web nginx -t
docker compose exec web nginx -s reload
```

✅ 確認: エラーが出ないこと。

### Step B-6. CA証明書を信頼ストアへ登録する

「このCAを信頼する」とOSに登録します。

```bash
sudo cp ca.crt /usr/local/share/ca-certificates/handson-ca.crt
sudo update-ca-certificates
```

✅ 確認: `1 added` と表示される。

### Step B-7. 警告が消えることを確認する

```bash
curl https://localhost/ | head -5
```

✅ 確認: **今度は `-k` なしで成功する。**

- 俺俺証明書 → 警告（誰も保証していない）
- 信頼したCAが署名した証明書 → 警告なし（CAが保証している）

---

## 後片付け（演習終了後・6時間目のあとでもよい）

```bash
# 信頼ストアからCA証明書を削除
sudo rm /usr/local/share/ca-certificates/handson-ca.crt
sudo update-ca-certificates --fresh

# CAコンテナ削除
docker rm -f handson-ca

# Webサーバーコンテナ停止・削除
cd ~/crypto-handson/files/nginx
docker compose down
```

---

## 今日わかったこと

- 証明書 = 「この公開鍵は誰のものか」をCAが署名で保証したもの
- 自己署名では第三者の保証がないため警告が出る
- CSR → CA署名 → 証明書発行、という流れ（秘密鍵は渡さない）
- 実際のインターネットでは Root CA → 中間CA → サーバー証明書の
  信頼の連鎖（チェーン）になっている

## でも、まだ問題が残る

> 証明書で「相手が本物」と分かった。では実際のHTTPS通信全体は
> どう動いているのか？ → 6時間目「TLS / HTTPS」へ
