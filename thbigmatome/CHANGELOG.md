# Changelog

All notable changes to this project will be documented in this file.

## [v0.2.0] - 2026-03-31

### Features

#### コミッショナー機能
- **1軍登録状況タブ**: コミッショナー向け全チーム横断の1軍登録状況確認＋CSV出力
- **昇降格履歴タブ**: シーズンポータルに昇降格履歴タブを追加（ストライプ表示＋日付フォーマット改善）
- **シーズンポータル改善**: インライン初期化フォーム、タブ順の使用頻度順並べ替え
- **リリース向けUI整理**: プレイヤー向け機能を非表示に（コミッショナー専用化）

#### 試合記録
- **投手登板記録**: 登板記録タブ、バルク一括保存、D&D並べ替え、先発行差別化
- **投手状態タブ**: 試合結果入力画面に投手状態タブを追加
- **試合概要改善**: パンくずリスト方式ヘッダー、GameResult改善

#### チーム編成
- **カード選択UI刷新**: モーダル廃止→ラジオボタン化、card_set単位統合
- **PlayerCard選択機能**: TeamMembershipにPlayerCard紐付け、player_card_id追加
- **特例選手（key_player）選択UI**: player_card紐付け対応
- **TeamMemberSelect背番号検索**: 背番号での選手検索に対応

#### UI/UX
- **PlayerNameLink**: ホバーカード画像ポップアップ、投手/打者カード切替、両契約選手対応
- **UI操作説明**: ツールチップ、ヘルプテキスト、空状態ガイドを全画面に追加
- **Vuetify 4対応**: 3.12.0→4.0.3アップデート、spacing修正、フォント復旧、日本語ロケール
- **WLD badge**: シーズンポータルに勝敗バッジ＋7カテゴリ色分けシステム

#### デプロイ・インフラ
- **本番デプロイ構成**: ConoHa VPS 2GB対応 Docker Compose構成確立
- **HTTPS対応**: Let's Encrypt + certbot + Nginx SSL設定
- **ドメインリダイレクト**: thbig.fun → dugout.thbig.fun
- **本番初期データ**: 34チーム・30player・31Manager のseed完全版

#### セキュリティ
- **CORS環境変数化**: 本番セキュリティ設定改善
- **サプライチェーン対策**: ignore-scripts=true 設定追加

### Improvements

- シーズンポータルのタブ順を使用頻度・作業フロー順に並べ替え
- ScoreSheet/StartingMemberDialogの完全削除（不要機能クリーンアップ）
- player_absencesにteam_idフィルタ対応追加
- robots.txt追加（全ページクロール除外）
- パッケージアップデート: Rails 8.1.3、Ruby 3.4.7、Vue Router 5、Vuetify 4.0.3

### Bug Fixes

- ActiveStorage URL protocol修正（本番カード画像HTTPS強制）
- PlayerCardSerializer image_urlのハードコードホスト除去
- player.short_name nil時のnameフォールバック
- CARD_IMAGE_DIRデフォルトパス修正
- 外の世界枠ヘルプテキスト3箇所の誤認修正
- コスト状況タブ種別日本語化・カードセットドロップダウン幅修正
- コスト列2行崩れ修正＋1軍コスト上限null表示改善
- PMカード含む全カードセットにseries値を設定（外の世界枠修正）
- 投手状態タブのデータ正確性修正
- pitcher_appearances bulk_saveでschedule_dateがNULLになるバグ修正
- pitcher_game_states players.positionをPlayerCard.is_pitcher=trueに修正
- 登板記録タブ2件バグ修正
- handedness未設定時のraw i18nキー表示崩れ修正
- FE本番ビルドTSエラー全修正
- Vitest Vuetify 4.0.3 VFormバグ回避

## [v0.1.0] - 2026-03-29

Initial release. コミッショナー向けチーム・選手・試合管理の基本機能。
