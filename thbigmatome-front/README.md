# THBIG Dugout — フロントエンド

東方BIG野球のチーム・選手・試合を管理するファンタジー野球管理アプリ「THBIG Dugout」のフロントエンドです。

## 主な技術スタック

| 項目 | バージョン |
|------|-----------|
| Vue.js | 3.5 |
| Vuetify | 4.0.3 |
| Vite | 7.x |
| TypeScript | 5.8 |
| Vue Router | 5 |
| Pinia | 3.x |
| Vitest | 4.x |
| Node.js | 20.x |

## 主な機能

- **チーム編成**: チームメンバー登録・選手カード選択・コスト管理
- **試合記録**: 試合ログインポート・打席記録表示・投手登板記録入力
- **日程管理**: シーズン日程・大会管理
- **コミッショナー機能**: ユーザー管理・離脱状況確認・1軍登録状況CSV出力
- **選手カード**: カード画像表示・PlayerNameLinkホバーポップアップ

## 開発環境のセットアップ

### 前提条件

- Node.js 20.x
- Yarn 4（Yarn Berry）。corepack 経由で入れる。`package.json` の `packageManager` が版を固定している

### Yarn（corepack）について

```bash
# 初回のみ。yarn の実体が corepack に切り替わる
corepack enable
```

- `.yarnrc.yml` で `nodeLinker: node-modules`（従来どおり `node_modules` に展開）、`enableScripts: false`（install 時に postinstall 等を実行しない）、`npmMinimalAgeGate: "7d"`（公開から 7 日未満の版は `yarn add` / `yarn up` / lock 再解決の対象にならない）を設定している。
- 若い版がどうしても必要な時だけ `yarn add --no-time-gate <pkg>` を使う（脆弱性の修正版が 7 日未満の場合など）。使ったら理由を残す。
- lock 済みの版は再判定されない。`yarn install --immutable` は lock を書き換えず、CI と Docker もこの形で動く。
- 他の Yarn Classic のリポ（packageManager を持たないもの）では、corepack は従来の Yarn 1.22.x を使うため影響しない。

### 手順

```bash
cd thbigmatome-front

# 環境変数を設定
cp .env.example .env.local
# .env.local の VITE_API_BASE_URL を編集（デフォルト: http://localhost:3000/api/v1）

# 依存関係インストール（lock を書き換えたくない時は yarn install --immutable）
yarn install

# 開発サーバー起動（http://localhost:5173）
yarn dev
```

**注意:** `.env.local` は `.gitignore` 対象。リポジトリにコミットされません。

## テスト

```bash
# ユニットテスト
yarn test
# または
yarn vitest run
```

## ビルド

```bash
# 本番ビルド（dist/ に出力）
yarn build

# TypeScriptチェック（本番ビルド前に実行推奨）
yarn type-check
```

## デプロイ

Docker Compose を使用して本番環境にデプロイします。詳細は [`../thbigmatome/DEPLOY.md`](../thbigmatome/DEPLOY.md) を参照。