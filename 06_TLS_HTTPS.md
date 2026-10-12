# 6時間目：TLS / HTTPS

テーマ：今日触った技術が全部ここで使われている。

HTTPSでは以下が組み合わされています。

- 共通鍵暗号（1時間目）… 実データの高速な暗号化
- 公開鍵暗号（2時間目）… 安全な鍵共有・認証
- ハッシュ（3時間目）… 改ざん検知
- 電子署名（4時間目）… 証明書への署名・検証
- 証明書 / PKI（5時間目）… 相手が本物であることの保証

> 注意: TLS 1.3では「公開鍵で共通鍵そのものを暗号化して送る」のでは
> なく、鍵交換（ECDHE等）で双方が同じセッション鍵を**導出**します。

5時間目のNginx HTTPS設定・CA信頼登録が済んでいる前提です。

---

## Step 1. HTTPとHTTPSを比べる

```bash
# HTTP（平文）
curl http://localhost/ | head -5

# HTTPS（暗号化）
curl https://localhost/ | head -5
```

✅ 確認: どちらも同じページが返る。違いは「通信路が守られているか」。
（HTTPとHTTPSの「見え方」の違いは第8回でパケットキャプチャして確認）

## Step 2. TLSハンドシェイクの様子を見る

```bash
curl -v https://localhost/ -o /dev/null
```

✅ 確認ポイント（出力の中から探す）:

- `SSL connection using TLSv1.3 / TLS_AES_...`
  → TLSバージョンと暗号スイート（AES = 1時間目の共通鍵暗号！）
- `subject: ... CN=localhost` → サーバー証明書のSubject
- `issuer: ... CN=DX Handson Root CA` → 5時間目に作ったCA
- `SSL certificate verify ok` → 証明書検証に成功

## Step 3. openssl s_client で証明書を直接見る

```bash
openssl s_client -connect localhost:443 \
  -servername localhost </dev/null
```

✅ 確認ポイント:

- `Certificate chain` … サーバーが提示した証明書
- `subject=` / `issuer=` … 誰の証明書で、誰が署名したか
- `Verify return code: 0 (ok)` … 検証成功
- `Protocol : TLSv1.3` などのTLS情報

```bash
# 証明書部分だけ取り出して中身を見る
openssl s_client -connect localhost:443 \
  -servername localhost </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates
```

## Step 4. TLSの大きな流れを整理する

手は動かさず、Step 2〜3で見た内容を流れに当てはめます。

```
Client                         Server
  | ---- 接続要求(ClientHello) --> |
  | <--- 証明書を提示 ------------ |   ← 5時間目の証明書
  | 証明書を検証（CAの署名を確認）  |   ← 4時間目の署名検証
  | <===== 鍵交換で             ===> |   ← 2時間目の公開鍵暗号の応用
  |        セッション鍵を共有        |
  | <==== 以降は共通鍵暗号で ====> |   ← 1時間目のAES
  |        高速に暗号化通信          |
```

## Step 5. （任意）HTTPをHTTPSへリダイレクトする

実運用でよくある「HTTPで来たらHTTPSへ転送」も設定してみます。
用意済みの設定ファイルを `conf.d/` へコピーして再読み込みするだけです。

```bash
cd ~/crypto-handson/files/nginx

# 元の設定を控えておく（conf.d の外に置く）
cp conf.d/handson-http.conf handson-http.conf.orig

# 80番の「ページ配信」設定を「リダイレクト」設定で置き換える
cp extra/handson-redirect.conf conf.d/handson-http.conf

docker compose exec web nginx -t
docker compose exec web nginx -s reload

# -L でリダイレクトを追いかける
curl -IL http://localhost/
```

✅ 確認: `301 Moved Permanently` → `Location: https://...` →
最終的に `200 OK`（HTTPS）となる。

元に戻すとき（やり直したいとき）:

```bash
cd ~/crypto-handson/files/nginx
cp handson-http.conf.orig conf.d/handson-http.conf
docker compose exec web nginx -s reload
```

---

## 6時間のまとめ

```
共通鍵暗号 ── 高速だが鍵の受け渡しが課題
   ↓
公開鍵暗号 ── 鍵を渡さず暗号・認証（SSH鍵もこれ）
   ↓
ハッシュ ──── データの指紋・改ざん検知
   ↓
電子署名 ──── ハッシュ×秘密鍵で「本人が作った」を保証
   ↓
証明書/PKI ── 「その公開鍵が本人のもの」をCAが保証
   ↓
TLS/HTTPS ── 上記ぜんぶの組み合わせ
```

## 今日わかったこと

- HTTPSは単一の技術ではなく、今日学んだ技術の組み合わせ
- 自分で証明書を作り、WebサーバーをHTTPS化できた
- 「セキュリティは後回しにしない」ための基礎部品が揃った

→ 第8回では、この通信をパケットレベルで「見て」、
SSHトンネル・VPNへ進みます。
