# Changelog

All notable changes to this project will be documented in this file.

## [v0.3.3] - 2026-04-22

### Bug Fixes

- Fixed: 監督追加後に一覧が即反映されない不具合を修正
- Fixed: チーム追加・編集ダイアログで監督候補が表示されない不具合を修正
- Fixed: ロスター画面・クールダウン表示で選手名が空欄または "null" になる不具合を修正

## [v0.3.2] - 2026-04-15

### Bug Fixes

#### 川口息吹 投手認識バグ修正（BE/FE）
- **can_pitch? 導入**: `card_type='batter'` でも `is_pitcher=true` の場合に投手として認識する `can_pitch?` メソッドを `PlayerCard` モデルに追加
- **投手判定ロジック刷新**: `is_pitcher` フラグへの単一依存を廃止。`player_card_defenses` の `P` ポジション存在チェックを正典とし、フォールバックとして `is_pitcher` フラグも使用する多層判定に変更
- **can_pitch scope 追加**: DB検索時に `can_pitch?` 相当のフィルタを適用できる ActiveRecord スコープを追加
- **投手状態タブ修正**: `pitcher_game_states` コントローラーの `is_pitcher: true` ベースDB検索を `PlayerCard.can_pitch` スコープに変更。川口息吹が投手状態タブに表示されるようになった
- **is_starter_pitcher / is_relief_only 修正**: `team_rosters_controller` 内のこれらフラグの計算も `pc.is_pitcher` から `pc.can_pitch?` に統一
- **FE 投手判定修正**: `SeasonRosterTab`・`PitcherAppearanceTab` の `position === 'pitcher'` フィルタに `is_pitcher === true` の OR 条件を追加
- **PlayerCard 型定義**: `PlayerCard` インターフェースに `is_pitcher?: boolean` を追加（optional）

#### その他バグ修正
- **no_out_exit バグ修正**: 0アウト降板時に `innings_pitched=0` が強制送信されるバグを修正
- **新人監督チーム登録不可修正**: 新規監督がチームを登録できない不具合を修正
- **高坂コスト修正**: 高坂選手のコストデータを修正
- **桜田二刀流コスト修正**: 桜田選手の二刀流コスト設定を修正

### Features

- **チーム一覧機能拡充**: チーム一覧画面に最終試合日・ゲーム内日付・ソート機能を追加

## [v0.2.0] - 2026-04-04

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
