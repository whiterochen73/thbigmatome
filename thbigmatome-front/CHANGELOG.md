# Changelog

All notable changes to the THBIG Dugout frontend will be documented in this file.

## [0.3.3] - 2026-04-22

### Bug Fixes

- Fixed: チーム追加ダイアログのキャンセルボタンが機能しない不具合を修正

## [v0.2.0] - 2026-04-04

### Features

#### コミッショナー機能
- **1軍登録状況タブ**: 全チーム横断の1軍登録状況確認＋CSV出力（RosterStatusTab）
- **昇降格履歴タブ**: シーズンポータルに昇降格履歴追加（ストライプ表示＋日付フォーマット改善）
- **シーズンポータル改善**: インライン初期化フォーム、タブ順の使用頻度順並べ替え
- **リリース向けUI整理**: プレイヤー向け機能を非表示に（コミッショナー専用化）

#### 試合記録UI
- **投手登板記録タブ**: 登板記録の入力・保存・D&D並べ替え・先発行差別化
- **投手状態タブ**: 試合結果画面に投手疲労状態の表示を追加
- **試合概要改善**: パンくずリスト方式ヘッダー、GameResult UI改善

#### チーム編成UI
- **カード選択UI刷新**: モーダル廃止→ラジオボタン化、card_set単位統合
- **PlayerCard選択**: TeamMembershipにPlayerCard紐付け表示対応
- **特例選手（key_player）選択UI**: player_card紐付けUI
- **TeamMemberSelect背番号検索**: 背番号での選手検索に対応

#### UI/UX共通
- **PlayerNameLink**: ホバーカード画像ポップアップ、投手/打者カード切替、両契約選手対応
- **UI操作説明**: ツールチップ、ヘルプテキスト、空状態ガイドを全画面に追加
- **WLD badge**: シーズンポータルに勝敗バッジ＋7カテゴリ色分けシステム

#### Vuetify 4対応
- **Vuetify 3.12.0 → 4.0.3**: メジャーアップデート対応
- spacing修正（dense → density="compact"）
- Zen Kaku Gothic Newフォント復旧＋Vuetify 4デフォルト上書き
- 日本語ロケール適用（英語表記一括解消）

#### デプロイ・Nginx
- **Nginx SSL設定**: Let's Encrypt + certbot対応
- **ドメインリダイレクト**: thbig.fun → dugout.thbig.fun（Nginx rewrite）
- **本番ビルド構成**: Docker Compose production対応

#### セキュリティ
- **サプライチェーン対策**: ignore-scripts=true 設定追加

### Improvements

- ScoreSheet / StartingMemberDialog の完全削除（不要機能クリーンアップ）
- robots.txt追加（全ページクロール除外）
- パッケージアップデート: Vue Router 5、Vuetify 4.0.3、Vite 7

### Bug Fixes

- FE本番ビルドTSエラー全修正（vue-tsc --noEmit対応）
- 外の世界枠ヘルプテキスト3箇所の誤認修正
- コスト状況タブ種別日本語化・カードセットドロップダウン幅修正
- コスト列2行崩れ＋1軍コスト上限null表示改善
- handedness未設定時のraw i18nキー表示崩れ修正
- TeamMembers各種修正（position参照、cost_players nullガード）
- Vitest Vuetify 4.0.3 VFormバグ回避
- チーム未選択時のチーム編成画面フォールバック修正

## [v0.1.0] - 2026-03-29

Initial release. コミッショナー向けチーム・選手・試合管理UIの基本機能。
