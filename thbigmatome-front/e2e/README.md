# e2e（Playwright）

今の画面が、実 Rails（test 環境・前提データ入り）と繋がって動くかを見る。対象は `auth.spec.ts`（ログイン・遷移）と `roster.spec.ts`（ホーム・左メニュー・ロスター・昇格）の 9 件。

CI では回していない。手元か、使い捨て環境で回す。

## 前提

| もの       | 内容                                                                                                                                                              |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Rails      | **test 環境**で起動していること。DB は使い捨てのものを使う                                                                                                        |
| 前提データ | `RAILS_ENV=test bin/rails e2e:seed`（`thbigmatome/db/seeds/test.rb`）。何度流しても同じ結果。test 環境以外では abort する                                         |
| フロント   | playwright が vite を自動で起こす（`playwright.config.ts` の `webServer`）。既に `E2E_BASE_URL` で動いていればそれを使う（`CI` が立っている時は使わず必ず起こす） |

前提データが作るもの: ユーザー `testuser` / `testpassword`（role: player）、そのユーザーに割り当てたチーム「テストチーム」、2軍の選手 2 人（短縮名 `投1` / `野2`）、コストとシーズン。チームに user を結ぶのが要点で、無いとホームが「チームが割り当てられていません」になり、テストが落ちる。

前提が欠けていると、`global-setup.ts` が最初に止まって何が足りないかを出す（各テストが 10 秒待って落ちる形にはならない）。

## 接続先（環境変数）

| 変数           | 既定                           | 意味                                                       |
| -------------- | ------------------------------ | ---------------------------------------------------------- |
| `E2E_BASE_URL` | `http://localhost:5173`        | フロントの URL                                             |
| `E2E_API_URL`  | `http://localhost:3000/api/v1` | Rails API の URL。vite にも `VITE_API_BASE_URL` として渡す |

Rails 側は `CORS_ALLOWED_ORIGIN` に `E2E_BASE_URL` と同じ origin を渡す（既定は `http://localhost:5173` だけ許可）。

## 手順（使い捨ての postgres と Rails を docker で立てる例）

ホストには libvips も PostgreSQL も無いことが多いので、Rails は docker で動かす。`<img>` は `thbigmatome/Dockerfile` から build したイメージ（WORKDIR は `docker inspect -f '{{.Config.WorkingDir}}' <img>` で確かめる）。名前と port は他と重ならないものにする。

```bash
# 1. 使い捨ての DB
docker network create e2e-net
docker run -d --name e2e-db --network e2e-net \
  -e POSTGRES_USER=e2e -e POSTGRES_PASSWORD=pw postgres:16-alpine
until docker exec e2e-db pg_isready -U e2e; do sleep 1; done   # 受け付け開始を待つ

# 2. Rails（test 環境）。コードは git ls-files -co で切り出したコピーを mount する
cat > e2e-rails.env <<'ENV'
RAILS_ENV=test
DB_HOST=e2e-db
DB_USERNAME=e2e
DB_PASSWORD=pw
HOME=/tmp
CORS_ALLOWED_ORIGIN=http://localhost:5189
ENV
APP=/path/to/copy-of-thbigmatome   # thbigmatome/ を git ls-files -co でコピーしたもの
docker run --rm --user $(id -u):$(id -g) --network e2e-net --env-file e2e-rails.env \
  -v $APP:/app --entrypoint bash <img> -c 'bin/rails db:create db:schema:load e2e:seed'
docker run -d --name e2e-rails --user $(id -u):$(id -g) --network e2e-net --env-file e2e-rails.env \
  -v $APP:/app -p 3119:3000 --entrypoint bash <img> -c 'bin/rails server -b 0.0.0.0 -p 3000'

# 3. e2e（thbigmatome-front/ で）
yarn install --immutable --ignore-scripts    # 初回のみ
npx playwright install chromium              # 初回のみ（ブラウザが無い時）
E2E_BASE_URL=http://localhost:5189 E2E_API_URL=http://localhost:3119/api/v1 npx playwright test

# 4. 片付け（自分で作ったものだけ）
docker rm -f e2e-rails e2e-db && docker network rm e2e-net
```

docker を使わず、手元の rails + postgres（test 環境）を `E2E_API_URL` に向けてもよい。その場合も `RAILS_ENV=test bin/rails e2e:seed` を一度流す。

## 直すとき

- ログイン後の遷移先・画面の文言を変えたら、`auth.spec.ts` / `roster.spec.ts` の期待を合わせる。URL は書かず `env.ts` から引く
- seed を変えたら `env.ts`（`TEST_USER` / `TEST_TEAM_NAME`）と `global-setup.ts` の検査を合わせる
- 昇格のテストは画面上で押すだけで保存しない。DB は変わらないので、何度流しても同じ結果になる
