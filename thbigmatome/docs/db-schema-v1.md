# DBスキーマ設計 v1 — 東方BIG野球まとめ

最終更新: 2026-02-21

## 設計方針

- **イベント格納**: 混合方式（打席=専用テーブル、盗塁・交代等=JSONB）
- **成績集計**: 都度計算（5,000打席/シーズン程度、SQLで十分な規模）
- **投手休養状態**: 試合確定時にスナップショット保存（参照頻度が高いため）
- **選手カードデータ**: 年次版管理（card_sets + player_cards）
- **大会スコープ**: v1はLペナのみ対応。他大会は将来拡張
- **シーズン中途導入**: imported_statsで導入前の成績サマリーを保持、at_bats集計と合算表示
- 将来リーグ全体集計が必要になったらマテリアライズドビューを検討

## 新規テーブル

### 試合系

#### games — 試合レコード

| カラム | 型 | 説明 |
|--------|-----|------|
| id | bigint PK | |
| competition_id | bigint FK → competitions | 所属大会 |
| home_team_id | bigint FK → teams | ホームチーム |
| visitor_team_id | bigint FK → teams | ビジターチーム |
| stadium_id | bigint FK → stadiums | 球場 |
| dh | boolean | DH制有無 |
| setting_date | string | バイオリズム基準日（ゲーム内日付） |
| home_schedule_date | string | ホームチームの日程日 |
| visitor_schedule_date | string | ビジターチームの日程日 |
| home_game_number | integer | ホーム側の第N試合 |
| visitor_game_number | integer | ビジター側の第N試合 |
| real_date | date | 実試合日（プレイヤーが現実で試合した日） |
| home_score | integer | ホーム得点 |
| visitor_score | integer | ビジター得点 |
| status | string | draft / confirmed |
| source | string | live / log_import / summary |
| raw_log | text | IRCログ原文 |
| roster_data | jsonb | オーダー決定事項 + 生成テキスト（下記参照） |
| created_at | datetime | |
| updated_at | datetime | |

##### roster_data のJSONB構造

ユーザーの「決定事項」のみ格納する。成績・疲労等は生成時にDBから計算。
生成後のIRCテキスト全文も保存し、「あのとき何を貼ったか」を記録する。

```json
{
  "roster_changes": [
    {"type": "register", "player_id": 123, "player_name": "赤蛮奇"},
    {"type": "deregister", "player_id": 456, "player_name": "鍵山雛"}
  ],
  "starting_lineup": [
    {"order": 1, "position": "C",  "player_id": 101},
    {"order": 2, "position": "3B", "player_id": 102},
    {"order": 3, "position": "LF", "player_id": 103},
    {"order": 4, "position": "1B", "player_id": 104},
    {"order": 5, "position": "2B", "player_id": 105},
    {"order": 6, "position": "RF", "player_id": 106},
    {"order": 7, "position": "CF", "player_id": 107},
    {"order": 8, "position": "SS", "player_id": 108},
    {"order": 9, "position": "P",  "player_id": 109}
  ],
  "starting_pitcher_id": 110,
  "designated_player_id": 104,
  "off_player_ids": [201, 202],
  "generated_text": "（生成されたIRC貼付けテキスト全文）"
}
```

各フィールド:
- `roster_changes`: 公示（登録/抹消）。なければ空配列
- `starting_lineup`: 打順順に並べた9人（DH時は10人）。orderの並び = 打順
- `starting_pitcher_id`: 先発投手
- `designated_player_id`: 怪我の特例を受けている選手（nullable）
- `off_player_ids`: ベンチ入りしない選手（オフ指定。前回登板が近い投手等）
- `generated_text`: 生成時点のIRC出力テキスト全文（スナップショット）

##### IRC出力テキスト生成仕様

若尊バレーナフォーマットをベースに、以下を自動生成する。

**生成セクションと自動計算の対応**:

| セクション | 生成内容 | データ源 |
|-----------|---------|---------|
| ヘッダー | チーム名、Match番号、日程日 | teams + games (試合数集計) |
| 指定選手 | 背番号+選手名 + 通算成績 | designated_player_id + games集計 |
| スタメン | 位置 背番号 短縮名 投打 打率 HR 打点 | starting_lineup + imported_stats/at_bats集計 |
| 控え野手 | 背番号 短縮名 投打 打率 HR 打点 | 1軍野手 − スタメン野手 |
| 中継ぎ投手 | 背番号 短縮名 投打 防御率 累積イニング | 1軍リリーフ − off_player_ids + pitcher_game_states |
| 先発ベンチ | 背番号 短縮名 投打 防御率 中N日 + オフ表示 | 1軍先発 − starting_pitcher + pitcher_game_states |
| 登板履歴 | 日付 ○/●投手名 イニング→... | pitcher_game_states + games (直近7〜10日分) |

**出力テンプレート例**:
```
【{チーム名}】	Match:{N}	{日程日}（{曜日}）
指定選手：{背番号} {選手名}	通算成績	{W}勝{L}敗{D}分
{位置}	{背番号}	{短縮名}	{投}	{打}	{打率}	{HR}	{打点}
{位置}	{背番号}	{短縮名}	{投}	{打}	{打率}	{HR}	{打点}
...（9行 = 打順）
控え野手
	{背番号}	{短縮名}	{投}	{打}	{打率}	{HR}	{打点}
	...
中継ぎ投手						累積
(中継)	{背番号}	{短縮名}	{投}	{打}	{防御率}	{累積}
	...
先発ベンチ					防御率	間隔
	{背番号}	{短縮名}	{投}	{打}	{防御率}	中{N}日
オフ
	{背番号}	{短縮名}	{投}	{打}	{防御率}	中{N}日
	...
登板履歴
{MM/DD}	{○/●}{投手名}{イニング}→{H/S}{投手名}{イニング}→...
...
```

**注意事項**:
- 短縮名(short_name)はplayersテーブルに格納済み
- 投打はR/L/S形式（players.throwing_hand, batting_hand）
- 累積イニング: pitcher_game_statesから計算（リリーフのみ）
- 中N日: pitcher_game_statesのschedule_date差分（負傷期間除外）
- (中継)マーク: リリーフ契約の投手に自動付与（player_card_player_typesで判定。記載義務あり）
- 登板履歴の○●: games結果から勝敗を判定、H=ホールド、S=セーブ
- 打率"-": 打席0の場合

#### at_bats — 打席（専用テーブル、成績集計の主役）

| カラム | 型 | 説明 |
|--------|-----|------|
| id | bigint PK | |
| game_id | bigint FK → games | |
| seq | integer | イベント通し番号（game_eventsと共有） |
| inning | integer | イニング |
| half | string | top(表) / bottom(裏) |
| outs | integer | 打席開始時アウトカウント |
| runners | jsonb | 打席開始時走者 例: ["1B","2B"] |
| batter_id | bigint FK → players | 打者 |
| pitcher_id | bigint FK → players | 投手 |
| pinch_hit_for_id | bigint FK → players (nullable) | 代打元（nullなら通常打席） |
| play_type | string | 作戦指示（後述） |
| rolls | jsonb | ダイスロール列（発生順） |
| result_code | string | 打撃結果コード（後述） |
| rbi | integer | 打点 |
| scored | boolean | 打者が生還したか |
| runners_after | jsonb | 打席終了時走者 |
| outs_after | integer | 打席終了時アウトカウント |
| created_at | datetime | |
| updated_at | datetime | |

##### play_type — 打席時の作戦指示

| 値 | 意味 |
|-----|------|
| normal | 通常打撃 |
| bunt | 犠牲バント |
| squeeze | スクイズ |
| safety_bunt | セーフティバント |
| hit_and_run | エンドラン |

犠打判定: play_type IN (bunt, squeeze) + 結果がアウト + 走者進塁 → 打数から除外
犠飛判定: result_code が F# + 3塁走者が得点 → 打数から除外

##### result_code — 打撃結果コード

最終結果のみを記録。レンジチェック経由・UP表経由の情報はrollsに記録。

**打者アウト系**
| コード | 意味 |
|--------|------|
| K | 三振 |
| PO | 内野フライ |

**ゴロ系**（#=守備位置番号1-9）
| コード | 意味 |
|--------|------|
| G#f | フォースゴロ（先行走者アウト、打者1塁） |
| G#a | アドバンスゴロ（走者進塁可） |
| G#D | 併殺ゴロ |

**安打系**
| コード | 意味 |
|--------|------|
| IH# | 内野安打（1進塁、積極走塁不可） |
| H# | 外野安打（1進塁+積極走塁可） |
| H#a | 長め外野安打（確定2進塁） |
| 2H# | 二塁打（2進塁+1塁走者積極走塁可） |
| 2H#a | 長い二塁打（走者一掃確定） |
| 3H# | 三塁打（全員生還） |
| HR# | 本塁打（全員生還） |

**四死球**
| コード | 意味 |
|--------|------|
| BB | 四球 |
| DB | 死球 |

**レンジチェック経由**
| コード | 意味 |
|--------|------|
| F# | フライアウト |
| F#a | フライアウト（積極走塁可） |
| LD | ライナー（打者+先頭走者アウト） |

**その他**
| コード | 意味 |
|--------|------|
| UP | UP表参照（好プレー珍プレー） |

※ レアケースは実際のIRCログ解析時に補完する。

##### rolls のJSONB構造例

```json
// 通常の打席
[
  {"type": "pitch", "die": 14, "result": 3},
  {"type": "batting", "die": 8, "result": "H7"},
  {"type": "running", "die": 12, "result": "safe"}
]

// レンジチェック経由（position=チェック対象野手）
[
  {"type": "pitch", "die": 14, "result": 3},
  {"type": "batting", "die": 8, "result": "range", "position": 5},
  {"type": "range", "die": 12, "result": "H7"}
]

// エラーチェック経由（UP表ルート）
[
  {"type": "pitch", "die": 14, "result": 3},
  {"type": "batting", "die": 8, "result": "UP"},
  {"type": "up", "die": 15, "result": "error_check"},
  {"type": "error_check", "die": 12, "fielder": 6, "rank": "B", "result": "E2"}
]
```

#### game_events — 打席以外のイベント（盗塁・交代等）

| カラム | 型 | 説明 |
|--------|-----|------|
| id | bigint PK | |
| game_id | bigint FK → games | |
| seq | integer | イベント通し番号（at_batsと共有） |
| event_type | string | steal / substitution / etc |
| inning | integer | |
| half | string | top / bottom |
| details | jsonb | 種別ごとの詳細 |
| created_at | datetime | |
| updated_at | datetime | |

details のJSONB構造例:
```json
// 盗塁
{
  "runner_id": 123,
  "from": "1B", "to": "2B",
  "rolls": [
    {"type": "start", "die": 8},
    {"type": "steal", "die": 14, "result": "safe"}
  ]
}

// 選手交代
{
  "sub_type": "pitcher_change",
  "player_in_id": 456,
  "player_out_id": 789
}
```

#### pitcher_game_states — 投手状態スナップショット

試合確定時（draft → confirmed）に、登板した全投手分を生成する。
次回試合準備時は最新スナップショット + 経過日数で判定（重い履歴走査不要）。

| カラム | 型 | 説明 |
|--------|-----|------|
| id | bigint PK | |
| game_id | bigint FK → games | この試合で更新された |
| pitcher_id | bigint FK → players | |
| competition_id | bigint FK → competitions | |
| team_id | bigint FK → teams | |
| role | string | starter / reliever / opener |
| innings_pitched | decimal | 投球イニング数（回跨ぎ考慮済み） |
| result_category | string | normal / ko / no_game / long_loss |
| cumulative_innings | integer | この試合終了時点の累積イニング（リリーフ用） |
| fatigue_p_used | integer | この試合で使った疲労P |
| injury_check | string (nullable) | null=不要 / safe / injured |
| schedule_date | string | このチームの日程日 |
| created_at | datetime | |

**バリデーション方針**: 登板不可・ルール違反は**警告のみ**（記録はブロックしない）。
裁定は運営が行うため、プレイヤーが確認できる形で表示する。

**判定フロー**:
1. pitcher_game_states からその投手の最新レコードを取得
2. 最新の schedule_date と今回の日程日から中日数を算出（player_absencesで負傷期間を除外）
3. role + result_category + 中日数 → 投手休養ルール表を参照して疲労Pを算出
4. リリーフなら cumulative_innings に休養日分の減衰を適用（3以下:-2/日、4以上:-1/日）

詳細ルール: [投手休養ルール完全解析](pitcher-rest-rules-analysis.md)

### マスタ系

#### stadiums — 球場マスタ

| カラム | 型 | 説明 |
|--------|-----|------|
| id | bigint PK | |
| name | string | 球場名（東京ドーム等） |
| code | string | 球場コード（1112, 1314等） |
| up_table_ids | jsonb | UP表対応 例: [1911, 1912] |
| indoor | boolean | 屋内球場か（西武ドーム=true） |
| created_at | datetime | |
| updated_at | datetime | |

### 中途導入支援

#### imported_stats — 導入前の成績サマリー

シーズン中途導入時に、導入前の成績集計値を格納する。
表示時は `at_bats` からの集計と合算してシーズン通算を出す。

| カラム | 型 | 説明 |
|--------|-----|------|
| id | bigint PK | |
| player_id | bigint FK → players | |
| competition_id | bigint FK → competitions | |
| team_id | bigint FK → teams | |
| stat_type | string | batting / pitching |
| as_of_date | string | この集計値の基準日（ゲーム内日付） |
| as_of_game_number | integer | 何試合目時点の集計か |
| stats | jsonb | 成績集計値（下記参照） |
| created_at | datetime | |
| updated_at | datetime | |

stats のJSONB構造:
```json
// stat_type = "batting"
{
  "plate_appearances": 320,
  "at_bats": 280,
  "hits": 78,
  "doubles": 15,
  "triples": 3,
  "home_runs": 12,
  "rbi": 45,
  "walks": 30,
  "hit_by_pitch": 5,
  "strikeouts": 60,
  "stolen_bases": 8,
  "sacrifice_bunts": 5,
  "sacrifice_flies": 3,
  "games": 80
}

// stat_type = "pitching"
{
  "games": 15,
  "games_started": 15,
  "wins": 8,
  "losses": 5,
  "saves": 0,
  "innings_pitched": 98.1,
  "hits_allowed": 85,
  "strikeouts": 72,
  "walks_allowed": 25,
  "earned_runs": 30,
  "home_runs_allowed": 8
}
```

**運用**:
- 導入時にExcelの集計シートから1チーム分を一括登録
- 1選手につき batting / pitching 各1レコード（両方ある二刀流は2レコード）
- シーズン通算表示: `imported_stats.stats + at_bats集計` の合算
- 導入前データの修正は `imported_stats` を直接編集（打席単位の修正は不可・不要）

**games.source との関係**:
| source | 意味 | データ粒度 |
|--------|------|-----------|
| live | リアルタイム記録（通常運用） | 打席レベル |
| log_import | IRCログからの遡及取込 | 打席レベル |
| summary | ダミー試合（imported_statsの紐づけ先等） | 集計値のみ |

**投手状態の初期化**:
- 中10日以上空いている投手 → 初期化不要（万全状態）
- 直近10日以内に登板した投手 → `pitcher_game_states` に手動スナップショットを1件登録
  - 直近1〜2試合のログがあれば正確に設定可能
  - なくても概算（登板日・role・イニング数）で実用上十分

### 大会系

#### competitions — 大会

| カラム | 型 | 説明 |
|--------|-----|------|
| id | bigint PK | |
| name | string | 大会名（Lペナント 2026, TLB 2026等） |
| competition_type | string | league_pennant / tournament / etc |
| year | integer | 年度 |
| rules | jsonb | 大会ルール（コスト上限・人数上限等） |
| created_at | datetime | |
| updated_at | datetime | |

rules のJSONB構造例:
```json
{
  "roster_limit": 28,
  "cost_limit": {"type": "tiered", "28": 120, "27": 119, "26": 117},
  "player_pool": "all"
}
```

v1ではLペナのみ対応。competitionsは成績をスコープするための箱として機能。
既存のチーム管理機能（teams, team_memberships, season_rosters）をそのまま活用する。

#### competition_entries — 大会参加（チーム×大会）

| カラム | 型 | 説明 |
|--------|-----|------|
| id | bigint PK | |
| competition_id | bigint FK → competitions | |
| team_id | bigint FK → teams | |
| base_team_id | bigint FK → teams (nullable) | TLBのベースチーム等（v1では未使用） |
| created_at | datetime | |
| updated_at | datetime | |

### 選手カード系

#### card_sets — カード改定セット

年次改定（毎年12月）+ 不定期追加（完走記念、エイプリルフール、新作追加等）に対応。

| カラム | 型 | 説明 |
|--------|-----|------|
| id | bigint PK | |
| year | integer | 年度 |
| name | string | セット名（"2026年版", "完走記念2026"等） |
| set_type | string | annual / supplement |
| created_at | datetime | |
| updated_at | datetime | |

ある選手の「現在有効なカード」= その選手が含まれる最新card_setのplayer_cardsを参照。

#### player_cards — 選手カードデータ（年次版管理）

players テーブルから年次で変わり得る属性を分離。
既存playersテーブルには不変の基本情報（name, short_name, number, position, throwing_hand, batting_hand）のみ残す。

| カラム | 型 | 説明 |
|--------|-----|------|
| id | bigint PK | |
| card_set_id | bigint FK → card_sets | |
| player_id | bigint FK → players | |
| speed | integer | 走力 |
| bunt | integer | バント値 |
| steal_start | integer | 盗塁スタート値 |
| steal_end | integer | 盗塁成功値 |
| injury_rate | integer | 怪我レベル |
| is_pitcher | boolean | 投手かどうか |
| is_relief_only | boolean | リリーフ専任（R付き） |
| starter_stamina | integer | 先発疲労P |
| relief_stamina | integer (nullable) | リリーフ疲労P（null=未記載） |
| batting_style_id | bigint FK → batting_styles | |
| batting_style_description | string | |
| pitching_style_id | bigint FK (nullable) | |
| pinch_pitching_style_id | bigint FK (nullable) | 走者あり時投球特徴 |
| catcher_pitching_style_id | bigint FK (nullable) | 専属捕手時投球特徴 |
| pitching_style_description | string | |
| defense_p | string | 守備値: 投手 |
| throwing_c | integer | 送球値: 投手 |
| defense_c | string | 守備値: 捕手 |
| special_defense_c | string | 特殊守備: 捕手 |
| special_throwing_c | integer | 特殊送球: 捕手 |
| defense_1b | string | 守備値: 一塁 |
| defense_2b | string | 守備値: 二塁 |
| defense_3b | string | 守備値: 三塁 |
| defense_ss | string | 守備値: 遊撃 |
| defense_of | string | 守備値: 外野（統合） |
| throwing_of | string | 送球値: 外野（統合） |
| defense_lf | string | 守備値: 左翼 |
| throwing_lf | string | 送球値: 左翼 |
| defense_cf | string | 守備値: 中堅 |
| throwing_cf | string | 送球値: 中堅 |
| defense_rf | string | 守備値: 右翼 |
| throwing_rf | string | 送球値: 右翼 |
| batting_table | jsonb | 打撃表（投球番号×出目、構造は下記参照） |
| pitching_table | jsonb | 投球P列（出目→投球番号、構造は下記参照） |
| abilities | jsonb | 特殊能力・特徴（構造は下記参照） |
| card_image_path | string (nullable) | カード画像ファイルパス/URL |
| created_at | datetime | |
| updated_at | datetime | |

##### abilities のJSONB構造

v1では「何を持っているか」の表示用。効果処理（試合シミュレーション）は将来対応。

```json
{
  "batting_styles": ["スイッチヒッター", "内野安打○"],
  "pitching_styles": ["対左○"],
  "batting_skills": ["満塁男"],
  "pitching_skills": ["クイック○"],
  "notes": "特殊: ○○の条件で△△"
}
```

各フィールド:
- `batting_styles`: 打撃特徴の名前リスト。なければ空配列
- `pitching_styles`: 投球特徴の名前リスト。なければ空配列
- `batting_skills`: 打撃特殊能力の名前リスト。なければ空配列
- `pitching_skills`: 投球特殊能力の名前リスト。なければ空配列
- `notes`: 分類が曖昧なもの・複雑な効果（ニナ等）のフリーテキスト補足（nullable）

将来のシミュレーション対応時にマスタYAML定義と紐づけ、notesの内容を正式なデータに昇格させる。

##### pitching_table のJSONB構造

出目1〜20 → 投球番号1〜5のマッピング。配列[20]、index 0 = 出目1。

各要素の型:
- `{"pitch": N}` — 確定投球番号
- `{"pitch": N, "fatigue": true}` — 疲労マーカー付き（`*`。疲労時に2→1, 3→2, 5→4へ劣化）
- `{"split": "lr", "left": N, "right": N}` — 対左右打者分岐
- `{"split": "runner", "none": N, "on": N}` — 走者有無分岐（P表記）

```json
// 例: 先発投手（疲労P=7）
[
  {"pitch": 1},                              // 出目1
  {"pitch": 1},                              // 出目2
  {"pitch": 2, "fatigue": true},             // 出目3  *2
  {"pitch": 2},                              // 出目4
  {"pitch": 2},                              // 出目5
  {"pitch": 3, "fatigue": true},             // 出目6  *3
  {"pitch": 3},                              // 出目7
  {"pitch": 3},                              // 出目8
  {"pitch": 3},                              // 出目9
  {"split": "lr", "left": 3, "right": 4},   // 出目10  3/4（対左→3、対右→4）
  {"pitch": 4},                              // 出目11
  {"pitch": 4},                              // 出目12
  {"pitch": 4},                              // 出目13
  {"split": "runner", "none": 4, "on": 5},  // 出目14  P（走者なし→4、走者あり→5）
  {"pitch": 5, "fatigue": true},             // 出目15  *5
  {"pitch": 5},                              // 出目16
  {"pitch": 5},                              // 出目17
  {"pitch": 5},                              // 出目18
  {"pitch": 5},                              // 出目19
  {"pitch": 5}                               // 出目20
]
```

ルックアップ: `pitching_table[die - 1]` → 投球番号を取得。splitの場合は条件に応じてleft/right or none/onを選択。

##### batting_table のJSONB構造

投球番号(1〜5) × 出目(1〜20) = 100マス。キー="1"〜"5"、値=配列[20]。

各マスの型:
- 文字列: 確定結果 — `"HR9"`, `"H7a"`, `"G5f"`, `"G4D"`, `"IH5"`, `"K"`, `"PO"`, `"BB"`, `"DB"`, `"F8"`, `"F9a"`, `"LD"`, `"UP"` 等
- `{"range": N}`: レンジチェック — Nは対象守備位置番号
- `{"split": "lr", "left": "結果", "right": "結果"}`: 対左右打者スプリット
- `{"split": "runner", "none": "結果", "on": "結果"}`: 走者有無スプリット

```json
// 例（架空の選手）
{
  "1": [
    "HR9", "2H8", {"range": 5}, {"range": 3},
    "H7", "H9a", "G5f", "G4D", "G6a",
    "F8", "PO", "K", "K", "K",
    "K", "K", "K", "K", "K", "UP"
  ],
  "2": [
    "HR8", "H7a", {"range": 4}, {"range": 6}, {"range": 3},
    "G4f", "G5D", "G3a", "F9", "PO",
    "K", "K", "K", "K", "K",
    "K", "K", "K", "K", "UP"
  ],
  "3": [
    {"range": 5}, {"range": 4}, {"range": 6},
    "G3D", "G5f", "G6a", "F7", "PO",
    "K", "K", "K", "K", "K",
    "K", "K", "K", "K", "K", "K", "UP"
  ],
  "4": [
    "G3f", "G4D", "F8", "BB", "BB",
    "BB", "DB", "K", "K", "K",
    "K", "K", "K", "K", "K",
    "K", "K", "K", "K", "UP"
  ],
  "5": [
    "K", "K", "K", "K", "K",
    "K", "K", "K", "K", "K",
    "K", "K", "K", "K", "K",
    "K", "K", "K", "K", "UP"
  ]
}
```

ルックアップ: `batting_table[投球番号][die - 1]` → 結果。文字列なら確定結果、オブジェクトならrange/splitを処理。

##### batting_table / pitching_table 共通の設計方針

| 判断 | 結論 | 理由 |
|------|------|------|
| キー名 | フルネーム（pitch, fatigue, range, split等） | 可読性重視 |
| 全20マス明示格納 | する（投球5が全Kでも20個書く） | ルックアップが一発で済む、暗黙ルールに依存しない |
| 出目20=UP | 明示的に `"UP"` を格納 | 同上 |
| スプリットの表現 | オブジェクト内に `split` キー | 通常結果（文字列）とスプリット（オブジェクト）をtypeofで判別可能 |
| レンジの表現 | `{"range": 守備位置}` | 守備位置がカード固有情報のためデータに含める |
| 例外選手 | データ自体はカード記載通りに格納 | サグメ（逆順投球）・正邪（逆順打撃）の特殊性はカード上で反映済み |

**関連する年次版管理の中間テーブル**（player_cardsに紐づけ）:
- player_card_batting_skills（打撃特殊能力）
- player_card_pitching_skills（投球特殊能力）
- player_card_biorhythms（バイオリズム）
- player_card_catchers（専属捕手関係）
- player_card_player_types（ルール系タイプ: 二刀流, リリーフ契約可）

**出自系のplayer_types（東方, ハチナイ, 球詠, PM, AP, オリジナル, 横綱）**は不変のため、
従来通り players に紐づく player_player_types で管理する。

## 既存テーブルとの関係

| 既存テーブル | 方針 | 備考 |
|-------------|------|------|
| players | 不変の基本情報のみ残す | 年次変動属性はplayer_cardsへ移行 |
| teams | そのまま活用 | games, competition_entriesからFK参照 |
| team_memberships | そのまま活用 | 1軍/2軍管理 |
| season_schedules | 残す | 日程管理用。gamesとは別の役割（日程 vs 試合記録） |
| season_rosters | そのまま活用 | 最新ロースター状態 |
| cost_assignments / cost_players | そのまま活用 | コスト管理（card_setsと改定タイミングは同じだが別管理）。cost_playersに `cost_exempt: boolean` を追加（借金特例等の各種特例でコスト上限から除外する選手にフラグ） |
| player_absences | そのまま活用 | ポストゲームサマリーで負傷登録時に使用 |
| player_player_types | 出自系のみ残す | ルール系(二刀流等)はplayer_card_player_typesへ |
| player_batting_skills 等 | 年次版へ移行 | player_card_*_skills に移行 |

## seq（通し番号）の運用

at_bats と game_events は同一試合内で **seq を共有**する。
画面のイニング表示で時系列に並べるときは:

```sql
SELECT seq, 'at_bat' as type, inning, half, ... FROM at_bats WHERE game_id = ?
UNION ALL
SELECT seq, event_type as type, inning, half, ... FROM game_events WHERE game_id = ?
ORDER BY seq
```

## 成績集計クエリの例

### 基本: at_batsのみからの集計

```sql
-- 打率（特定選手・特定大会、導入後データのみ）
SELECT
  COUNT(*) as plate_appearances,
  COUNT(*) FILTER (WHERE result_code NOT IN ('BB','DB')
    AND NOT (play_type IN ('bunt','squeeze') AND result_code LIKE 'G%')
    AND NOT (result_code LIKE 'F%' AND rbi > 0)
  ) as at_bats_count,
  COUNT(*) FILTER (WHERE result_code LIKE 'H%' OR result_code LIKE '2H%'
    OR result_code LIKE '3H%' OR result_code LIKE 'HR%' OR result_code LIKE 'IH%') as hits
FROM at_bats ab
JOIN games g ON ab.game_id = g.id
WHERE ab.batter_id = ? AND g.competition_id = ? AND g.status = 'confirmed';
```

### シーズン通算: imported_stats との合算

```sql
-- シーズン通算打撃成績（imported_stats + at_bats の合算）
WITH live_stats AS (
  SELECT
    ab.batter_id as player_id,
    COUNT(*) as pa,
    COUNT(*) FILTER (WHERE result_code NOT IN ('BB','DB')
      AND NOT (play_type IN ('bunt','squeeze') AND result_code LIKE 'G%')
      AND NOT (result_code LIKE 'F%' AND rbi > 0)
    ) as ab_count,
    COUNT(*) FILTER (WHERE result_code LIKE 'H%' OR result_code LIKE '2H%'
      OR result_code LIKE '3H%' OR result_code LIKE 'HR%' OR result_code LIKE 'IH%') as hits,
    COUNT(*) FILTER (WHERE result_code LIKE 'HR%') as hr,
    SUM(rbi) as rbi
  FROM at_bats ab
  JOIN games g ON ab.game_id = g.id
  WHERE g.competition_id = ? AND g.status = 'confirmed'
  GROUP BY ab.batter_id
)
SELECT
  COALESCE(l.player_id, i.player_id) as player_id,
  COALESCE((i.stats->>'plate_appearances')::int, 0) + COALESCE(l.pa, 0) as plate_appearances,
  COALESCE((i.stats->>'at_bats')::int, 0) + COALESCE(l.ab_count, 0) as at_bats,
  COALESCE((i.stats->>'hits')::int, 0) + COALESCE(l.hits, 0) as hits,
  COALESCE((i.stats->>'home_runs')::int, 0) + COALESCE(l.hr, 0) as home_runs,
  COALESCE((i.stats->>'rbi')::int, 0) + COALESCE(l.rbi, 0) as rbi
FROM live_stats l
FULL OUTER JOIN imported_stats i
  ON l.player_id = i.player_id AND i.competition_id = ? AND i.stat_type = 'batting';
```

### ゲーム固有指標（at_batsのみ、imported_statsには含まれない）

```sql
-- 投球番号別打撃成績
SELECT
  rolls->0->>'result' as pitch_number,
  COUNT(*) as count,
  COUNT(*) FILTER (WHERE result_code LIKE 'H%' OR result_code LIKE '2H%'
    OR result_code LIKE '3H%' OR result_code LIKE 'HR%' OR result_code LIKE 'IH%') as hits
FROM at_bats
WHERE batter_id = ?
GROUP BY pitch_number;

-- レンジチェック経由の安打率
SELECT
  COUNT(*) FILTER (WHERE result_code LIKE 'H%' OR result_code LIKE 'IH%') as range_hits,
  COUNT(*) as range_total
FROM at_bats
WHERE batter_id = ?
  AND rolls @> '[{"result": "range"}]';
```

※ 投球番号別成績・レンジ経由安打率等のゲーム固有指標は打席レベルのデータが必要なため、
imported_statsとの合算は不可。「導入後のデータのみ」と明示して表示する。

## 関連ドキュメント

- [画面設計 v1](screen-design-v1.md) — このスキーマが支える画面設計
- [投手休養ルール完全解析](pitcher-rest-rules-analysis.md) — 投手状態管理の参考
- [試合まとめODS構造解析](game-summary-analysis.md) — 現Excelとの対応
