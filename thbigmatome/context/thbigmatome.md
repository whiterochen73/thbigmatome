# thbigmatome プロジェクトコンテキスト
最終更新: 2026-03-10

## 基本情報
- **プロジェクトID**: thbigmatome
- **正式名称**: 東方BIG野球まとめ
- **パス**: /home/morinaga/projects/
- **公式Wiki**: https://thbigbaseball.wiki.fc2.com/

## 概要
野球ボードゲーム「東方BIG野球」のリーグ戦・チーム運営を管理するWebアプリケーション。バックエンドAPI + フロントエンドSPAの2リポジトリ + Pythonパーサーの計3リポジトリ構成。IRCログ解析→試合記録管理→成績集計を一貫して処理する。

## 技術スタック
- バックエンド: Ruby on Rails ~> 8.0.2 (thbigmatome/)
- フロントエンド: Vue.js 3 + TypeScript + Vuetify 3 (thbigmatome-front/)
- データベース: PostgreSQL
- ビルド: Vite 7
- パーサー: Python 3 (thbig-irc-parser/)
- コンテナ: Docker Compose

## システム構成

```
thbigmatome (Rails 8 API)
  ├─ 試合管理・チーム管理・選手マスタ等のCRUD API
  └─ game_records / at_bat_records: パーサーレビュー用テーブル（IRCログ取り込み機能の廃止前に作られたデータの閲覧・確定のみ）

thbigmatome-front (Vue.js 3 SPA)
  ├─ 試合記録一覧 → パーサーレビュー（ログ取り込み画面は廃止済み）
  ├─ タイムライン表示（3色分類: 宣言/ダイス/自動計算）
  └─ インライン編集 → 確定フロー

thbig-irc-parser (Python独立パッケージ)
  ├─ IRCログ → 打席レコード変換（atbat_parser）
  ├─ GameStateMachine: 走者・得点・アウトの状態追跡
  ├─ UP表・レンジチェック・エラーチェック処理
  └─ 選手カードPDF解析（card_parser）
```

BE→パーサー連携: 廃止済み（cmd_1791）。Rails 側の `games#parse_log` / `games#import_log` / `game_records#create` と PARSER_API_URL 連携は削除した。試合日ページの試合ログ保存（`season_schedules.game_log`）は別機能で、内容を解析せずに保存するだけなので残している。

## ドキュメント一覧

### バックエンド (thbigmatome/docs/)
- [db-schema.md](../docs/db-schema.md) — DBスキーマ定義（テーブル・カラム・リレーション）
- [models.md](../docs/models.md) — ActiveRecordモデル・バリデーション・アソシエーション
- [api-endpoints.md](../docs/api-endpoints.md) — APIエンドポイント一覧・リクエスト/レスポンス形式
- [serializers.md](../docs/serializers.md) — JSONシリアライザー出力形式

### フロントエンド (thbigmatome-front/docs/)
- [views.md](../../thbigmatome-front/docs/views.md) — ページコンポーネント・ルーティング・画面仕様
- [components.md](../../thbigmatome-front/docs/components.md) — 再利用コンポーネント仕様
- [composables-and-stores.md](../../thbigmatome-front/docs/composables-and-stores.md) — Composition API・状態管理
- [types.md](../../thbigmatome-front/docs/types.md) — TypeScript型定義

## 開発環境の注意事項

### Axios baseURL
`thbigmatome-front/plugins/axios.ts` に `axios.defaults.baseURL = 'http://localhost:3000/api/v1'` が設定済み。
FEのURLは `/api/v1/` プレフィックスなしの相対パスで書くこと（例: `/competitions`, `/teams`）。
`/api/v1/competitions` と書くと二重プレフィックスになり 404 になる。

### プロジェクトパス
プロジェクトパスは `/home/morinaga/projects/` 配下（マルチエージェントリポジトリの外）。

### 旧仕様書
`SPECIFICATION.md`, `NEW_FEATURE_SPECIFICATION.md` は旧仕様。参考程度にとどめること。
