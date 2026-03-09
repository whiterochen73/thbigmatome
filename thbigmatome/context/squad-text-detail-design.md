# スカッドテキスト作成補助機能 — 詳細設計書

**作成日**: 2026-03-06
**作成者**: 軍師マキノ (subtask_489a)
**前提資料**: context/squad-text-design.md (cmd_482 事前調査)
**ステータス**: P設計方針確定済み → 実装着手可能

---

## 1. DBスキーマ変更案

### 1.1 lineup_templates（オーダーテンプレート）

チーム×DH有無×対戦投手左右 = 4パターンを保存。

```ruby
create_table :lineup_templates do |t|
  t.references :team, null: false, foreign_key: true
  t.boolean    :dh_enabled, null: false          # DH有無
  t.string     :opponent_pitcher_hand, null: false # 'left' or 'right'
  t.timestamps
end

add_index :lineup_templates,
  [:team_id, :dh_enabled, :opponent_pitcher_hand],
  unique: true,
  name: 'index_lineup_templates_uniqueness'
```

**設計判断**:
- 4パターン固定（将来拡張考慮は不要 — P方針）
- name/label列は不要（4パターンはdh_enabled×opponent_pitcher_handで一意特定）
- チーム1つにつき最大4レコード。存在しないパターンは「未設定」扱い

### 1.2 lineup_template_entries（打順エントリ）

```ruby
create_table :lineup_template_entries do |t|
  t.references :lineup_template, null: false, foreign_key: true
  t.integer    :batting_order, null: false  # 1-9
  t.references :player, null: false, foreign_key: true
  t.string     :position, null: false       # 'RF', 'C', 'P', 'DH' etc.
  t.timestamps
end

add_index :lineup_template_entries,
  [:lineup_template_id, :batting_order],
  unique: true,
  name: 'index_lineup_template_entries_on_template_and_order'
```

**設計判断**:
- player_idはPlayersテーブル参照（team_membershipsではなく）。テンプレートは「この選手をこの打順で使う」という設定
- batting_order: 1-9。DHなし時は投手が9番固定ではなく、テンプレート上で自由配置
- position: ポジション略称（英語）。表示時にユーザー設定で漢字変換

### 1.3 squad_text_settings（書式カスタマイズ設定）

```ruby
create_table :squad_text_settings do |t|
  t.references :team, null: false, foreign_key: true
  t.string  :position_format,       default: 'english'  # 'english' or 'kanji'
  t.string  :handedness_format,     default: 'alphabet'  # 'alphabet' or 'kanji'
  t.string  :date_format,           default: 'absolute'  # 'absolute' or 'relative'
  t.string  :section_header_format, default: 'bracket'   # 'bracket' or 'plain'
  t.boolean :show_number_prefix,    default: true         # 背番号接頭辞表示
  t.jsonb   :batting_stats_config,  default: {}           # 打者成績ON/OFF
  t.jsonb   :pitching_stats_config, default: {}           # 投手成績ON/OFF
  t.timestamps
end

add_index :squad_text_settings, :team_id, unique: true
```

**batting_stats_config デフォルト値**:
```json
{
  "avg": true, "hr": true, "rbi": true,
  "sb": false, "obp": false, "ops": false,
  "ab_h": false
}
```

**pitching_stats_config デフォルト値**:
```json
{
  "w_l": true, "games": true, "era": true,
  "so": true, "ip": true,
  "hold": false, "save": false
}
```

**設計判断**:
- チーム単位で設定（ユーザー単位ではない）。1チーム=1オーナーの運用前提
- JSONB列で成績項目のON/OFFを管理。項目追加時にマイグレーション不要
- 将来ユーザー単位にする場合はuser_id列追加+unique制約変更で対応可能

### 1.4 game_lineups（前回生成データ保持）

テキスト生成後、実際に使ったオーダー全体を保存する。次の試合で「前回のオーダーから」微調整する用途。

```ruby
create_table :game_lineups do |t|
  t.references :team, null: false, foreign_key: true
  t.jsonb      :lineup_data, null: false, default: {}
  t.timestamps
end

add_index :game_lineups, :team_id, unique: true
```

**lineup_data JSOBBの構造**:
```json
{
  "dh_enabled": true,
  "opponent_pitcher_hand": "right",
  "starting_lineup": [
    { "batting_order": 1, "player_id": 42, "position": "RF" },
    ...
  ],
  "bench_players": [10, 25, 33],
  "off_players": [44, 55],
  "relief_pitcher_ids": [101, 102, 103],
  "starter_bench_pitcher_ids": [200]
}
```

**設計判断**:
- **1チーム1件（最新のみ）**: unique制約 on team_id。UPSERTで常に上書き
  - 理由: 用途が「前回をベースに微調整」のみ。N件前を参照するユースケースがない
  - 将来履歴が必要になった場合: unique制約を外し、`ORDER BY created_at DESC LIMIT N` で対応可能
- **JSONB 1列に全データ格納**: スタメン9人+ベンチ+オフ+投手区分を1レコードで保存
  - 正規化テーブル（game_lineup_entries）は不要。参照整合性よりシンプルさを優先
  - 前回データはあくまで「開始点」であり、読み込み時にバリデーション（1軍/離脱チェック）するため、player_idが古くても問題ない
- テンプレート（lineup_templates）とは役割が異なる:
  - テンプレート = 「理想の基本形」（4パターン、長期保持）
  - 前回データ = 「直近の実績」（1件、毎試合上書き）

### 1.5 永続化しないデータ（P方針確認済み）

以下は都度のUI操作で設定するが、テキスト生成確定時にgame_lineupsに保存される:
- ベンチ入り/オフの振り分け
- 先発ベンチ/中継ぎの振り分け
- 試合ごとの打順微調整（テンプレートからの変更分）

これらはFE側のステート（Pinia store等）で管理し、テキスト生成もFE側で完結する。
テキスト生成（コピー）確定時に、game_lineupsへPOSTして前回データとして保存する。

---

## 2. API設計

### 2.1 テンプレートCRUD

**Base path**: `/api/v1/teams/:team_id/lineup_templates`

| Method | Path | 説明 |
|--------|------|------|
| GET | `/lineup_templates` | 4パターン一覧取得 |
| GET | `/lineup_templates/:id` | 1パターン詳細（entries含む） |
| PUT | `/lineup_templates/:id` | テンプレート更新（entries含む nested attributes） |
| POST | `/lineup_templates` | テンプレート新規作成 |
| DELETE | `/lineup_templates/:id` | テンプレート削除 |

**GET /lineup_templates レスポンス例**:
```json
[
  {
    "id": 1,
    "dh_enabled": true,
    "opponent_pitcher_hand": "right",
    "entries": [
      { "batting_order": 1, "player_id": 42, "position": "RF",
        "player_name": "志摩　リン", "player_number": "F72" },
      ...
    ]
  },
  ...
]
```

**PUT /lineup_templates/:id リクエスト例**:
```json
{
  "lineup_template": {
    "entries_attributes": [
      { "batting_order": 1, "player_id": 42, "position": "RF" },
      { "batting_order": 2, "player_id": 15, "position": "3B" },
      ...
    ]
  }
}
```

**設計判断**:
- entries はテンプレート更新時に全件洗い替え（delete_all + insert）。差分更新は打順入替時に複雑になる
- player_nameやnumberはレスポンスに含めるが、DB上はplayer_id参照のみ

### 2.2 FEテキスト生成モジュール（BEエンドポイント不要）

テキスト生成はFE側で完結する。BEにPOSTエンドポイントは設けない。

**FEが取得するデータ（各GET APIから）**:
| データ | 取得元API | 用途 |
|--------|----------|------|
| テンプレート打順 | GET /lineup_templates/:id | ベース打順 |
| 前回生成データ | GET /game_lineup | 前回オーダー全体 |
| 書式設定 | GET /squad_text_settings | ポジション表記・成績項目ON/OFF等 |
| 選手成績 | GET /imported_stats (既存) | 打撃/投手成績 |
| 投手登板状態 | GET /pitcher_game_states (既存) | 累積・登板間隔・登板履歴 |
| 公示変更 | GET /roster_changes | 1⇔2軍入替 |

**FE側で管理するステート（Pinia store）**:
- `lineupOverrides`: 打順微調整（テンプレートからの変更分）
- `benchPlayers`: ベンチ入り野手のplayer_id配列
- `offPlayers`: オフ（ベンチ外）のplayer_id配列
- `reliefPitcherIds`: 中継ぎ投手のplayer_id配列
- `starterBenchPitcherIds`: 先発ベンチ投手のplayer_id配列

**テキスト生成composable**: `useSquadTextGenerator()`
- 上記のステート + 各APIから取得したデータを組み合わせてテキストを生成
- セクション別にcomputed propertyで生成し、プレビュー表示
- 全セクション結合のプレーンテキストをクリップボードコピー

**設計判断**:
- BEにテキスト生成ロジックを持たせない（P方針: FE完結）
- FEでテンプレート+成績データ+書式設定を各GET APIから取得し、FE側で組み立て
- SquadTextService（BE）は不要

### 2.3 前回生成データエンドポイント

**Singular resource**: `/api/v1/teams/:team_id/game_lineup`（1チーム1件のためsingular）

| Method | Path | 説明 |
|--------|------|------|
| GET | `/game_lineup` | 前回データ取得（なければ404） |
| PUT | `/game_lineup` | 前回データ保存（UPSERT: 新規作成/既存更新を自動判定） |

**PUT リクエスト例**:
```json
{
  "game_lineup": {
    "lineup_data": {
      "dh_enabled": true,
      "opponent_pitcher_hand": "right",
      "starting_lineup": [
        { "batting_order": 1, "player_id": 42, "position": "RF" },
        ...
      ],
      "bench_players": [10, 25, 33],
      "off_players": [44, 55],
      "relief_pitcher_ids": [101, 102, 103],
      "starter_bench_pitcher_ids": [200]
    }
  }
}
```

**GET /game_lineup レスポンス例**:
```json
{
  "id": 1,
  "lineup_data": { ... },
  "updated_at": "2026-03-06T23:00:00+09:00"
}
```

**設計判断**:
- Rails singular resource（`resource :game_lineup`）を使用。1チーム1件のhas_one関係に適合
- PUT時にfind_or_initialize_byで新規/更新を自動判定（FE側でPOST/PUTを区別する必要なし）
- FEでテキスト生成→コピー確定時にPUTする（自動保存）
- 前回データがない（初回利用時）は404を返し、FEはテンプレートモードのみ表示

### 2.4 書式設定エンドポイント

**GET/PUT `/api/v1/teams/:team_id/squad_text_settings`**

| Method | 説明 |
|--------|------|
| GET | 現在の書式設定取得（未作成時はデフォルト値） |
| PUT | 書式設定更新 |

### 2.5 公示生成エンドポイント

**GET `/api/v1/teams/:team_id/roster_changes`**

**パラメータ**:
| パラメータ | 必須 | 説明 |
|-----------|------|------|
| since | Yes | 前回試合日（この日以降の変更を検出） |
| season_id | Yes | 対象シーズン |

**レスポンス**:
```json
{
  "changes": [
    { "type": "promote", "player_id": 78, "player_name": "ユキ", "date": "2025-06-04" },
    { "type": "demote", "player_id": 107, "player_name": "エタニティラルバ", "date": "2025-06-04" }
  ],
  "text": "登録：78 ユキ\n抹消：107 エタニティラルバ"
}
```

**実装方式**:
- season_rostersテーブルのregistered_on + squad変更履歴から差分検出
- team_membershipsのsquad列変更をupdated_atで追跡（またはseason_rostersの新規レコード追加で追跡）

---

## 3. FE画面構成案

### 3.1 テンプレート編集画面

**配置**: SeasonPortal内の新規タブ「オーダー」

**画面要素**:
1. **パターン選択タブ**: 4つのタブ（DH有-対右, DH有-対左, DH無-対右, DH無-対左）
2. **打順リスト**: ドラッグ&ドロップで並べ替え可能な9行のリスト
   - 各行: 打順番号 | ポジション選択 | 選手選択（1軍メンバーから）
3. **選手プール**: 1軍メンバー一覧（未配置の選手をハイライト）
4. **保存ボタン**: テンプレートをDBに保存

**UX方針**:
- 選手選択はオートコンプリート（名前/背番号で検索）
- ポジション選択はドロップダウン（C, 1B, 2B, 3B, SS, LF, CF, RF, P, DH）
- 1軍メンバーのみ選択可能（squad='first'のteam_memberships）

### 3.2 テキスト生成画面

**配置**: SeasonPortalの「オーダー」タブ内、テンプレート編集の下部または別サブタブ

#### 運用フロー（全体像）

```
(A) チーム編成画面(TeamMembers)で公示（1⇔2軍入替）
     ↓
(B) オーダー画面で開始方法を選択:
     [テンプレートから始める] or [前回のオーダーから始める]
     → いずれも読み込み時にバリデーション（1軍/離脱チェック+警告）
     ↓
(C) 微調整 → テキスト生成 → コピー
     → コピー確定時に前回データとして自動保存
```

- (A)は試合前に1⇔2軍の入替を行う既存画面。公示テキストはこの画面の操作結果から自動生成
- (B)では2つの開始モードを提供:
  - **テンプレートから**: パターン選択（DH有無×左右）→ テンプレート読み込み → バリデーション
  - **前回のオーダーから**: 前回データ(game_lineups)読み込み → バリデーション → 微調整
  - 前回データがない（初回）場合はテンプレートモードのみ表示
  - いずれの場合もバリデーション（3.4）が適用される
- (C)がテキスト生成画面のメイン操作。コピー確定時にPOST /game_lineupsで保存

#### テキスト生成画面 操作フロー

```
0. 開始方法選択: [テンプレートから] or [前回のオーダーから]
     ↓
1. パターン選択（DH有無×左右 → テンプレート自動読み込み + バリデーション）
   ※前回オーダーの場合はこのステップをスキップし、前回データを直接読み込み
     ↓
2. 打順微調整（テンプレートから読み込んだ打順を必要に応じ変更）
     ↓
3. ベンチ振り分け
   - 1軍メンバーのうちスタメン以外を「ベンチ入り」「オフ」に分類
   - 投手を「中継ぎ」「先発ベンチ」「オフ」に分類
   - ドラッグ&ドロップまたはチェックボックスで振り分け
     ↓
4. プレビュー（リアルタイムでテキスト生成結果を表示）
     ↓
5. コピー（クリップボードにコピー → IRCに貼り付け）
     ↓
6. 自動保存（コピー確定時に前回データとしてgame_lineupsに保存）
```

**画面レイアウト**:
```
+----------------------------------+------------------+
| [パターン選択: DH有-対右 ▼]      |                  |
|                                  |                  |
| --- スターティングメンバー ---     |   プレビュー     |
| 1. RF  F72 志摩リン    [↑][↓]    |   (生成テキスト)  |
| 2. 3B  45  夢美        [↑][↓]    |                  |
| ...                              |                  |
|                                  |                  |
| --- ベンチ入り ---               |                  |
| [ドロップゾーン]                  |                  |
|                                  |                  |
| --- 中継ぎ ---                   |                  |
| [ドロップゾーン]                  |                  |
|                                  |                  |
| --- 先発ベンチ ---               |                  |
| [ドロップゾーン]                  |   [コピー]       |
|                                  |                  |
| --- オフ ---                     |                  |
| [ドロップゾーン]                  |                  |
+----------------------------------+------------------+
```

### 3.4 テンプレート読み込み時バリデーション

テンプレート読み込み時に各エントリをチェックし、使えない選手を検出する。

**チェック項目**:
| チェック | 条件 | 警告理由表示 |
|---------|------|------------|
| 1軍所属確認 | team_memberships.squad = 'first' | 「2軍」 |
| 離脱確認 | player_absencesに有効な離脱レコードなし | 「離脱中（理由: ○○）」 |

**検出時の挙動**:
1. 使えない選手の打順枠に**警告表示**（理由付き: 「2軍」「離脱中」等）
2. その枠を**空欄**にして差し替えを促す
3. 可能であれば**候補選手を提示**（同ポジション可能な1軍メンバー）
4. **テンプレート自体は書き換えない**（基本オーダーとして保持）

**実装方式**:
- FEのテンプレート読み込みロジック（composable `useLineupTemplate()`）に組み込み
- テンプレートGET → entries内の各player_idについて、team_memberships/player_absencesを照合
- **前回データ(game_lineups)読み込み時にも同じバリデーションを適用**
  - 前回データのstarting_lineup/bench_players等の全player_idをチェック
  - 使えなくなった選手は警告表示+枠空欄（テンプレート読み込みと同じ挙動）
- 照合に必要なデータ（1軍メンバー一覧、離脱者一覧）はSeasonPortal表示時に既に取得済み
- バリデーション結果はリアクティブにUI反映（v-alert / badge等）

```typescript
// composable: useLineupTemplate()
interface TemplateValidationResult {
  battingOrder: number
  playerId: number
  status: 'ok' | 'not_first_squad' | 'absent'
  reason?: string  // '2軍', '離脱中（○○）'
  candidates?: Player[]  // 同ポジション候補
}
```

---

### 3.3 書式設定画面

**配置**: SeasonPortalの「設定」タブ内、またはチーム設定画面

**設定項目**:

| 設定 | UI | 選択肢 |
|------|-----|--------|
| ポジション表記 | ラジオボタン | 英語略称(RF) / 漢字略称(右) |
| 投打表記 | ラジオボタン | アルファベット(RR) / 漢字(右右) |
| 登板履歴日付 | ラジオボタン | 絶対日付(MM/DD) / 相対日付(N日前) |
| セクションヘッダー | ラジオボタン | 括弧付き / 無印 |
| 背番号接頭辞 | トグル | 表示する / しない |
| 打者成績項目 | チェックボックス群 | 打率/HR/打点/盗塁/出塁率/OPS |
| 投手成績項目 | チェックボックス群 | 勝敗/登板数/防御率/奪三振/投球回/ホールド/セーブ |

---

## 4. テキスト生成ロジック（FE実装詳細）

### 4.1 データ取得・組み立てフロー

```
useSquadTextGenerator(team, season)  // Vue composable
  |
  |-- initFromSource(mode)  // 'template' or 'previous'
  |     |
  |     |-- [template] loadTemplate(templateId)
  |     |     -> lineup_template + entries（GET API）
  |     |     -> バリデーション実施（3.4参照）
  |     |
  |     +-- [previous] loadPreviousLineup()
  |           -> GET /game_lineup
  |           -> バリデーション実施（3.4参照、同一ロジック）
  |           -> Pinia storeにbench/off/relief等を復元
  |
  |-- applyOverrides(lineupOverrides)
  |     -> Pinia storeの打順微調整を適用
  |
  |-- fetchStats(playerIds)
  |     -> imported_stats（GET API / 既にSeasonPortalで取得済みならキャッシュ利用）
  |
  |-- fetchPitcherStates(pitcherIds)
  |     -> pitcher_game_states（GET API）
  |
  |-- fetchSettings()
  |     -> squad_text_settings（GET API）
  |
  |-- classifyPlayers()
  |     -> bench/relief/starterBench/off（Pinia storeから）
  |
  |-- generateText()  // computed
  |     -> セクション別テキスト + 全結合プレーンテキスト
  |
  +-- saveAsGameLineup()  // コピー確定時に呼出
        -> PUT /game_lineup（現在のステートをUPSERT保存）
```

### 4.2 セクション生成

| セクション | データソース | 主要処理 |
|-----------|------------|---------|
| ヘッダー | teams, seasons, game_records集計 | チーム名/日付/通算成績/コスト/人数/指定選手 |
| スタメン | lineup entries + imported_stats | 打順/ポジション/背番号/名前/投打/打撃成績 |
| 控え野手 | bench_players + imported_stats | 背番号/名前/投打/打撃成績 |
| 中継ぎ投手 | relief_pitcher_ids + pitcher_game_states | (中継)マーク/背番号/名前/投打/防御率/累積 |
| 先発ベンチ | starter_bench_pitcher_ids + pitcher_game_states | 背番号/名前/投打/防御率/登板間隔 |
| オフ | off_players + pitcher_game_states | 背番号/名前/投打/防御率/登板間隔 |
| 登板履歴 | pitcher_game_states (直近7日) + season_schedules | 日付/勝敗マーク/投手名/イニング |

### 4.3 ポジション表記変換テーブル

```typescript
// composable: useSquadTextGenerator() 内
const POSITION_MAP: Record<string, Record<string, string>> = {
  english: { C: 'C', '1B': '1B', '2B': '2B', '3B': '3B',
             SS: 'SS', LF: 'LF', CF: 'CF', RF: 'RF',
             P: 'P', DH: 'DH' },
  kanji:   { C: '捕', '1B': '一', '2B': '二', '3B': '三',
             SS: '遊', LF: '左', CF: '中', RF: '右',
             P: '投', DH: 'DH' }
}
```

### 4.4 投打表記変換

```typescript
// handedness: 'right_right', 'right_left', 'left_left', 'right_switch' etc.
const HANDEDNESS_MAP: Record<string, Record<string, string>> = {
  alphabet: { right: 'R', left: 'L', switch: 'S' },
  kanji:    { right: '右', left: '左', switch: '両' }
}
```

---

## 5. Phase分割実装計画

### Phase 1: DBスキーマ + テンプレートCRUD

**スコープ**:
- マイグレーション: lineup_templates, lineup_template_entries, squad_text_settings, game_lineups
- Model: LineupTemplate, LineupTemplateEntry, SquadTextSetting, GameLineup
- Controller: Api::V1::LineupTemplatesController (CRUD), Api::V1::GameLineupsController (GET/POST)
- FE: テンプレート編集タブ（4パターンの打順設定、選手並べ替え）

**前提条件**: なし（既存テーブルへの変更なし）

**工数感**: 足軽1名で2-3 cmd

**成果物**:
- BE: マイグレーション + モデル + コントローラー(テンプレートCRUD + 前回データGET/POST) + RSpec
- FE: SeasonPortal内「オーダー」タブ + テンプレートエディタ

### Phase 2: テキスト生成（打者/投手成績込み）

**スコープ**:
- FE composable: `useSquadTextGenerator()`（テキスト生成ロジック本体）
- FE composable: `useLineupTemplate()`（テンプレート/前回データ読み込み+バリデーション）
- FE: テキスト生成画面（開始方法選択→バリデーション→ベンチ振り分け→プレビュー→コピー→自動保存）
- FE: Pinia store（ベンチ/中継ぎ/先発ベンチ/オフの振り分けステート管理）
- FE: 開始方法選択UI（「テンプレートから」or「前回のオーダーから」）
- FE: コピー確定時の前回データ自動保存（POST /game_lineups）

**前提条件**: Phase 1完了

**工数感**: 足軽1-2名で3-4 cmd（テキスト生成ロジック+前回データ統合が主要部分）

**成果物**:
- FE: composable + Pinia store + テキスト生成UI + プレビュー + クリップボードコピー + 前回データ保存/読込
- BE追加なし（テキスト生成はFE完結。前回データAPIはPhase 1で作成済み）

**注意**: imported_statsに成績データがインポート済みの選手のみ成績表示可能。未インポート選手は成績欄を空欄または「-」表示。

### Phase 3: 書式カスタマイズ

**スコープ**:
- Controller: Api::V1::SquadTextSettingsController (GET/PUT)
- FE: 書式設定画面（ラジオボタン/チェックボックス群）
- `useSquadTextGenerator()` composableに設定反映ロジック追加

**前提条件**: Phase 2完了

**工数感**: 足軽1名で1-2 cmd

**成果物**:
- BE: 設定コントローラー（GET/PUT のみ）
- FE: 設定画面 + `useSquadTextGenerator()`への設定適用 + リアルタイムプレビュー反映

### Phase 4: 公示自動生成

**スコープ**:
- Service: RosterChangeService（差分検出ロジック）
- Controller: Api::V1::RosterChangesController (GET)
- FE: テキスト生成画面に公示セクション追加

**前提条件**: Phase 2完了（Phase 3と並行可）

**工数感**: 足軽1名で1-2 cmd

**成果物**:
- BE: RosterChangeService + コントローラー
- FE: 公示プレビュー（テキスト生成画面の先頭に表示）

**実装方式**: season_rostersのregistered_onを基準に、since日付以降のsquad変更を検出。promote（second→first）とdemote（first→second）を分類。

---

## 6. 既存スキーマとの整合性

### 影響なし（既存テーブル変更不要）

新規テーブル4つの追加のみ（lineup_templates, lineup_template_entries, squad_text_settings, game_lineups）。既存テーブルへの列追加やスキーマ変更は不要。

### 参照する既存テーブル

| テーブル | 用途 |
|---------|------|
| teams | チーム情報 |
| players | 選手基本情報（名前、背番号） |
| player_cards | 投打、ポジション、疲労P |
| team_memberships | 1軍/2軍区分、コスト種別 |
| cost_players | コスト値 |
| imported_stats | 打撃/投手成績 |
| pitcher_game_states | 累積、登板履歴、登板間隔 |
| seasons | シーズン情報、指定選手 |
| season_schedules | 日程、先発予告 |
| season_rosters | 公示用の登録日 |
| player_absences | 離脱情報 |

### cmd_482で指摘された不足データ(D1-D6)への対応

| ID | 不足項目 | 本設計での対応 |
|----|---------|-------------|
| D1 | 出撃時打順 | lineup_templatesで基本形を永続化。前回実績はgame_lineupsに保存。試合時の微調整はFEステートで管理 |
| D2 | ベンチ入り/オフ区分 | テンプレートには含めない。前回実績としてgame_lineupsに保存。FE側Pinia storeで都度管理 |
| D3 | 先発ベンチ/中継ぎ区分 | 同上。前回実績としてgame_lineupsに保存。FE側Pinia storeで都度管理 |
| D4 | ホールド数 | imported_stats.stats JSOBBに含まれていれば表示。なければ非表示 |
| D5 | 登板履歴日別詳細 | pitcher_game_statesから取得。データ既存 |
| D6 | 公示履歴 | season_rostersのregistered_onから差分検出 |
