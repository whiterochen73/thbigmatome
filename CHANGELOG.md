# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1] - 2026-04-06

### Fixed
- 先発疲労P未設定時にデフォルト値3を適用（ルール§8.3, Issue #7）
- AP鈴仙の外の世界枠判定修正（Issue #4）
- 正邪の野手判定修正（Issue #5）
- 野手専念投手の表示修正（Issue #6）
- FE CIをyarnに切り替え（npm ci→yarn install --frozen-lockfile）

### Added
- Dugout内部API新設（Clubhouseデータ同期用）

## [0.2.0] - 2026-04-03

### Added
- AI整合性維持フレームワーク（ハーネス層＋プロジェクト層2層構造）
- ペルソナ選択型エージェント（my-idol-agent Phase1）
- 記事図書館スクリプト（article_index.sh、article_detect.sh）
- Portalポータル：記事ライブラリ画面・自動ビルド・再起動スクリプト
- 各種仕様書現状追従更新（models/db-schema/api-endpoints/serializers）

## [0.1.0] - 2026-02-17

### Added
- プロジェクト開始（Initial release）
