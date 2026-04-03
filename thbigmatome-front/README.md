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
- npm（またはyarn / pnpm）

### 手順

```bash
cd thbigmatome-front

# 環境変数を設定
cp .env.example .env.local
# .env.local の VITE_API_BASE_URL を編集（デフォルト: http://localhost:3000/api/v1）

# 依存関係インストール
npm install

# 開発サーバー起動（http://localhost:5173）
npm run dev
```

**注意:** `.env.local` は `.gitignore` 対象。リポジトリにコミットされません。

## テスト

```bash
# ユニットテスト
npm run test
# または
npx vitest run
```

## ビルド

```bash
# 本番ビルド（dist/ に出力）
npm run build

# TypeScriptチェック（本番ビルド前に実行推奨）
npx vue-tsc --noEmit
```

## デプロイ

Docker Compose を使用して本番環境にデプロイします。詳細は [`../thbigmatome/DEPLOY.md`](../thbigmatome/DEPLOY.md) を参照。