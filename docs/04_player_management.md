# 04. 選手管理システム (Player Management)

最終更新: 2026-02-21
対応バージョン: Rails 8.0.2, Vue 3 + TypeScript

---

## 1. 概要

選手管理システムは、野球ボードゲーム「東方BIG野球」における選手マスターデータの作成・更新・削除・参照を担う中核機能である。バックエンドはRails 8 APIモード、フロントエンドはVue 3 Composition API + TypeScript + Vuetify 3で構成される。

### 1.1 システム構成

```
┌─────────────────┐      ┌──────────────────┐
│  Players.vue    │─────▶│ PlayersController│
│  (選手一覧画面) │      │  (CRUD API)      │
│  + 検索/フィルター│     └──────────────────┘
└─────────────────┘               │
         │                        ▼
         ▼               ┌─────────────────┐
┌─────────────────┐     │  Player Model   │
│ PlayerDialog    │     │  (46 columns)   │
│  (編集Dialog)   │     │  19 relations   │
└─────────────────┘     └─────────────────┘
         │                        │
    ┌────┴────┬─────────┬─────────┼────────┐
    ▼         ▼         ▼         ▼        ▼
┌────────┐┌─────────┐┌────────┐┌────────┐┌────────┐
│Identity││ Fielder ││Defense ││Pitching││中間    │
│  Form  ││  Form   ││  Form  ││  Form  ││テーブル│
└────────┘└─────────┘└────────┘└────────┘└────────┘
                                           (×5)
```

### 1.2 管理対象データ

選手データは以下の5カテゴリー、**46カラム**で構成される:

| カテゴリ | カラム数 | 主要項目 |
|---------|---------|---------|
| **基本情報** | 11 | name, number, position, throwing_hand, batting_hand, 投打スタイルID×4 |
| **野手能力** | 5 | speed, bunt, steal_start/end, injury_rate |
| **守備能力** | 21 | defense_p/c/1b/2b/3b/ss/of/lf/cf/rf (各2カラム: 守備力+送球) + special_defense_c/throwing_c |
| **投手能力** | 3 | starter_stamina, relief_stamina, is_relief_only |
| **メタ情報** | 6 | id, created_at, updated_at, batting/pitching_style_description×2, is_pitcher |

### 1.3 多対多リレーション (5テーブル)

> **注**: 旧バージョンにあった `has_one :player_pitching` リレーションは削除済み。投手能力は `players` テーブルの直接カラム（`is_pitcher`, `starter_stamina`, `relief_stamina`, `is_relief_only`）で管理される。

| 中間テーブル | 関連マスター | カーディナリティ |
|------------|------------|----------------|
| `player_batting_skills` | `batting_skills` | N:M |
| `player_pitching_skills` | `pitching_skills` | N:M |
| `player_player_types` | `player_types` | N:M |
| `player_biorhythms` | `biorhythms` | N:M |
| `catchers_players` | `players` (自己参照) | N:M (投手-捕手相性) |

### 1.4 エンドポイント

| Method | Path | 用途 | シリアライザー |
|--------|------|------|--------------|
| GET | `/api/v1/players` | 全選手取得 | PlayerDetailSerializer |
| GET | `/api/v1/players/:id` | 選手詳細取得 | PlayerDetailSerializer |
| POST | `/api/v1/players` | 選手作成 | (default) |
| PATCH | `/api/v1/players/:id` | 選手更新 | (default) |
| DELETE | `/api/v1/players/:id` | 選手削除 | (none) |
| GET | `/api/v1/team_registration_players` | チーム登録用一覧 | PlayerSerializer |

---

## 2. データモデル詳細

### 2.1 players テーブル (主テーブル)

#### 2.1.1 スキーマ定義 (db/schema.rb L213-258)

```ruby
create_table "players", force: :cascade do |t|
  # 基本情報
  t.string "name", null: false
  t.string "short_name"
  t.string "number", null: false
  t.string "position"              # enum: pitcher/catcher/infielder/outfielder
  t.string "throwing_hand"         # enum: right_throw/left_throw
  t.string "batting_hand"          # enum: right_bat/left_bat/switch_hitter

  # 野手能力
  t.integer "speed"
  t.integer "bunt"
  t.integer "steal_start"
  t.integer "steal_end"
  t.integer "injury_rate"

  # 守備能力 (10ポジション)
  t.string "defense_p"
  t.string "defense_c"
  t.integer "throwing_c"
  t.string "defense_1b"
  t.string "defense_2b"
  t.string "defense_3b"
  t.string "defense_ss"
  t.string "defense_of"
  t.string "throwing_of"
  t.string "defense_lf"
  t.string "throwing_lf"
  t.string "defense_cf"
  t.string "throwing_cf"
  t.string "defense_rf"
  t.string "throwing_rf"

  # 特殊守備 (相性投手と組んだ時)
  t.string "special_defense_c"
  t.integer "special_throwing_c"

  # 投手能力
  t.boolean "is_pitcher", default: false
  t.boolean "is_relief_only", default: false
  t.integer "starter_stamina"
  t.integer "relief_stamina"

  # スタイルID (外部キー)
  t.bigint "batting_style_id"
  t.bigint "pitching_style_id"
  t.bigint "pinch_pitching_style_id"
  t.bigint "catcher_pitching_style_id"

  # 自由記述フィールド
  t.string "pitching_style_description"
  t.string "batting_style_description"

  # メタ情報
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false

  # インデックス
  t.index ["batting_style_id"], name: "index_players_on_batting_style_id"
  t.index ["catcher_pitching_style_id"], name: "index_players_on_catcher_pitching_style_id"
  t.index ["pinch_pitching_style_id"], name: "index_players_on_pinch_pitching_style_id"
  t.index ["pitching_style_id"], name: "index_players_on_pitching_style_id"
end
```

**合計**: 46カラム (id含む)

#### 2.1.2 外部キー制約 (db/schema.rb L394-397)

```ruby
add_foreign_key "players", "batting_styles"
add_foreign_key "players", "pitching_styles"
add_foreign_key "players", "pitching_styles", column: "catcher_pitching_style_id"
add_foreign_key "players", "pitching_styles", column: "pinch_pitching_style_id"
```

---

### 2.2 中間テーブル (5テーブル)

#### 2.2.1 player_batting_skills (schema.rb L165-173)

```ruby
create_table "player_batting_skills", force: :cascade do |t|
  t.bigint "player_id", null: false
  t.bigint "batting_skill_id", null: false
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false

  t.index ["batting_skill_id"], name: "index_player_batting_skills_on_batting_skill_id"
  t.index ["player_id"], name: "index_player_batting_skills_on_player_id"
  t.index ["player_id", "batting_skill_id"],
          name: "index_player_batting_skills_on_player_id_and_batting_skill_id", unique: true
end
```

**モデルバリデーション** (player_batting_skill.rb L1-6):

```ruby
class PlayerBattingSkill < ApplicationRecord
  belongs_to :player
  belongs_to :batting_skill

  validates :batting_skill_id, uniqueness: { scope: :player_id, message: 'は既に登録されています' }
end
```

#### 2.2.2 player_pitching_skills (schema.rb L185-193)

同様の構造。unique index: `idx_on_player_id_pitching_skill_id_bd496ce465`

#### 2.2.3 player_player_types (schema.rb L195-203)

同様の構造。

#### 2.2.4 player_biorhythms (schema.rb L175-183)

同様の構造。

#### 2.2.5 catchers_players (投手-捕手相性, schema.rb L42-48)

```ruby
create_table "catchers_players", id: false, force: :cascade do |t|
  t.bigint "player_id"     # 投手のID
  t.bigint "catcher_id"    # 捕手のID

  t.index ["catcher_id"], name: "index_catchers_players_on_catcher_id"
  t.index ["player_id"], name: "index_catchers_players_on_player_id"
  t.index ["player_id", "catcher_id"],
          name: "index_catchers_players_on_player_id_and_catcher_id", unique: true
end
```

**特徴**:
- `id: false` でPRIMARY KEYなし
- **自己参照多対多**: player_id も catcher_id も players.id を参照

**モデル定義** (catchers_player.rb):

```ruby
class CatchersPlayer < ApplicationRecord
  belongs_to :player
  belongs_to :catcher, class_name: 'Player'
end
```

---

### 2.3 Player モデルのリレーション定義 (player.rb)

```ruby
class Player < ApplicationRecord
  # チーム所属 (多対多)
  has_many :team_memberships, dependent: :destroy
  has_many :teams, through: :team_memberships

  # 打撃スタイル
  belongs_to :batting_style, optional: true
  has_many :player_batting_skills, dependent: :destroy
  has_many :batting_skills, through: :player_batting_skills

  # 投球スタイル (3種類)
  belongs_to :pitching_style, optional: true
  belongs_to :pinch_pitching_style, class_name: "PitchingStyle",
             foreign_key: :pinch_pitching_style_id, optional: true
  belongs_to :catcher_pitching_style, class_name: "PitchingStyle",
             foreign_key: :catcher_pitching_style_id, optional: true

  # 投球スキル
  has_many :player_pitching_skills, dependent: :destroy
  has_many :pitching_skills, through: :player_pitching_skills

  # 選手タイプ
  has_many :player_player_types, dependent: :destroy
  has_many :player_types, through: :player_player_types

  # バイオリズム
  has_many :player_biorhythms, dependent: :destroy
  has_many :biorhythms, through: :player_biorhythms

  # コスト
  has_many :cost_players, dependent: :destroy

  # 投手-捕手相性 (自己参照多対多)
  has_many :catchers_players, dependent: :destroy
  has_many :catchers, through: :catchers_players, source: :catcher

  # 捕手-投手相性 (逆方向)
  has_many :partner_pitchers_players, class_name: "CatchersPlayer", foreign_key: "catcher_id"
  has_many :partner_pitchers, through: :partner_pitchers_players, source: :player, dependent: :destroy
end
```

**リレーション総数**: 19個

> **変更履歴**: `has_one :player_pitching, dependent: :destroy` は削除された。このリレーションは使われていない死んだ関連で、`Player#destroy` 時に `NameError` を引き起こしていたため除去された。投手能力は `players` テーブルの直接カラムで管理されている。

---

### 2.4 バリデーション詳細

#### 2.4.1 Enum定義 (player.rb L30-35)

```ruby
enum :position, { pitcher: 'pitcher', catcher: 'catcher',
                  infielder: 'infielder', outfielder: 'outfielder' }
enum :throwing_hand, { right_throw: 'right_throw', left_throw: 'left_throw' }
enum :batting_hand, { right_bat: 'right_bat', left_bat: 'left_bat', switch_hitter: 'switch_hitter' }
```

#### 2.4.2 守備力フォーマット (player.rb)

```ruby
DEFENSE_RATING_FORMAT = /\A[0-5][A-E|S]\z/.freeze
DEFENSE_ATTRIBUTES = %i[
  defense_p defense_c defense_1b defense_2b defense_3b defense_ss
  defense_of defense_lf defense_cf defense_rf special_defense_c
].freeze

validates(*DEFENSE_ATTRIBUTES,
          format: { with: DEFENSE_RATING_FORMAT, message: :invalid_format },
          allow_blank: true)
```

> **注**: バリデーションメッセージは i18n キー（`:invalid_format`）を使用。実際のメッセージは `config/locales` で定義される。

**許可パターン**: `0A`, `1B`, `2C`, `3D`, `4E`, `5S` 等
**空値**: 許可

#### 2.4.3 捕手送球バリデーション (player.rb)

```ruby
# 通常捕手
validates :throwing_c,
          presence: { message: :required_when_defense_c_present },
          if: -> { defense_c.present? }
validates :throwing_c,
          numericality: { only_integer: true, message: :not_an_integer },
          inclusion: { in: -5..5, message: :out_of_range },
          allow_blank: true

# 特殊捕手 (相性投手用)
validates :special_throwing_c,
          presence: { message: :required_when_special_defense_c_present },
          if: -> { special_defense_c.present? }
validates :special_throwing_c,
          numericality: { only_integer: true, message: :not_an_integer },
          inclusion: { in: -5..5, message: :out_of_range },
          allow_blank: true
```

> **注**: バリデーションメッセージはすべて i18n キーを使用。

**範囲**: -5〜5 (整数)
**必須条件**: 対応する defense_c / special_defense_c が設定されている場合

#### 2.4.4 外野手送球バリデーション (player.rb)

```ruby
OUTFIELDER_THROWING_ATTRIBUTES = %i[throwing_of throwing_lf throwing_cf throwing_rf].freeze
OUTFIELDER_THROWING_VALUES = %w[S A B C].freeze

validates(*OUTFIELDER_THROWING_ATTRIBUTES,
          inclusion: { in: OUTFIELDER_THROWING_VALUES, message: :must_be_s_a_b_or_c },
          allow_blank: true)

# 守備力との連動チェック
{ defense_of: :throwing_of, defense_lf: :throwing_lf,
  defense_cf: :throwing_cf, defense_rf: :throwing_rf }
  .each do |defense_attr, throwing_attr|
    validates throwing_attr,
              presence: { message: :required_when_defense_present },
              if: -> { send(defense_attr).present? }
  end
```

**許可値**: S, A, B, C
**必須条件**: 対応する defense_of/lf/cf/rf が設定されている場合

#### 2.4.5 スタミナバリデーション (player.rb)

```ruby
# 先発スタミナ (リリーフ専門時は無効)
validates :starter_stamina,
          numericality: { only_integer: true, message: :not_an_integer },
          inclusion: { in: 4..9, message: :out_of_range },
          allow_blank: true,
          unless: :is_relief_only

# リリーフスタミナ
validates :relief_stamina,
          numericality: { only_integer: true, message: :not_an_integer },
          inclusion: { in: 0..3, message: :out_of_range },
          allow_blank: true
```

**先発**: 4〜9 (`is_relief_only == true` の場合はバリデーション対象外)
**リリーフ**: 0〜3

#### 2.4.6 野手能力バリデーション (player.rb)

```ruby
validates :speed, presence: true, numericality: { only_integer: true, message: :not_an_integer },
          inclusion: { in: 1..5, message: :out_of_range }
validates :bunt, presence: true, numericality: { only_integer: true, message: :not_an_integer },
          inclusion: { in: 1..10, message: :out_of_range }
validates :steal_start, presence: true, numericality: { only_integer: true, message: :not_an_integer },
          inclusion: { in: 1..22, message: :out_of_range }
validates :steal_end, presence: true, numericality: { only_integer: true, message: :not_an_integer },
          inclusion: { in: 1..22, message: :out_of_range }
```

| フィールド | 範囲 | 必須 |
|----------|------|------|
| speed | 1〜5 | ✓ |
| bunt | 1〜10 | ✓ |
| steal_start | 1〜22 | ✓ |
| steal_end | 1〜22 | ✓ |

#### 2.4.7 怪我率バリデーション (player.rb)

```ruby
validates :injury_rate, presence: true, numericality: { only_integer: true, message: :not_an_integer },
          inclusion: { in: 1..7, message: :out_of_range }
```

**備考**: 範囲は `1..7`（1以上7以下）。バリデーションメッセージは i18n キーで管理。

#### 2.4.8 外野守備の排他性バリデーション (player.rb)

```ruby
validate :defense_of_exclusivity

private

def defense_of_exclusivity
  has_of = defense_of.present?
  has_individual = [ defense_lf, defense_cf, defense_rf ].any?(&:present?)
  if has_of && has_individual
    errors.add(:base, :of_and_individual_exclusive)
  end
end
```

**ルール**: 外野守備力の統合値（`defense_of`）と個別値（`defense_lf`, `defense_cf`, `defense_rf`）を同時に設定することは禁止。どちらか一方のみ設定可能。

---

### 2.5 ID配列を返すヘルパーメソッド (player.rb L97-119)

```ruby
def batting_skill_ids
  player_batting_skills.map(&:batting_skill_id)
end

def player_type_ids
  player_player_types.map(&:player_type_id)
end

def biorhythm_ids
  player_biorhythms.map(&:biorhythm_id)
end

def pitching_skill_ids
  player_pitching_skills.map(&:pitching_skill_id)
end

def catcher_ids
  catchers_players.map(&:catcher_id)
end

def partner_pitcher_ids
  partner_pitchers_players.map(&:player_id)
end
```

**用途**: シリアライザーで `attributes :batting_skill_ids` と記述すると、これらのメソッドが呼ばれ、ID配列がJSON出力される。

---

## 3. APIエンドポイント仕様

### 3.1 GET /api/v1/players

全選手の詳細情報を取得する。

#### リクエスト

```http
GET /api/v1/players HTTP/1.1
Authorization: Bearer <token>
```

#### 処理フロー (players_controller.rb L2-5)

```ruby
def index
  players = Player.eager_load(
    :player_batting_skills, :player_player_types, :player_biorhythms,
    :player_pitching_skills, :catchers_players, :partner_pitchers_players
  ).all.order(:id)
  render json: players, each_serializer: PlayerDetailSerializer
end
```

**N+1対策**: `eager_load` により中間テーブルを一括ロード
**並び順**: ID昇順

#### 成功レスポンス (200 OK)

```json
[
  {
    "id": 1,
    "name": "博麗 霊夢",
    "short_name": "霊夢",
    "number": "1",
    "position": "pitcher",
    "throwing_hand": "right_throw",
    "batting_hand": "right_bat",
    "speed": 3,
    "bunt": 5,
    "steal_start": 15,
    "steal_end": 20,
    "injury_rate": 3,
    "defense_p": "5A",
    "defense_c": null,
    "throwing_c": null,
    "defense_1b": "2C",
    "defense_2b": null,
    "defense_3b": null,
    "defense_ss": null,
    "defense_of": null,
    "throwing_of": null,
    "defense_lf": null,
    "throwing_lf": null,
    "defense_cf": null,
    "throwing_cf": null,
    "defense_rf": null,
    "throwing_rf": null,
    "special_defense_c": null,
    "special_throwing_c": null,
    "is_pitcher": true,
    "starter_stamina": 7,
    "relief_stamina": 2,
    "is_relief_only": false,
    "pitching_style_id": 1,
    "pitching_style_description": "本格派",
    "pinch_pitching_style_id": null,
    "catcher_pitching_style_id": null,
    "batting_style_id": 2,
    "batting_style_description": "アベレージヒッター",
    "biorhythm_ids": [1, 2],
    "batting_skill_ids": [3, 5],
    "pitching_skill_ids": [1, 4, 7],
    "player_type_ids": [1, 3],
    "catcher_ids": [5],
    "partner_pitcher_ids": []
  }
]
```

---

### 3.2 GET /api/v1/players/:id

指定IDの選手詳細を取得する。

#### リクエスト

```http
GET /api/v1/players/1 HTTP/1.1
Authorization: Bearer <token>
```

#### 処理フロー (players_controller.rb L7-10)

```ruby
def show
  player = Player.find(params[:id])
  render json: player, serializer: PlayerDetailSerializer
end
```

#### 成功レスポンス (200 OK)

GET /players のレスポンス配列の1要素と同じ構造。

#### 失敗レスポンス (404 Not Found)

```json
{
  "error": "Record not found"
}
```

Railsの `ActiveRecord::RecordNotFound` 例外が404を返す。

---

### 3.3 POST /api/v1/players

新規選手を作成する。

#### リクエスト

```http
POST /api/v1/players HTTP/1.1
Content-Type: application/json
Authorization: Bearer <token>

{
  "player": {
    "name": "霧雨 魔理沙",
    "short_name": "魔理沙",
    "number": "2",
    "position": "outfielder",
    "throwing_hand": "left_throw",
    "batting_hand": "left_bat",
    "speed": 4,
    "bunt": 3,
    "steal_start": 18,
    "steal_end": 22,
    "injury_rate": 2,
    "defense_of": "4B",
    "throwing_of": "A",
    "batting_style_id": 1,
    "batting_skill_ids": [1, 2],
    "player_type_ids": [2],
    "biorhythm_ids": [],
    "pitching_skill_ids": [],
    "catcher_ids": [],
    "partner_pitcher_ids": []
  }
}
```

#### Strong Parameters (players_controller.rb L38-48)

```ruby
def player_params
  params.require(:player).permit(
    :name, :number, :short_name, :position, :throwing_hand, :batting_hand,
    :bunt, :steal_start, :steal_end, :speed,
    :defense_p, :defense_c, :defense_1b, :defense_2b, :defense_3b, :defense_ss,
    :defense_of, :defense_lf, :defense_cf, :defense_rf,
    :special_defense_c,
    :throwing_c, :special_throwing_c,
    :throwing_of, :throwing_lf, :throwing_cf, :throwing_rf,
    :starter_stamina, :relief_stamina, :is_relief_only,
    :injury_rate, :batting_style_id, :pitching_style_id,
    :pinch_pitching_style_id, :catcher_pitching_style_id,
    batting_skill_ids: [], pitching_skill_ids: [], player_type_ids: [],
    biorhythm_ids: [], catcher_ids: [], partner_pitcher_ids: []
  )
end
```

**配列パラメータ**の処理: Rails の `has_many` accepts_nested_attributes により、`batting_skill_ids: [1,2,3]` が自動的に中間テーブルレコードに変換される。

#### 成功レスポンス (201 Created)

```json
{
  "id": 2,
  "name": "霧雨 魔理沙",
  ...
}
```

#### 失敗レスポンス (422 Unprocessable Entity)

```json
{
  "errors": [
    "Name can't be blank",
    "Defense of は0～5の数字とA～Eのアルファベットの組み合わせ2文字で入力してください"
  ]
}
```

`player.errors.full_messages` により、全バリデーションエラーが配列で返される。

---

### 3.4 PATCH /api/v1/players/:id

選手情報を更新する。

#### リクエスト

```http
PATCH /api/v1/players/1 HTTP/1.1
Content-Type: application/json
Authorization: Bearer <token>

{
  "player": {
    "number": "99",
    "batting_style_id": 3
  }
}
```

**部分更新対応**: 送信したフィールドのみ更新される。

#### 成功レスポンス (200 OK)

```json
{
  "id": 1,
  "name": "博麗 霊夢",
  "number": "99",
  "batting_style_id": 3,
  ...
}
```

#### 失敗レスポンス

- **404 Not Found**: 指定IDが存在しない
- **422 Unprocessable Entity**: バリデーションエラー (POST と同じ形式)

---

### 3.5 DELETE /api/v1/players/:id

選手を削除する。

#### リクエスト

```http
DELETE /api/v1/players/1 HTTP/1.1
Authorization: Bearer <token>
```

#### 処理フロー (players_controller.rb L30-34)

```ruby
def destroy
  player = Player.find(params[:id])
  player.destroy
  head :no_content
end
```

#### 成功レスポンス (204 No Content)

ボディなし。

#### カスケード削除

`dependent: :destroy` により以下が連鎖削除される:

- player_batting_skills
- player_pitching_skills
- player_player_types
- player_biorhythms
- catchers_players
- cost_players
- team_memberships
- partner_pitchers_players

> **注**: 旧バージョンにあった `player_pitching` は削除済みのため、カスケード削除の対象ではなくなった。

---

### 3.6 GET /api/v1/team_registration_players

チーム登録画面用の選手一覧を取得する。

#### リクエスト

```http
GET /api/v1/team_registration_players HTTP/1.1
Authorization: Bearer <token>
```

#### 処理フロー (team_registration_players_controller.rb L2-6)

```ruby
def index
  # cost_list_idによるフィルタリングはフロントエンドで行うため、ここではすべての選手を返す
  players = Player.eager_load(:cost_players, :player_player_types).all
  render json: players, each_serializer: PlayerSerializer
end
```

**シリアライザー**: `PlayerSerializer` (詳細版ではなく簡易版)
**N+1対策**: `cost_players` と `player_player_types` を eager_load

#### 成功レスポンス (200 OK)

```json
[
  {
    "id": 1,
    "name": "博麗 霊夢",
    "number": "1",
    "short_name": "霊夢",
    "position": "pitcher",
    "player_type_ids": [1, 3],
    "throwing_hand": "right_throw",
    "batting_hand": "right_bat",
    "defense_p": "5A",
    "defense_c": null,
    "defense_1b": "2C",
    "defense_2b": null,
    "defense_3b": null,
    "defense_ss": null,
    "defense_of": null,
    "defense_lf": null,
    "defense_cf": null,
    "defense_rf": null,
    "throwing_c": null,
    "throwing_of": null,
    "throwing_lf": null,
    "throwing_cf": null,
    "throwing_rf": null,
    "cost_players": [
      {
        "id": 10,
        "cost_id": 1,
        "player_id": 1,
        "normal_cost": 500,
        "relief_only_cost": 300,
        "pitcher_only_cost": 450,
        "fielder_only_cost": 200,
        "two_way_cost": 550
      }
    ]
  }
]
```

**備考**: フロントエンドが `cost_players` 配列を受け取り、選択したコストリストIDでフィルタリングする設計。

---

### 3.7 シリアライザー仕様

#### 3.7.1 PlayerSerializer (player_serializer.rb)

```ruby
class PlayerSerializer < ActiveModel::Serializer
  attributes :id, :name, :number, :short_name, :position, :player_type_ids,
             :throwing_hand, :batting_hand,
             :defense_p, :defense_c, :defense_1b, :defense_2b, :defense_3b, :defense_ss,
             :defense_of, :defense_lf, :defense_cf, :defense_rf,
             :throwing_c, :throwing_of, :throwing_lf, :throwing_cf, :throwing_rf

  has_many :cost_players, serializer: CostPlayerSerializer

  def player_type_ids
    object.player_player_types.pluck(:player_type_id)
  end
end
```

**用途**: チーム登録画面 (コスト情報を含む簡易版)

#### 3.7.2 PlayerDetailSerializer (player_detail_serializer.rb)

```ruby
class PlayerDetailSerializer < ActiveModel::Serializer
  attributes :id, :name, :short_name, :number, :position, :throwing_hand, :batting_hand,
             :speed, :bunt, :steal_start, :steal_end, :injury_rate,
             :defense_p, :defense_c, :throwing_c,
             :defense_1b, :defense_2b, :defense_3b, :defense_ss,
             :defense_of, :throwing_of,
             :defense_lf, :throwing_lf, :defense_cf, :throwing_cf, :defense_rf, :throwing_rf,
             :is_pitcher, :starter_stamina, :relief_stamina, :is_relief_only,
             :pitching_style_id, :pinch_pitching_style_id, :catcher_pitching_style_id,
             :batting_style_id,
             :pitching_style_description, :batting_style_description,
             :special_defense_c, :special_throwing_c,
             :biorhythm_ids, :batting_skill_ids, :pitching_skill_ids, :player_type_ids,
             :catcher_ids, :partner_pitcher_ids

  def catcher_ids
    object.catchers_players.pluck(:catcher_id)
  end

  def pitching_skill_ids
    object.player_pitching_skills.pluck(:pitching_skill_id)
  end

  def batting_skill_ids
    object.player_batting_skills.pluck(:batting_skill_id)
  end

  def player_type_ids
    object.player_player_types.pluck(:player_type_id)
  end

  def biorhythm_ids
    object.player_biorhythms.pluck(:biorhythm_id)
  end

  # ⚠️ 重複定義あり (L12-13 と L27-28)
  def catcher_ids
    object.catchers_players.pluck(:catcher_id)
  end

  def partner_pitchers_players
    object.partner_pitchers_players.pluck(:player_id)
  end
end
```

**⚠️ 問題**: `catcher_ids` メソッドが2回定義されている (L12-14 と L27-29)。後の定義が有効になるため動作上の問題はないが冗長。

**用途**: 選手編集画面 (全フィールドを含む詳細版)

---

## 4. フロントエンド実装詳細

### 4.1 画面構成

#### 4.1.1 選手一覧画面 (src/views/Players.vue)

##### レイアウト

```
┌───────────────────────────────────────────────────────┐
│ 選手一覧                          [ + 選手を追加 ]     │
├───────────────────────────────────────────────────────┤
│ [🔍 名前検索          ] [▼ ポジション]                │  ← フィルター
├──────┬──────────┬──────────┬──────────┬──────────────┤
│背番号│ 名前      │ 短縮名    │ポジション│ 操作          │
├──────┼──────────┼──────────┼──────────┼──────────────┤
│  1   │博麗 霊夢  │ 霊夢      │ 投手      │ [編集] [削除]│
│  2   │霧雨 魔理沙│ 魔理沙    │ 外野手    │ [編集] [削除]│
└──────┴──────────┴──────────┴──────────┴──────────────┘
```

##### 検索・フィルター機能

```vue
<!-- フィルターUI -->
<v-row dense class="mb-4">
  <v-col cols="12" sm="6" md="4">
    <v-text-field
      v-model="searchText"
      :label="t('playerList.filters.searchPlaceholder')"
      prepend-inner-icon="mdi-magnify"
      clearable dense hide-details
    ></v-text-field>
  </v-col>
  <v-col cols="12" sm="6" md="3">
    <v-select
      v-model="selectedPosition"
      :items="positionFilterOptions"
      :label="t('playerList.filters.position')"
      clearable dense hide-details
    ></v-select>
  </v-col>
</v-row>
```

**フィルター条件:**

| フィルター | v-model | 動作 |
|-----------|---------|------|
| 名前検索 | `searchText` | `name` または `short_name` に対する大文字小文字無視の部分一致 |
| ポジション | `selectedPosition` | `position` の完全一致。選択肢: 投手/捕手/内野手/外野手 |

**フィルター実装:**
```typescript
const filteredPlayers = computed(() => {
  let result = players.value

  if (searchText.value) {
    const search = searchText.value.toLowerCase()
    result = result.filter(
      (player) =>
        player.name.toLowerCase().includes(search) ||
        (player.short_name && player.short_name.toLowerCase().includes(search)),
    )
  }

  if (selectedPosition.value) {
    result = result.filter((player) => player.position === selectedPosition.value)
  }

  return result
})
```

- `v-data-table` の `:items` には `filteredPlayers`（フィルター適用後のリスト）を渡す
- フィルターはクライアントサイドで実行（APIにフィルターパラメータは送信しない）

##### ステート管理

```typescript
const players = ref<PlayerDetail[]>([])
const loading = ref(true)
const dialog = ref(false)
const editedItem = ref<PlayerDetail | null>(null)
const searchText = ref('')
const selectedPosition = ref<string | null>(null)

const fetchPlayers = async () => {
  loading.value = true
  try {
    const response = await axios.get<PlayerDetail[]>('/players')
    players.value = response.data
  } catch {
    showSnackbar(t('playerList.fetchFailed'), 'error')
  } finally {
    loading.value = false
  }
}

onMounted(fetchPlayers)
```

##### 選手削除

```typescript
const deletePlayer = async (id: number) => {
  if (!confirmDialog.value) return
  const result = await confirmDialog.value.open(
    t('playerList.deleteConfirmTitle'),
    t('playerList.deleteConfirmMessage'),
    { color: 'error' },
  )
  if (!result) return
  try {
    await axios.delete(`/players/${id}`)
    showSnackbar(t('playerList.deleteSuccess'), 'success')
    fetchPlayers()
  } catch (error) {
    console.error('Error deleting player:', error)
    showSnackbar(t('playerList.deleteFailed'), 'error')
  }
}
```

---

#### 4.1.2 選手編集ダイアログ (src/components/players/PlayerDialog.vue)

##### 構造

```
PlayerDialog (900px幅モーダル)
├─ PlayerIdentityForm (基本情報)
├─ FielderAbilityForm (野手能力)
├─ DefenseAbilityForm (守備能力)
├─ v-checkbox (投手フラグ)
└─ PitchingAbilityForm (投手能力) ← is_pitcher=true の場合のみ表示
```

##### タイトル決定ロジック

```typescript
const title = computed(() => (
  props.item ? t('playerDialog.title.edit') : t('playerDialog.title.add')
))
```

##### バリデーション

```typescript
const isFormValid = computed(() => {
  const item = editableItem.value;
  return !!item.name &&
         item.bunt != null &&
         item.steal_start != null &&
         item.steal_end != null &&
         item.speed != null &&
         item.injury_rate != null;
})
```

**保存ボタン**: `!isFormValid` の場合 `disabled`

##### 保存処理

```typescript
const saveItem = async () => {
  if (!isFormValid.value) return
  try {
    const payload = { player: editableItem.value }
    props.item?.id
      ? await axios.put(`/players/${props.item.id}`, payload)
      : await axios.post('/players', payload)

    showSnackbar(
      props.item?.id ? t('playerDialog.notifications.updateSuccess')
                     : t('playerDialog.notifications.addSuccess'),
      'success'
    )
    emit('save')
    closeDialog()
  } catch (error) {
    const message = isAxiosError(error) && Array.isArray(error.response?.data?.errors)
      ? t('playerDialog.notifications.saveFailedWithErrors',
          { errors: (error.response?.data?.errors as string[]).join('\n') })
      : t('playerDialog.notifications.saveFailed')
    showSnackbar(message, 'error')
  }
}
```

---

### 4.2 サブフォーム詳細

#### 4.2.1 PlayerIdentityForm (基本情報)

##### フィールド一覧

| ラベル | v-model | type | 制約 |
|--------|---------|------|------|
| 背番号 | number | text | maxlength=4, clearable |
| 名前 | name | text | 必須, autofocus |
| 短縮名 | short_name | text | 任意 |
| ポジション | position | select | pitcher/catcher/infielder/outfielder |
| 投 | throwing_hand | select | right_throw/left_throw |
| 打 | batting_hand | select | right_bat/left_bat/switch_hitter |
| 選手タイプ | player_type_ids | select | 複数選択, chips |

##### セレクトボックスの国際化

```typescript
const positionOptions = computed(() => [
  { value: 'pitcher', title: 'pitcher', japanese: t('baseball.positions.pitcher') },
  { value: 'catcher', title: 'catcher', japanese: t('baseball.positions.catcher') },
  { value: 'infielder', title: 'infielder', japanese: t('baseball.positions.infielder') },
  { value: 'outfielder', title: 'outfielder', japanese: t('baseball.positions.outfielder') },
]);
```

`v-select` は `#item` および `#selection` スロットで `item.raw.japanese` を表示。

##### マスターデータ取得

```typescript
onMounted(() => {
  fetchPlayerTypes()  // GET /api/v1/player-types
})
```

---

#### 4.2.2 FielderAbilityForm (野手能力)

##### フィールド一覧

| ラベル | v-model | type | 範囲 | 必須 |
|--------|---------|------|------|------|
| 盗塁スタート | steal_start | number | 1〜22 | ✓ |
| 盗塁エンド | steal_end | number | 1〜22 | ✓ |
| バント | bunt | number | 1〜10 | ✓ |
| 走力 | speed | number | 1〜5 | ✓ |
| 怪我率 | injury_rate | number | 1〜7 | ✓ |
| 打撃スタイル | batting_style_id | select | - | - |
| 打撃スタイル説明 | batting_style_description | text | - | - |
| 打撃スキル | batting_skill_ids | select | 複数選択 | - |

##### 条件付きフィールド: バイオリズム

```typescript
const isBiorhythmEnabled = computed(() => {
  return editableItem.value.batting_skill_ids?.includes(3) ||
         editableItem.value.pitching_skill_ids?.includes(10);
});
```

**表示条件**: 打撃スキルに ID=3 が含まれる、または投球スキルに ID=10 が含まれる場合

```vue
<v-row dense v-if="isBiorhythmEnabled">
  <v-col cols="12" sm="5">
    <v-select
      v-model="editableItem.biorhythm_ids"
      :items="biorhythms"
      :label="t('playerDialog.form.biorhythms')"
      multiple chips clearable
    ></v-select>
  </v-col>
</v-row>
```

##### マスターデータ取得

```typescript
onMounted(() => {
  fetchBattingStyles()   // GET /api/v1/batting-styles
  fetchBattingSkills()   // GET /api/v1/batting-skills
  fetchBiorhythms()      // GET /api/v1/biorhythms
})
```

---

#### 4.2.3 PitchingAbilityForm (投手能力)

**表示条件**: `PlayerDialog` で `is_pitcher == true` の場合のみ

##### 基本フィールド

| ラベル | v-model | type | 範囲 | disabled条件 |
|--------|---------|------|------|-------------|
| 先発スタミナ | starter_stamina | number | 4〜9 | `is_relief_only == true` |
| リリーフスタミナ | relief_stamina | number | 0〜3 | - |
| リリーフ専門 | is_relief_only | checkbox | - | - |
| 投球スキル | pitching_skill_ids | select | 複数選択 | - |
| 投球スタイル | pitching_style_id | select | - | - |
| 代打時投球スタイル | pinch_pitching_style_id | select | - | - |
| 投球スタイル説明 | pitching_style_description | text | - | - |
| 相性捕手あり | showPartnerCatchers (local) | checkbox | - | - |

##### 条件付きフィールド: 相性捕手

```typescript
const showPartnerCatchers = ref(false)

watch(() => editableItem, (newItem) => {
  if (newItem) {
    showPartnerCatchers.value = !!newItem.value.catcher_ids.length;
  }
}, { immediate: true, deep: true })
```

**表示条件**: `showPartnerCatchers == true`

```vue
<v-row dense v-show="showPartnerCatchers">
  <v-col cols="12" sm="6">
    <PlayerDetailSelect
      v-model="editableItem.catcher_ids"
      :players="catchers"
      :label="t('playerDialog.form.catchers')"
    />
  </v-col>
  <v-col cols="12" sm="3">
    <v-select
      v-model="editableItem.catcher_pitching_style_id"
      :items="pitchingStyles"
      :label="t('playerDialog.form.catcher_pitching_style')"
      clearable
    ></v-select>
  </v-col>
</v-row>
```

##### キーボードショートカット

```typescript
const reliefStaminaInput = useTemplateRef('reliefStaminaInput');

const onStarterStaminaKeydown = (event: KeyboardEvent) => {
  if (event.key === '/') {
    event.preventDefault();
    reliefStaminaInput.value?.focus();
  }
};

const onReliefStaminaKeydown = (event: KeyboardEvent) => {
  if (event.key.toUpperCase() === 'R') {
    editableItem.value.is_relief_only = true
    editableItem.value.starter_stamina = null
    event.preventDefault();
  }
};
```

- **先発スタミナ入力中に `/` キー**: リリーフスタミナフィールドへフォーカス移動
- **リリーフスタミナ入力中に `R` キー**: `is_relief_only = true` に設定し、先発スタミナを `null` にクリア

---

#### 4.2.4 DefenseAbilityForm (守備能力)

##### セクション構成

```
┌─ 投手・捕手セクション
│  ├─ P守備力
│  ├─ C守備力
│  ├─ C送球
│  └─ 相性投手あり (checkbox)
│      └─ 相性投手フィールド (条件付き)
│
├─ 内野手セクション
│  ├─ 1B守備力
│  ├─ 2B守備力
│  ├─ 3B守備力
│  └─ SS守備力
│
└─ 外野手セクション
   ├─ 統合モード (showIndividualOutfielders == false)
   │  ├─ OF守備力
   │  └─ OF送球
   │
   └─ 個別モード (showIndividualOutfielders == true)
      ├─ LF守備力 + LF送球
      ├─ CF守備力 + CF送球
      └─ RF守備力 + RF送球
```

##### 守備力バリデーション

```typescript
const rules = {
  defenseFormat: (value: string) =>
    !value || /^[0-5][A-E|S]$/.test(value) || t('validation.validation.defenseFormat'),
};
```

**正規表現**: `/^[0-5][A-E|S]$/`
**許可パターン**: `0A`, `1B`, `2C`, `3D`, `4E`, `5S` 等

##### 送球フィールドの連動制御

```typescript
<v-text-field
  v-model.number="editableItem.throwing_c"
  :label="`${t('baseball.shortPositions.c')} ${t('playerDialog.form.throwing')}`"
  type="number"
  :disabled="!editableItem.defense_c"
  clearable
></v-text-field>
```

**disabled条件**: 対応する守備力フィールドが空の場合

##### 外野個別設定の自動切替

```typescript
const showIndividualOutfielders = ref(false);

watch(() => editableItem, (newItem) => {
  if (newItem) {
    showIndividualOutfielders.value = !!(
      editableItem.value.defense_lf ||
      editableItem.value.defense_cf ||
      editableItem.value.defense_rf
    );
  }
}, { immediate: true, deep: true })

watch(showIndividualOutfielders, (isIndividual) => {
  if (!isIndividual) {
    editableItem.value.defense_lf = null;
    editableItem.value.throwing_lf = null;
    editableItem.value.defense_cf = null;
    editableItem.value.throwing_cf = null;
    editableItem.value.defense_rf = null;
    editableItem.value.throwing_rf = null;
  }
});
```

**動作**:
- 編集時: `defense_lf/cf/rf` のいずれかが存在すれば、自動的に `showIndividualOutfielders = true`
- 統合モードへ切替時: 個別フィールドを全て `null` にクリア

---

### 4.3 型定義の問題点

#### 4.3.1 PlayerDetail型の型エラー (src/types/playerDetail.ts)

```typescript
export interface PlayerDetail {
  // ... 省略 ...
  defense_p: number | null;      // ⚠️ 誤り: string | null であるべき
  defense_c: number | null;      // ⚠️ 誤り: string | null であるべき
  defense_1b: number | null;     // ⚠️ 誤り: string | null であるべき
  defense_2b: number | null;     // ⚠️ 誤り: string | null であるべき
  defense_3b: number | null;     // ⚠️ 誤り: string | null であるべき
  defense_ss: number | null;     // ⚠️ 誤り: string | null であるべき
  defense_of: number | null;     // ⚠️ 誤り: string | null であるべき
  defense_lf: number | null;     // ⚠️ 誤り: string | null であるべき
  defense_cf: number | null;     // ⚠️ 誤り: string | null であるべき
  defense_rf: number | null;     // ⚠️ 誤り: string | null であるべき
  special_defense_c: number | null; // ⚠️ 誤り: string | null であるべき
  special_throwing_c: string | null; // ⚠️ 誤り: number | null であるべき
}
```

**問題点**:

1. **守備力フィールド** (`defense_p` 等) は `string` 型であるべき
   - スキーマ定義: `t.string "defense_p"` (schema.rb L225)
   - 格納値: `"5A"`, `"2C"` 等の文字列

2. **special_throwing_c** は `number` 型であるべき
   - スキーマ定義: `t.integer "special_throwing_c"` (schema.rb L251)
   - バリデーション: `-5..5` の整数 (player.rb L57-63)

**正しい型定義**:

```typescript
export interface PlayerDetail {
  // ... 省略 ...
  defense_p: string | null;
  defense_c: string | null;
  defense_1b: string | null;
  defense_2b: string | null;
  defense_3b: string | null;
  defense_ss: string | null;
  defense_of: string | null;
  defense_lf: string | null;
  defense_cf: string | null;
  defense_rf: string | null;
  special_defense_c: string | null;
  special_throwing_c: number | null;
}
```

#### 4.3.2 Player型 (正しい参考例)

`src/types/player.ts` では、守備力フィールドが正しく `string` 型で定義されている:

```typescript
export interface Player {
  // ... 省略 ...
  defense_p?: string;   // ✓ 正しい
  defense_c?: string;   // ✓ 正しい
  defense_1b?: string;  // ✓ 正しい
  // ... 以下同様
}
```

**影響**: TypeScript のコンパイルエラーは発生しないが、実行時に `v-text-field` が数値型として扱うため、`"5A"` のような文字列入力が正しく保存されない可能性がある。

---

## 5. ビジネスロジック補足

### 5.1 投手-捕手相性の双方向性

```ruby
# 投手側のアクセス
pitcher = Player.find(1)
pitcher.catchers          # => [Player#5, Player#7]  相性の良い捕手一覧

# 捕手側のアクセス
catcher = Player.find(5)
catcher.partner_pitchers  # => [Player#1, Player#3]  相性の良い投手一覧
```

`catchers_players` テーブルは1レコードで双方向の関連を表現する。

### 5.2 enum の実装方式

Rails 8 では `enum` が文字列ベースで実装されている:

```ruby
enum :position, {
  pitcher: 'pitcher',
  catcher: 'catcher',
  infielder: 'infielder',
  outfielder: 'outfielder'
}
```

データベースには文字列 `'pitcher'` が格納される (整数ではない)。

### 5.3 中間テーブルへの自動挿入

```ruby
player = Player.create!(
  name: '博麗 霊夢',
  batting_skill_ids: [1, 2, 3]  # 配列で指定
)
```

上記のコードにより、以下のレコードが自動的に挿入される:

```sql
INSERT INTO player_batting_skills (player_id, batting_skill_id) VALUES (1, 1);
INSERT INTO player_batting_skills (player_id, batting_skill_id) VALUES (1, 2);
INSERT INTO player_batting_skills (player_id, batting_skill_id) VALUES (1, 3);
```

Railsの `has_many` + `accepts_nested_attributes_for` 機能により実現。

---

## 6. フロントエンド補足

### 6.1 defineModel の使用

**Vue 3.4+** の新機能。親コンポーネントの `v-model` を子コンポーネントで双方向バインドする際に使用。

```typescript
// 親 (PlayerDialog.vue)
<FielderAbilityForm v-model="editableItem"></FielderAbilityForm>

// 子 (FielderAbilityForm.vue)
const editableItem = defineModel<PlayerDetail>({
  type: Object,
  required: true,
});

// 子で editableItem.value を変更すると、親の editableItem も自動的に更新される
```

従来の `props + emit('update:modelValue')` パターンを簡潔に記述できる。

### 6.2 国際化 (vue-i18n)

全ラベル・メッセージは `src/locales/ja.json` で管理:

```json
{
  "playerDialog": {
    "form": {
      "name": "名前",
      "number": "背番号",
      "position": "ポジション"
    }
  },
  "baseball": {
    "positions": {
      "pitcher": "投手",
      "catcher": "捕手",
      "infielder": "内野手",
      "outfielder": "外野手"
    }
  }
}
```

使用例:

```typescript
t('playerDialog.form.name')        // → "名前"
t('baseball.positions.pitcher')    // → "投手"
```

### 6.3 useSnackbar コンポーザブル

トースト通知を表示する共通コンポーザブル:

```typescript
const { showSnackbar } = useSnackbar()
showSnackbar('保存しました', 'success')
showSnackbar('エラーが発生しました', 'error')
```

実装: `src/composables/useSnackbar.ts`

---

## 7. 既知の問題点・制約事項

### 7.1 バグ一覧

| ID | ファイル | 行数 | 問題 | 影響 | 優先度 | 状態 |
|----|---------|------|------|------|--------|------|
| BUG-001 | src/views/Players.vue | - | 削除エンドポイントが `/managers/:id` になっていた | 選手削除が動作しなかった | **高** | **修正済み** |
| BUG-002 | app/models/player.rb | - | injury_rate のバリデーションメッセージ不整合 | - | 中 | **修正済み**（i18nキーに移行） |
| BUG-003 | app/serializers/player_detail_serializer.rb | - | `catcher_ids` メソッドが重複定義 | コードが冗長 | 低 | 未修正 |
| BUG-004 | src/types/playerDetail.ts | - | 守備力フィールドが `number | null` だが `string | null` であるべき | 入力不具合の可能性 | **高** | 未修正 |
| BUG-005 | src/types/playerDetail.ts | - | `special_throwing_c` が `string | null` だが `number | null` であるべき | 入力不具合の可能性 | **高** | 未修正 |

### 7.2 未実装機能

- **選手の一括インポート**: CSV/Excel からの一括登録機能
- **選手画像アップロード**: プロフィール画像の管理
- **選手の詳細統計**: 過去の成績データとの連携

> **変更履歴**: 選手の検索・フィルター機能は実装済み。名前検索（部分一致）とポジションフィルターが利用可能。

### 7.3 パフォーマンス上の制約

- **N+1クエリの残存**: `player.teams` など、一部のリレーションで eager_load 未実施
- **ページネーションなし**: 選手数が1000人を超えると一覧画面の初期ロードが遅延する可能性

### 7.4 設計上の制約

- **外野守備の排他制御**: `defense_of` (統合) と `defense_lf/cf/rf` (個別) の同時設定はバックエンドの `defense_of_exclusivity` バリデーションで禁止される。フロントエンドでも統合/個別モードの切り替えUIで制御
- **投球スタイルの複雑性**: `pitching_style_id`, `pinch_pitching_style_id`, `catcher_pitching_style_id` の3種類があるが、優先順位や適用条件のドキュメントが不足

---

## 8. テスト指針 (参考)

### 8.1 バックエンドテスト項目

#### モデルテスト (RSpec)

- [ ] 守備力フォーマットバリデーション (`0A`〜`5S` のみ許可)
- [ ] 送球値の必須連動 (守備力が設定されている場合のみ送球値必須)
- [ ] スタミナバリデーション (先発4〜9、リリーフ0〜3)
- [ ] `is_relief_only == true` 時に先発スタミナのバリデーションがスキップされること
- [ ] 中間テーブルの一意性制約 (同一選手へのスキル重複登録を防止)
- [ ] カスケード削除 (選手削除時に関連レコードも削除)

#### コントローラーテスト (RSpec)

- [ ] GET /players で全選手が ID 昇順で取得できること
- [ ] GET /players/:id で指定選手が取得できること
- [ ] POST /players で選手が作成できること
- [ ] POST /players でバリデーションエラーが正しく返されること
- [ ] PATCH /players/:id で部分更新ができること
- [ ] DELETE /players/:id で選手が削除できること

### 8.2 フロントエンドテスト項目 (参考)

#### コンポーネントテスト (Vitest + Vue Test Utils)

- [ ] Players.vue: 選手一覧が表示されること
- [ ] Players.vue: 「選手を追加」ボタンでダイアログが開くこと
- [ ] PlayerDialog: 新規作成時に defaultItem で初期化されること
- [ ] PlayerDialog: 編集時に props.item で初期化されること
- [ ] PlayerDialog: `is_pitcher == false` の場合 PitchingAbilityForm が非表示になること
- [ ] DefenseAbilityForm: 外野統合モード↔個別モードの切替時にフィールドがクリアされること

---

## 9. 参考資料

### 9.1 関連ファイル一覧

#### バックエンド

| ファイル | 行数 | 説明 |
|---------|------|------|
| `app/models/player.rb` | 134 | Playerモデル (バリデーション、リレーション) |
| `app/controllers/api/v1/players_controller.rb` | 49 | CRUD API |
| `app/serializers/player_serializer.rb` | 12 | 簡易版シリアライザー |
| `app/serializers/player_detail_serializer.rb` | 33 | 詳細版シリアライザー |
| `app/models/player_batting_skill.rb` | 6 | 中間テーブル |
| `app/models/player_pitching_skill.rb` | 6 | 中間テーブル |
| `app/models/player_player_type.rb` | 6 | 中間テーブル |
| `app/models/player_biorhythm.rb` | 6 | 中間テーブル |
| `app/models/catchers_player.rb` | 4 | 投手-捕手相性 |
| `db/schema.rb` | 414 | DBスキーマ定義 |
| `config/routes.rb` | 87 | ルーティング |

#### フロントエンド

| ファイル | 行数 | 説明 |
|---------|------|------|
| `src/views/Players.vue` | 167 | 選手一覧画面 (検索・フィルター機能付き) |
| `src/components/players/PlayerDialog.vue` | 140 | 選手編集ダイアログ |
| `src/components/players/PlayerIdentityForm.vue` | 153 | 基本情報フォーム |
| `src/components/players/FielderAbilityForm.vue` | 170 | 野手能力フォーム |
| `src/components/players/PitchingAbilityForm.vue` | 188 | 投手能力フォーム |
| `src/components/players/DefenseAbilityForm.vue` | 308 | 守備能力フォーム |
| `src/types/playerDetail.ts` | 48 | PlayerDetail型定義 |
| `src/types/player.ts` | 29 | Player型定義 |
| `src/types/playerType.ts` | 5 | PlayerType型定義 |

### 9.2 ER図 (簡略版)

```
┌──────────────┐
│   players    │
│ (46 columns) │
└──────┬───────┘
       │
       ├─ has_many ─▶ player_batting_skills ─▶ batting_skills
       ├─ has_many ─▶ player_pitching_skills ─▶ pitching_skills
       ├─ has_many ─▶ player_player_types ─▶ player_types
       ├─ has_many ─▶ player_biorhythms ─▶ biorhythms
       ├─ has_many ─▶ catchers_players ─┐
       │                                  │
       │                  (自己参照多対多) │
       │                                  │
       └──────────────────────────────────┘
```

---

**仕様書作成者**: 足軽4号
**作成日**: 2026-02-14
**最終更新**: 2026-02-21
**根拠**: 実ソースコード (thbigmatome/, thbigmatome-front/)
