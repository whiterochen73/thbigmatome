# DB スキーマ仕様書

最終更新日: 2026-03-10

## 参照ソースファイル

- `db/schema.rb` (schema version: 2026_03_09_142556)
- `config/game_rules.yaml` — ゲームルール正本（DB制約とビジネスルールの照合に使用）

---

## テーブル一覧

| テーブル名 | 用途 |
|-----------|------|
| ability_definitions | 選手カードのアビリティ（特殊能力）マスタ |
| active_storage_attachments | Active Storage — 添付ファイルとレコードの紐付け |
| active_storage_blobs | Active Storage — ファイルメタデータ・ストレージキー |
| active_storage_variant_records | Active Storage — 画像バリアント（リサイズ等）キャッシュ |
| at_bat_records | ゲームレコード（ログ解析結果）の打席レコード |
| at_bats | 試合の打席データ（ライブ入力） |
| batting_styles | 打撃スタイルマスタ（引っ張り・流し等） |
| biorhythms | バイオリズム周期マスタ（期間定義） |
| card_sets | カードセットマスタ（年度・セット種別） |
| competition_entries | 大会へのチーム参加エントリ |
| competition_rosters | 大会エントリのロスター（登録選手カード） |
| competitions | 大会マスタ（ペナント・トーナメント） |
| cost_players | 選手コスト情報（コストリストごとの各種コスト値） |
| costs | コストリストマスタ（期間・改定履歴） |
| game_events | 試合内のイベント（盗塁・暴投等）ログ |
| game_lineup_entries | 試合ラインナップの個別エントリ（先発/ベンチ等） |
| game_lineups | チームの試合用ラインナップ一時保存（1チーム1件） |
| game_records | ゲームレコード（ログ解析結果の試合単位データ） |
| games | 試合データ（ライブ入力・ログインポート） |
| imported_stats | 外部からインポートした選手成績統計 |
| lineup_template_entries | ラインナップテンプレートの個別エントリ |
| lineup_templates | オーダーテンプレート（投手左右×DH有無で最大4パターン） |
| managers | 監督・コーチマスタ |
| pitcher_game_states | 投手の試合ごとの登板状態（勝敗・疲労・イニング数） |
| pitching_styles | 投球スタイルマスタ（速球・変化球系等） |
| player_absences | 選手の離脱記録（怪我・出場停止等） |
| player_card_abilities | 選手カードのアビリティ付与（中間テーブル） |
| player_card_defenses | 選手カードの守備能力（ポジション×レンジ×エラーランク） |
| player_card_exclusive_catchers | 専用捕手制約（特定カードと捕手の組み合わせ） |
| player_card_player_types | 選手カードのプレイヤータイプ付与（中間テーブル） |
| player_card_traits | 選手カードの特徴（トレイト）付与（中間テーブル） |
| player_cards | 選手カードデータ（打撃表・投球表・各種能力値） |
| player_types | プレイヤータイプマスタ（外の世界枠等の分類） |
| players | 選手マスタ（名前・背番号） |
| schedule_details | スケジュール詳細（日付単位の試合日種別） |
| schedules | スケジュールマスタ（有効期間付き） |
| season_rosters | シーズンロスター（公示履歴） |
| season_schedules | チームシーズンの試合スケジュール（結果含む） |
| seasons | チームのシーズン管理 |
| squad_text_settings | チームのスカッドテキスト生成設定 |
| stadiums | 球場マスタ |
| team_managers | チームと監督・コーチの紐付け |
| team_memberships | チームと選手の所属関係 |
| teams | チームマスタ |
| trait_conditions | トレイト・アビリティの発動条件マスタ |
| trait_definitions | トレイト（特徴）定義マスタ |
| users | ユーザーマスタ（認証・ロール管理） |

---

## テーブル詳細

### ability_definitions

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| name | string | NO | — | アビリティ名（一意） |
| typical_role | string | YES | — | 典型的な役割（投手/野手等） |
| effect_description | text | YES | — | 効果説明 |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `name` (unique)

---

### active_storage_attachments

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| name | string | NO | — | 添付ファイル名（例: "card_image"） |
| record_type | string | NO | — | 添付元レコードのクラス名（STI） |
| record_id | bigint | NO | — | 添付元レコードID |
| blob_id | bigint | NO | — | active_storage_blobs FK |
| created_at | datetime | NO | — | 作成日時 |

**インデックス**: `blob_id`, `(record_type, record_id, name, blob_id)` (unique)

---

### active_storage_blobs

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| key | string | NO | — | ストレージキー（一意） |
| filename | string | NO | — | ファイル名 |
| content_type | string | YES | — | MIMEタイプ |
| metadata | text | YES | — | 任意メタデータ（JSON文字列） |
| service_name | string | NO | — | ストレージサービス名 |
| byte_size | bigint | NO | — | ファイルサイズ（バイト） |
| checksum | string | YES | — | チェックサム |
| created_at | datetime | NO | — | 作成日時 |

**インデックス**: `key` (unique)

---

### active_storage_variant_records

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| blob_id | bigint | NO | — | active_storage_blobs FK |
| variation_digest | string | NO | — | バリアント変換パラメータのdigest |

**インデックス**: `(blob_id, variation_digest)` (unique)

---

### at_bat_records

ゲームレコード（ログ解析結果）の打席単位データ。`at_bats`（ライブ入力）とは別テーブル。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| game_record_id | bigint | NO | — | game_records FK |
| ab_num | integer | YES | — | 打席番号（ゲームレコード内）|
| inning | integer | YES | — | イニング |
| half | string | YES | — | 表/裏 (top/bottom) |
| batter_id | string | YES | — | 打者識別子（文字列ID） |
| batter_name | string | YES | — | 打者名 |
| pitcher_id | string | YES | — | 投手識別子（文字列ID） |
| pitcher_name | string | YES | — | 投手名 |
| bat_roll | integer | YES | — | 打撃ダイス値 |
| pitch_roll | integer | YES | — | 投球ダイス値 |
| bat_result | string | YES | — | 打撃結果コード |
| pitch_result | string | YES | — | 投球結果コード |
| result_code | string | YES | — | 最終結果コード |
| strategy | string | YES | — | 作戦 (hitting/bunt/endrun/steal/intentional_walk) |
| outs_before | integer | YES | — | 打席前アウト数 |
| outs_after | integer | YES | — | 打席後アウト数 |
| runs_scored | integer | NO | 0 | 得点数 |
| play_description | text | YES | — | プレイ説明文 |
| runners_before | jsonb | YES | {} | 打席前走者状況 |
| runners_after | jsonb | YES | {} | 打席後走者状況 |
| gsm_value | jsonb | YES | {} | GSM解析値 |
| adopted_value | jsonb | YES | {} | 採用値 |
| discrepancies | jsonb | NO | [] | 解析不一致リスト |
| extra_data | jsonb | YES | {} | 追加データ |
| source_events | jsonb | NO | [] | ソースイベントリスト |
| modified_fields | jsonb | YES | — | 修正済みフィールド |
| is_modified | boolean | NO | false | 修正済みフラグ |
| is_reviewed | boolean | NO | false | レビュー済みフラグ |
| review_notes | text | YES | — | レビューメモ |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `game_record_id`, `(game_record_id, ab_num)` (unique)

---

### at_bats

試合（Game）の打席データ（ライブ入力）。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| game_id | bigint | NO | — | games FK |
| seq | integer | NO | — | 試合内連番（一意） |
| inning | integer | NO | — | イニング |
| half | string | NO | — | 表/裏 (top/bottom) |
| batter_id | bigint | NO | — | players FK（打者） |
| pitcher_id | bigint | NO | — | players FK（投手） |
| pinch_hit_for_id | bigint | YES | — | players FK（代打対象選手） |
| outs | integer | NO | — | 打席前アウト数 (0-2) |
| outs_after | integer | NO | — | 打席後アウト数 (0-3) |
| result_code | string | NO | — | 結果コード |
| play_type | string | NO | "normal" | 作戦種別 (normal/bunt/squeeze/safety_bunt/hit_and_run) |
| rbi | integer | YES | 0 | 打点 |
| scored | boolean | YES | false | 得点フラグ |
| rolls | jsonb | NO | [] | ダイス値リスト |
| runners | jsonb | NO | [] | 走者状況（打席前） |
| runners_after | jsonb | NO | [] | 走者状況（打席後） |
| status | integer | NO | 0 | ステータス enum (draft:0, confirmed:1) |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `batter_id`, `pitcher_id`, `pinch_hit_for_id`, `game_id`, `(game_id, seq)` (unique), `(game_id, inning, half)`, `(game_id, status)`

---

### batting_styles

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| name | string | NO | — | スタイル名（一意） |
| description | string | YES | — | 説明 |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `name` (unique)

---

### biorhythms

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| name | string | NO | — | バイオリズム名（一意） |
| start_date | date | NO | — | 開始日 |
| end_date | date | NO | — | 終了日 |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `name` (unique)

---

### card_sets

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| name | string | NO | — | カードセット名 |
| year | integer | NO | — | 年度 |
| set_type | string | NO | "annual" | セット種別（annual等） |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `(year, set_type)` (unique)

---

### competition_entries

大会へのチーム参加エントリ。base_teamは派生チームの元チームを指す（トーナメント等で別名義参加時）。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| competition_id | bigint | NO | — | competitions FK |
| team_id | bigint | NO | — | teams FK |
| base_team_id | bigint | YES | — | teams FK（元チーム、任意） |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `competition_id`, `team_id`, `base_team_id`, `(competition_id, team_id)` (unique)

---

### competition_rosters

大会エントリへの選手カード登録。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| competition_entry_id | bigint | NO | — | competition_entries FK |
| player_card_id | bigint | NO | — | player_cards FK |
| squad | integer | NO | — | 軍種別 enum (first_squad:0, second_squad:1) |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `competition_entry_id`, `player_card_id`, `(competition_entry_id, player_card_id)` (unique)

---

### competitions

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| name | string | NO | — | 大会名 |
| year | integer | NO | — | 開催年 |
| competition_type | string | NO | — | 大会種別 (league_pennant/tournament) |
| rules | jsonb | NO | {} | ルール設定 |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `competition_type`, `(name, year)` (unique)

---

### cost_players

選手ごとのコスト値。コストリスト（costs）に対して登録。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| cost_id | bigint | NO | — | costs FK |
| player_id | bigint | NO | — | players FK |
| normal_cost | integer | YES | — | 通常コスト |
| relief_only_cost | integer | YES | — | リリーフ限定コスト |
| pitcher_only_cost | integer | YES | — | 投手限定コスト |
| fielder_only_cost | integer | YES | — | 野手限定コスト |
| two_way_cost | integer | YES | — | 二刀流コスト |
| cost_exempt | boolean | NO | false | コスト免除フラグ |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `cost_id`, `player_id`, `(cost_id, player_id)`

---

### costs

コストリストマスタ。`end_date IS NULL` が現在有効なコストリスト。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| name | string | YES | — | コストリスト名 |
| start_date | date | YES | — | 開始日 |
| end_date | date | YES | — | 終了日（NULLが現在有効） |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `end_date` (unique, WHERE end_date IS NULL) — 現在有効コストリストが1件であることを保証

---

### game_events

試合内の特殊イベント（盗塁・暴投等）ログ。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| game_id | bigint | NO | — | games FK |
| seq | integer | NO | — | 試合内連番（一意） |
| inning | integer | NO | — | イニング |
| half | string | NO | — | 表/裏 (top/bottom) |
| event_type | string | NO | — | イベント種別 |
| details | jsonb | NO | {} | イベント詳細 |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `event_type`, `game_id`, `(game_id, seq)` (unique), `(game_id, inning, half)`

---

### game_lineup_entries

試合ラインナップの個別エントリ（先発・ベンチ・オフ・DH指名選手）。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| game_id | bigint | NO | — | games FK |
| player_card_id | bigint | NO | — | player_cards FK |
| role | integer | NO | — | 役割 enum (starter:0, bench:1, off:2, designated_player:3) |
| batting_order | integer | YES | — | 打順 (1-9) |
| position | string | YES | — | 守備位置 (P/C/1B/2B/3B/SS/LF/CF/RF/DH) |
| is_dh_pitcher | boolean | NO | false | DH制投手フラグ |
| is_reliever | boolean | NO | false | 中継ぎフラグ |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `game_id`, `player_card_id`, `(game_id, player_card_id)` (unique)

---

### game_lineups

チームの試合用ラインナップ一時保存テーブル（1チーム1件）。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| team_id | bigint | NO | — | teams FK（一意） |
| lineup_data | jsonb | NO | {} | ラインナップデータ |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `team_id` (unique)

---

### game_records

ログ解析結果の試合単位データ。IRC ログから解析して生成。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| team_id | bigint | NO | — | teams FK |
| game_id | bigint | YES | — | games FK（紐付け後） |
| game_date | date | YES | — | 試合日 |
| opponent_team_name | string | YES | — | 対戦チーム名 |
| result | string | YES | — | 試合結果 (win/lose/draw) |
| score_home | integer | YES | — | 自チームスコア（ホーム時） |
| score_away | integer | YES | — | 自チームスコア（アウェイ時） |
| stadium | string | YES | — | 球場名 |
| played_at | datetime | YES | — | 試合実施日時 |
| parsed_at | datetime | YES | — | 解析実施日時 |
| confirmed_at | datetime | YES | — | 確定日時 |
| parser_version | string | YES | — | パーサーバージョン |
| source_log | text | YES | — | ソースログ原文 |
| status | string | NO | "draft" | ステータス (draft/confirmed) |
| batting_stats | jsonb | YES | — | 打撃成績集計 |
| pitching_stats | jsonb | YES | — | 投手成績集計 |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `game_date`, `status`, `team_id`, `game_id` (unique, WHERE game_id IS NOT NULL)

---

### games

試合データ（ライブ入力・ログインポート・サマリー）。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| competition_id | bigint | NO | — | competitions FK |
| home_team_id | bigint | NO | — | teams FK（ホームチーム） |
| visitor_team_id | bigint | NO | — | teams FK（ビジターチーム） |
| stadium_id | bigint | YES | — | stadiums FK |
| real_date | date | YES | — | 実際の試合日 |
| home_score | integer | YES | — | ホームスコア |
| visitor_score | integer | YES | — | ビジタースコア |
| dh | boolean | YES | false | DH制フラグ |
| status | string | NO | "draft" | ステータス (draft/confirmed) |
| source | string | NO | "live" | データソース (live/log_import/summary) |
| raw_log | text | YES | — | 生ログ |
| roster_data | jsonb | NO | {} | ロスターデータ |
| home_game_number | integer | YES | — | ホームチーム試合番号 |
| visitor_game_number | integer | YES | — | ビジターチーム試合番号 |
| home_schedule_date | string | YES | — | ホームチームのスケジュール日付文字列 |
| visitor_schedule_date | string | YES | — | ビジターチームのスケジュール日付文字列 |
| setting_date | string | YES | — | 設定日付文字列 |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `competition_id`, `home_team_id`, `visitor_team_id`, `stadium_id`, `status`, `(home_team_id, visitor_team_id, real_date)`

---

### imported_stats

外部からインポートした選手成績統計（打撃または投球）。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| player_id | bigint | NO | — | players FK |
| competition_id | bigint | NO | — | competitions FK |
| team_id | bigint | NO | — | teams FK |
| stat_type | string | NO | — | 統計種別 (batting/pitching) |
| stats | jsonb | NO | {} | 成績データ |
| as_of_date | string | YES | — | 統計基準日（文字列） |
| as_of_game_number | integer | YES | — | 統計基準試合番号 |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `competition_id`, `player_id`, `team_id`, `(player_id, competition_id, stat_type)` (unique)

---

### lineup_template_entries

ラインナップテンプレートの個別エントリ（打順×選手×ポジション）。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| lineup_template_id | bigint | NO | — | lineup_templates FK |
| player_id | bigint | NO | — | players FK |
| batting_order | integer | NO | — | 打順 (1-9) |
| position | string | NO | — | 守備位置 |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `lineup_template_id`, `player_id`, `(lineup_template_id, batting_order)` (unique)

---

### lineup_templates

オーダーテンプレート。投手の左右×DH有無の組み合わせ（最大4パターン）でチームごとに保持。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| team_id | bigint | NO | — | teams FK |
| dh_enabled | boolean | NO | — | DH制有効フラグ |
| opponent_pitcher_hand | string | NO | — | 対戦投手の投げ手 (left/right) |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `team_id`, `(team_id, dh_enabled, opponent_pitcher_hand)` (unique)

---

### managers

監督・コーチマスタ。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| name | string | YES | — | 氏名 |
| short_name | string | YES | — | 短縮名 |
| irc_name | string | YES | — | IRC名 |
| user_id | string | YES | — | ユーザーID（文字列） |
| role | integer | NO | 0 | 役割 enum (director:0, coach:1) |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

---

### pitcher_game_states

投手の試合ごとの登板状態。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| game_id | bigint | NO | — | games FK |
| pitcher_id | bigint | NO | — | players FK（投手） |
| competition_id | bigint | NO | — | competitions FK |
| team_id | bigint | NO | — | teams FK |
| role | string | NO | — | 役割 (starter/reliever/opener) |
| innings_pitched | decimal(5,1) | YES | — | 投球回数 |
| cumulative_innings | integer | YES | 0 | 累積イニング数 |
| earned_runs | integer | NO | 0 | 自責点 |
| fatigue_p_used | integer | YES | 0 | 疲労P使用量 |
| decision | string | YES | — | 勝敗 (W/L/S/H) |
| result_category | string | YES | — | 結果カテゴリ (normal/ko/no_game/long_loss) |
| injury_check | string | YES | — | 怪我チェック結果 (safe/injured) |
| schedule_date | string | YES | — | スケジュール日付文字列 |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `competition_id`, `game_id`, `pitcher_id`, `team_id`, `decision`, `(game_id, pitcher_id)` (unique)

---

### pitching_styles

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| name | string | NO | — | 投球スタイル名（一意） |
| description | string | YES | — | 説明 |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `name` (unique)

---

### player_absences

選手の離脱記録。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| team_membership_id | bigint | NO | — | team_memberships FK |
| season_id | bigint | NO | — | seasons FK |
| absence_type | integer | NO | — | 離脱種別 enum (injury:0, suspension:1, reconditioning:2) |
| start_date | date | NO | — | 離脱開始日 |
| duration | integer | NO | — | 離脱期間（数値） |
| duration_unit | string | NO | — | 期間単位 (days/games) |
| reason | text | YES | — | 理由 |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `season_id`, `team_membership_id`

---

### player_card_abilities

選手カードとアビリティの中間テーブル。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| player_card_id | bigint | NO | — | player_cards FK |
| ability_definition_id | bigint | NO | — | ability_definitions FK |
| condition_id | bigint | YES | — | trait_conditions FK（発動条件） |
| role | string | YES | — | 適用役割（投手/野手等） |
| sort_order | integer | YES | 0 | 表示順 |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `ability_definition_id`, `condition_id`, `player_card_id`

---

### player_card_defenses

選手カードの守備能力。ポジションごとに登録。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| player_card_id | bigint | NO | — | player_cards FK |
| position | string | NO | — | 守備位置 |
| range_value | integer | NO | — | 守備範囲値 |
| error_rank | string | NO | — | エラーランク |
| throwing | string | YES | — | 送球能力 |
| condition_id | bigint | YES | — | trait_conditions FK（条件付き守備時） |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `condition_id`, `player_card_id`, `(player_card_id, position, condition_id)` (unique)

---

### player_card_exclusive_catchers

特定選手カードに対する専用捕手制約（複合主キー）。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| player_card_id | bigint | NO | — | player_cards FK（主キーの一部） |
| catcher_player_id | bigint | NO | — | players FK（捕手）（主キーの一部） |

**主キー**: `(player_card_id, catcher_player_id)` (複合)

---

### player_card_player_types

選手カードとプレイヤータイプの中間テーブル。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| player_card_id | bigint | NO | — | player_cards FK |
| player_type_id | bigint | NO | — | player_types FK |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `player_card_id`, `player_type_id`, `(player_card_id, player_type_id)` (unique)

---

### player_card_traits

選手カードとトレイト（特徴）の中間テーブル。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| player_card_id | bigint | NO | — | player_cards FK |
| trait_definition_id | bigint | NO | — | trait_definitions FK |
| condition_id | bigint | YES | — | trait_conditions FK（条件付きトレイト時） |
| role | string | YES | — | 適用役割 |
| sort_order | integer | YES | 0 | 表示順 |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `condition_id`, `player_card_id`, `trait_definition_id`

---

### player_cards

選手カードデータ。1選手×1カードセット×1カード種別（pitcher/batter）で一意。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| player_id | bigint | NO | — | players FK |
| card_set_id | bigint | NO | — | card_sets FK |
| card_type | string | NO | — | カード種別 (pitcher/batter) |
| card_label | string | YES | — | カードラベル（特別カード名等） |
| handedness | string | YES | — | 利き手（投打方向） |
| is_pitcher | boolean | YES | — | 投手フラグ |
| is_relief_only | boolean | YES | — | リリーフ専用フラグ |
| is_closer | boolean | NO | false | クローザーフラグ |
| is_switch_hitter | boolean | NO | false | スイッチヒッターフラグ |
| is_dual_wielder | boolean | NO | false | 二刀流フラグ |
| batting_style_id | bigint | YES | — | batting_styles FK |
| pitching_style_id | bigint | YES | — | pitching_styles FK（主投球スタイル） |
| pinch_pitching_style_id | bigint | YES | — | pitching_styles FK（緊急登板スタイル） |
| catcher_pitching_style_id | bigint | YES | — | pitching_styles FK（捕手投球スタイル） |
| speed | integer | YES | — | 走力 (1-5) |
| bunt | integer | YES | — | バント (1-10) |
| steal_start | integer | YES | — | 盗塁開始値 (1-22) |
| steal_end | integer | YES | — | 盗塁終了値 (1-22) |
| injury_rate | integer | YES | — | 怪我率 (0-7) |
| starter_stamina | integer | YES | — | 先発スタミナ (4-9) |
| relief_stamina | integer | YES | — | 中継ぎスタミナ (0-3) |
| special_defense_c | string | YES | — | 特殊守備C（例: "3A"） |
| special_throwing_c | integer | YES | — | 特殊送球C (-5〜5) |
| batting_table | jsonb | NO | {} | 打撃結果テーブル |
| pitching_table | jsonb | NO | {} | 投球結果テーブル |
| irc_display_name | string | YES | — | IRC表示名 |
| irc_macro_name | string | YES | — | IRCマクロ名 |
| biorhythm_period | string | YES | — | バイオリズム周期 |
| biorhythm_date_ranges | jsonb | YES | — | バイオリズム適用日付範囲 |
| injury_traits | jsonb | YES | — | 怪我トレイト設定 |
| unique_traits | text | YES | — | ユニーク特徴（テキスト） |
| pitching_style_description | string | YES | — | 投球スタイル説明（旧カラム、互換用） |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `batting_style_id`, `card_set_id`, `catcher_pitching_style_id`, `pinch_pitching_style_id`, `pitching_style_id`, `player_id`, `(card_set_id, player_id, card_type)` (unique)

**Active Storage**: `card_image` — カード画像ファイル（`has_one_attached :card_image`）

---

### player_types

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| name | string | NO | — | タイプ名（一意） |
| category | string | YES | — | カテゴリ |
| description | text | YES | — | 説明 |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `name` (unique)

---

### players

選手マスタ。カードデータ・チーム所属・コストとは別管理。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| name | string | NO | — | 選手名 |
| number | string | NO | — | 背番号 |
| short_name | string | YES | — | 短縮名 |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

---

### schedule_details

スケジュールの日付単位エントリ。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| schedule_id | bigint | NO | — | schedules FK |
| date | date | YES | — | 日付 |
| date_type | string | YES | — | 日付種別 (game_day/off_day等) |
| priority | integer | YES | — | 優先度 |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `schedule_id`, `(schedule_id, date)` (unique)

---

### schedules

スケジュールマスタ。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| name | string | YES | — | スケジュール名 |
| start_date | date | YES | — | 開始日 |
| end_date | date | YES | — | 終了日 |
| effective_date | date | YES | — | 有効開始日 |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

---

### season_rosters

シーズンロスター（公示履歴）。チームメンバーシップ単位で登録。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| season_id | bigint | NO | — | seasons FK |
| team_membership_id | bigint | NO | — | team_memberships FK |
| squad | string | NO | — | 軍種別 (first/second) |
| registered_on | date | NO | — | 登録日 |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `season_id`, `team_membership_id`

---

### season_schedules

チームシーズンの試合スケジュール（結果含む）。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| season_id | bigint | NO | — | seasons FK |
| date | date | NO | — | 試合日 |
| date_type | string | YES | — | 日付種別 (game_day/interleague_game_day/off等) |
| home_away | string | YES | — | 主客区分 (home/visitor) |
| game_number | integer | YES | — | 試合番号 |
| opponent_team_id | bigint | YES | — | teams FK（対戦チーム） |
| stadium | string | YES | — | 球場名 |
| designated_hitter_enabled | boolean | YES | — | DH制フラグ |
| score | integer | YES | — | 自チームスコア |
| opponent_score | integer | YES | — | 対戦チームスコア |
| announced_starter_id | bigint | YES | — | team_memberships FK（先発予告投手） |
| winning_pitcher_id | bigint | YES | — | players FK（勝利投手） |
| losing_pitcher_id | bigint | YES | — | players FK（敗戦投手） |
| save_pitcher_id | bigint | YES | — | players FK（セーブ投手） |
| starting_lineup | jsonb | YES | — | 先発ラインナップ |
| opponent_starting_lineup | jsonb | YES | — | 対戦チーム先発ラインナップ |
| scoreboard | jsonb | YES | — | イニング別スコア |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `announced_starter_id`, `losing_pitcher_id`, `opponent_team_id`, `save_pitcher_id`, `season_id`, `winning_pitcher_id`

---

### seasons

チームのシーズン管理（1チーム1シーズン）。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| team_id | bigint | NO | — | teams FK（一意） |
| name | string | NO | — | シーズン名 |
| current_date | date | NO | — | シーズン内現在日 |
| team_type | string | YES | — | チーム種別 |
| key_player_id | bigint | YES | — | team_memberships FK（キー選手） |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `key_player_id`, `team_id`

---

### squad_text_settings

チームのスカッドテキスト（IRC投稿用オーダーテキスト）生成設定。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| team_id | bigint | NO | — | teams FK（一意） |
| handedness_format | string | YES | "alphabet" | 利き手表記形式 |
| position_format | string | YES | "english" | ポジション表記形式 |
| date_format | string | YES | "absolute" | 日付表記形式 |
| section_header_format | string | YES | "bracket" | セクションヘッダー形式 |
| show_number_prefix | boolean | YES | true | 背番号プレフィックス表示フラグ |
| batting_stats_config | jsonb | YES | {} | 打撃成績表示設定（avg/hr/rbi等のON/OFF） |
| pitching_stats_config | jsonb | YES | {} | 投球成績表示設定（w_l/era等のON/OFF） |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `team_id` (unique)

---

### stadiums

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| name | string | NO | — | 球場名（一意） |
| code | string | NO | — | 球場コード（一意） |
| indoor | boolean | NO | false | 屋内球場フラグ |
| up_table_ids | jsonb | NO | [] | UPテーブルIDリスト |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `code` (unique), `name` (unique)

---

### team_managers

チームと監督・コーチの紐付けテーブル。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| team_id | bigint | NO | — | teams FK |
| manager_id | bigint | NO | — | managers FK |
| role | integer | NO | 0 | 役割 enum (director:0, coach:1) |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `manager_id`, `team_id`

---

### team_memberships

チームと選手の所属関係。コスト種別・軍種別・除外設定を管理。

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| team_id | bigint | NO | — | teams FK |
| player_id | bigint | NO | — | players FK |
| squad | string | NO | "second" | 軍種別 (first/second) |
| selected_cost_type | string | NO | "normal_cost" | 選択コスト種別 |
| display_name | string | YES | — | 表示名（オーバーライド用） |
| excluded_from_team_total | boolean | NO | false | チーム合計コスト除外フラグ |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `player_id`, `team_id`, `(team_id, player_id)` (unique)

---

### teams

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| name | string | YES | — | チーム名 |
| short_name | string | YES | — | 短縮名 |
| is_active | boolean | YES | true | アクティブフラグ |
| user_id | bigint | YES | — | users FK（オーナーユーザー） |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

---

### trait_conditions

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| name | string | NO | — | 条件名（一意） |
| description | text | YES | — | 説明 |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `name` (unique)

---

### trait_definitions

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| name | string | NO | — | トレイト名（一意） |
| typical_role | string | YES | — | 典型的役割（※`default_role`はRails 8予約語のため`typical_role`を使用） |
| description | text | YES | — | 説明 |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

**インデックス**: `name` (unique)

---

### users

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|-----|------|-----------|------|
| id | bigint | NO | (auto) | 主キー |
| name | string | YES | — | ログイン名（一意） |
| display_name | string | YES | — | 表示名 |
| password_digest | string | YES | — | bcryptパスワードハッシュ（has_secure_password） |
| role | integer | NO | 0 | ロール enum (player:0, commissioner:1) |
| created_at | datetime | NO | — | 作成日時 |
| updated_at | datetime | NO | — | 更新日時 |

---

## JSONBカラム構造

### player_cards.batting_table / pitching_table

打撃・投球結果テーブル。ダイス目（1〜22）をキーとして結果コードを格納するハッシュ形式。

```json
{
  "1": "HR",
  "2": "H3",
  ...
  "22": "K"
}
```

### player_cards.biorhythm_date_ranges

バイオリズム適用日付範囲のリスト。

```json
[
  { "start": "2025-04-01", "end": "2025-04-10" }
]
```

### games.roster_data

試合時点でのロスターデータスナップショット。

### at_bats.rolls

打席で使用したダイス値のリスト。

```json
[{ "type": "bat", "value": 12 }, { "type": "pitch", "value": 7 }]
```

### at_bats.runners / runners_after

走者状況。塁（1B/2B/3B）をキーとした選手情報ハッシュ。

### at_bat_records.discrepancies / source_events

解析不一致リスト・ソースイベントリスト（配列形式）。

### squad_text_settings.batting_stats_config / pitching_stats_config

成績表示設定。各成績項目をキー、ON/OFFをbooleanで保持。

```json
{
  "avg": true,
  "hr": true,
  "rbi": true,
  "sb": false,
  "obp": false,
  "ops": false,
  "ab_h": false
}
```

### season_schedules.starting_lineup / scoreboard

ラインナップ・スコアボードのJSONデータ（構造はアプリ実装依存）。

---

## 外部キー一覧

| テーブル | カラム | 参照先テーブル | 参照カラム | on_delete |
|---------|--------|--------------|-----------|-----------|
| active_storage_attachments | blob_id | active_storage_blobs | id | — |
| active_storage_variant_records | blob_id | active_storage_blobs | id | — |
| at_bat_records | game_record_id | game_records | id | — |
| at_bats | game_id | games | id | — |
| at_bats | batter_id | players | id | — |
| at_bats | pitcher_id | players | id | — |
| at_bats | pinch_hit_for_id | players | id | — |
| competition_entries | competition_id | competitions | id | — |
| competition_entries | team_id | teams | id | — |
| competition_entries | base_team_id | teams | id | — |
| competition_rosters | competition_entry_id | competition_entries | id | — |
| competition_rosters | player_card_id | player_cards | id | — |
| cost_players | cost_id | costs | id | — |
| cost_players | player_id | players | id | — |
| game_events | game_id | games | id | — |
| game_lineups | team_id | teams | id | — |
| game_records | game_id | games | id | nullify |
| game_records | team_id | teams | id | — |
| games | competition_id | competitions | id | — |
| games | stadium_id | stadiums | id | — |
| games | home_team_id | teams | id | — |
| games | visitor_team_id | teams | id | — |
| imported_stats | competition_id | competitions | id | — |
| imported_stats | player_id | players | id | — |
| imported_stats | team_id | teams | id | — |
| lineup_template_entries | lineup_template_id | lineup_templates | id | — |
| lineup_template_entries | player_id | players | id | — |
| lineup_templates | team_id | teams | id | — |
| pitcher_game_states | competition_id | competitions | id | — |
| pitcher_game_states | game_id | games | id | — |
| pitcher_game_states | pitcher_id | players | id | — |
| pitcher_game_states | team_id | teams | id | — |
| player_absences | season_id | seasons | id | — |
| player_absences | team_membership_id | team_memberships | id | — |
| player_card_abilities | ability_definition_id | ability_definitions | id | — |
| player_card_abilities | player_card_id | player_cards | id | — |
| player_card_abilities | condition_id | trait_conditions | id | — |
| player_card_defenses | player_card_id | player_cards | id | — |
| player_card_defenses | condition_id | trait_conditions | id | — |
| player_card_exclusive_catchers | player_card_id | player_cards | id | — |
| player_card_exclusive_catchers | catcher_player_id | players | id | — |
| player_card_player_types | player_card_id | player_cards | id | — |
| player_card_player_types | player_type_id | player_types | id | — |
| player_card_traits | player_card_id | player_cards | id | — |
| player_card_traits | condition_id | trait_conditions | id | — |
| player_card_traits | trait_definition_id | trait_definitions | id | — |
| player_cards | batting_style_id | batting_styles | id | — |
| player_cards | card_set_id | card_sets | id | — |
| player_cards | pitching_style_id | pitching_styles | id | — |
| player_cards | catcher_pitching_style_id | pitching_styles | id | — |
| player_cards | pinch_pitching_style_id | pitching_styles | id | — |
| player_cards | player_id | players | id | — |
| schedule_details | schedule_id | schedules | id | — |
| season_rosters | season_id | seasons | id | — |
| season_rosters | team_membership_id | team_memberships | id | — |
| season_schedules | announced_starter_id | team_memberships | id | — |
| season_schedules | losing_pitcher_id | players | id | — |
| season_schedules | save_pitcher_id | players | id | — |
| season_schedules | winning_pitcher_id | players | id | — |
| season_schedules | season_id | seasons | id | — |
| season_schedules | opponent_team_id | teams | id | — |
| seasons | key_player_id | team_memberships | id | — |
| seasons | team_id | teams | id | — |
| squad_text_settings | team_id | teams | id | — |
| team_managers | manager_id | managers | id | — |
| team_managers | team_id | teams | id | — |
| team_memberships | player_id | players | id | — |
| team_memberships | team_id | teams | id | — |

---

## ER関係（主要テーブル）

```
users
  └── teams (user_id, nullify on delete)

teams
  ├── team_memberships → players
  ├── competition_entries → competitions
  ├── season (1:1)
  │   ├── season_schedules
  │   └── player_absences ← team_memberships
  ├── games (home_team / visitor_team) → competitions → stadiums
  ├── lineup_templates → lineup_template_entries → players
  ├── squad_text_setting (1:1)
  ├── game_lineups (1:1)
  └── team_managers → managers

player_cards
  ├── players
  ├── card_sets
  ├── batting_styles / pitching_styles
  ├── player_card_defenses (条件付き守備)
  ├── player_card_traits → trait_definitions (+ trait_conditions)
  ├── player_card_abilities → ability_definitions (+ trait_conditions)
  ├── player_card_player_types → player_types
  ├── player_card_exclusive_catchers → players (専用捕手)
  └── [Active Storage] card_image

costs
  └── cost_players → players

games
  ├── at_bats → players (batter/pitcher)
  ├── game_events
  ├── pitcher_game_states → players
  ├── game_lineup_entries → player_cards
  └── game_record → at_bat_records

competitions
  ├── competition_entries → teams
  │   └── competition_rosters → player_cards
  ├── games
  ├── pitcher_game_states
  └── imported_stats → players
```
