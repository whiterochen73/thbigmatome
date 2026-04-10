# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.1] - 2026-04-10

### Added
- 本番DBバックアップ体制構築（backup_daily.sh・restore.sh・pull_backup.sh）
- PM2026未登録カード4件を開発DBに登録（西行寺幽々子楼閣・八雲藍WBC2・花山栄美UR・小鳥遊柚UR）
- PM2026バリエーション4件の親カード紐づけ修正（幽々子楼閣・藍WBC2をtouhou基底プレイヤーに変更）

### Fixed
- 0アウト降板（no_out_exit）時の累積投球回計算修正（+2固定→max(ip+flag,1)方式）
- 先発長イニング敗戦ペナルティにno_out_exit関与イニング計算を適用
- 関与イニング数を通算アウト数ベースで正確に計算するよう修正
- バリエーション持ち選手のコスト検索をvariant-aware化（FE・BE両対応）
- チーム一覧アクティブ優先ソート＋destroyの防御的修正

## [0.3.0] - 2026-04-08

### Added
- バリエーション持ち選手の自動判定＋カード別コスト種別（available_cost_types_for_card）実装
- コスト画面ハイブリッド拡張（カード別コスト登録対応）
- コスト種別解禁条件実装（リリーフ・二刀流・投手専念・野手専念）
- コスト登録メニュー解禁＋player_types API整備
- PM2026バリアント選手50件のvariant設定＋元選手紐づけ
- オリジナル枠バリエーション選手45件のvariant設定

### Fixed
- hachinai_two_way?誤判定修正（number<=39条件削除→hachinai61カードセット保有+投手/野手両方保有に変更）
- コスト一覧からカード未登録選手を除外
- PM通し番号選手17件のvariant誤付与を修正
- 投手休養ルール3件修正（負傷中の休養凍結・減衰凍結・中10日全快）
- relief_only_cost解禁条件修正
- チームダイアログ コーチ欄削除＋director locale修正
- バグ2件修正（チームダイアログ不開・累積イニング一律1判定）
- バグ3件修正（端数入力0補完・innings計算・cooldown null）

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
