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
  ├─ IRCログ取り込み（parse_log / import_log）
  ├─ AtBatRecordBuilder: パーサー出力→source_events/discrepancies正規化
  └─ game_records / at_bat_records: パーサーレビュー用テーブル

thbigmatome-front (Vue.js 3 SPA)
  ├─ 試合記録一覧 → ログ取り込みウィザード → パーサーレビュー
  ├─ タイムライン表示（3色分類: 宣言/ダイス/自動計算）
  └─ インライン編集 → 確定フロー

thbig-irc-parser (Python独立パッケージ)
  ├─ IRCログ → 打席レコード変換（atbat_parser）
  ├─ GameStateMachine: 走者・得点・アウトの状態追跡
  ├─ UP表・レンジチェック・エラーチェック処理
  └─ 選手カードPDF解析（card_parser）
```

BE→パーサー連携: Rails側の `games#parse_log` がPythonパーサーを呼び出し、結果を `game_records` + `at_bat_records` に格納。`import_log` で確定メタデータと紐づけ、`game_record_id` を返却。

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
