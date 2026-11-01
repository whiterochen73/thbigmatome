# thbigmatome プロジェクトコンテキスト
最終更新: 2026-03-10

## 基本情報
- **プロジェクトID**: thbigmatome
- **正式名称**: 東方BIG野球まとめ
- **パス**: /home/morinaga/projects/
- **公式Wiki**: https://thbigbaseball.wiki.fc2.com/

## 概要
野球ボードゲーム「東方BIG野球」のリーグ戦・チーム運営を管理するWebアプリケーション。バックエンドAPI + フロントエンドSPAの2リポジトリ構成（Pythonパーサーは凍結。カード読み取りの道具としてだけ残る）。試合日ページでの結果入力→試合記録管理を行う。

## 技術スタック
- バックエンド: Ruby on Rails ~> 8.0.2 (thbigmatome/)
- フロントエンド: Vue.js 3 + TypeScript + Vuetify 3 (thbigmatome-front/)
- データベース: PostgreSQL
- ビルド: Vite 7
- パーサー: Python 3 (thbig-irc-parser/)。凍結。選手カードの PDF 読み取り・画像切り出しにだけ使う
- コンテナ: Docker Compose

## システム構成

```
thbigmatome (Rails 8 API)
  ├─ 試合管理・チーム管理・選手マスタ等のCRUD API
  └─ game_records / at_bat_records: 表だけ残す（画面と API は cmd_1795 で廃止。migration は作らない）

thbigmatome-front (Vue.js 3 SPA)
  └─ 試合日ページ（GameResult）での結果入力など。パーサー経由の画面（試合記録・試合詳細・オーダー確認・成績集計・パーサーレビュー）は廃止

thbig-irc-parser (Python独立パッケージ・凍結)
  ├─ IRCログ解析（atbat_parser ほか）: Rails とは繋がらない。Clubhouse の取り込みが今も呼ぶ
  └─ 選手カードPDF解析（card_parser）: 現役の使い道
```

BE→パーサー連携: 廃止済み（cmd_1791 でログ取り込み、cmd_1795 でパーサー経由の画面と API）。Rails 側の `games#parse_log` / `games#import_log` / `game_records#create` と PARSER_API_URL 連携は削除した。試合日ページの試合ログ保存（`season_schedules.game_log`）は別機能で、内容を解析せずに保存するだけなので残している。

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
