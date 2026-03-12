# セカンドチームルール 設計書

## cmd_538 / 作成: 2026-03-12 / 更新: 2026-03-12 (cmd_539, cmd_543) / 作成者: 軍師マキノ

---

## 0. User / Manager / Team の関係性

### 0.1 3つの概念

| 概念 | 説明 | 例 |
|------|------|-----|
| **User** | ツールにログインする人。`has_secure_password`。コミッショナーもUserになりうる | morinaga (commissioner), tanaka (player) |
| **Manager** | このゲームをプレイする人（監督）。ログインしない人も含む。チームの「所有者」 | 田中監督、佐藤監督 |
| **Team** | チーム。Managerが `TeamManager(role: director)` として紐づく | 東方オールスターズ、ハチナイドリームス |

### 0.2 関係図

```
User (ログインアカウント)
  │
  ├── has_many :teams (user_id FK)          ← ログインアクセス権・代理管理権
  │     ↓
  │   Team
  │     ├── has_many :team_managers
  │     │     ├── TeamManager(role: director) ← ゲーム上のチーム所有者（1チーム1人）
  │     │     └── TeamManager(role: coach)    ← コーチ（複数可）
  │     ├── has_many :team_memberships → Players
  │     └── ...
  │
Manager (ゲーム上の監督)
  ├── has_many :team_managers
  └── has_many :teams, through: :team_managers
```

### 0.3 重要な区別

| 項目 | User.user_id | Manager(director) |
|------|-------------|-------------------|
| 意味 | ログインアクセス権 | ゲーム上のチーム所有者 |
| 1対多 | 1 User → 多数 Teams 可能 | 1 Manager → **最大2 Teams**（本設計で制約追加） |
| 用途例 | コミッショナーが全チームを代理管理 | 田中監督が通常チーム + ハチナイチームを持つ |
| 排他の単位 | **ではない** | **排他チェックの単位** |

**セカンドチームの排他チェックはManager(director)単位で行う**。
User単位ではない理由: コミッショナーが複数チームの `user_id` を持つ場合があり、
User単位だとコミッショナーの代理管理チーム間で誤って排他が発動する。

---

## 1. 現状調査

### 1.1 既存のチーム構造

```
User (has_many :teams)
  └── Team (belongs_to :user, optional: true)
        ├── team_managers (has_many)
        │     ├── director (has_one, through: director_team_manager)
        │     └── coaches (has_many, through: coach_team_managers)
        ├── team_memberships (has_many, UNIQUE: team_id + player_id)
        │     └── Player (belongs_to)
        ├── season (has_one)
        ├── competition_entries (has_many)
        ├── lineup_templates (has_many)
        └── squad_text_setting (has_one)
```

**重要**: `User has_many :teams` の構造は既に存在する → 複数チーム保持は構造的に可能。
**重要**: `TeamManager(role: director)` の `validates :team_id, uniqueness: { scope: :role }` で1チーム1director は保証済み。

### 1.2 teamsテーブル（現状）

```
teams:
├── name (string)
├── short_name (string)
├── is_active (boolean, default: true)
├── user_id (FK → users, nullable)
└── timestamps
```

**team_typeカラムは存在しない**。
※ `seasons.team_type` が存在するが、これはシーズン単位の属性であり、チーム固有の属性ではない。

### 1.3 外の世界枠判定ロジック（現状）

```ruby
# Team#outside_world_first_squad_memberships
team_memberships.where(squad: "first")
  .joins(:player)
  .where.not(players: { series: "touhou" })
```

**現在の判定**: `Player.series != "touhou"` → 外の世界枠
- touhou → ネイティブ（外の世界枠を消費しない）
- hachinai / tamayomi / original → 外の世界枠を消費

**定数**: `OUTSIDE_WORLD_LIMIT = 4`

### 1.4 Player.series の値分布

| series | 説明 | 現チームでのネイティブ判定 |
|--------|------|------------------------|
| `touhou` | 東方キャラ | ネイティブ |
| `hachinai` | ハチナイキャラ | 外の世界 |
| `tamayomi` | 球詠キャラ | 外の世界 |
| `original` | オリジナルキャラ | 外の世界 |

### 1.5 選手排他制約（現状なし）

現在、同一ユーザーの複数チーム間で選手の重複を防ぐ仕組みは存在しない。
TeamMembership の UNIQUE制約は `(team_id, player_id)` のみ → 同一選手が別チームに所属可能。

### 1.6 FE チーム作成/編集画面（現状）

- **TeamDialog.vue**: name, short_name, director_id, coach_ids, is_active
- **team_type選択UIなし**
- **TeamList.vue**: チーム一覧 + CRUD操作

### 1.7 既存セカンドチーム保持者

3名のユーザーが既にセカンドチームを保持（データ移行必要）。
→ 移行時に team_type を設定する必要あり。

---

## 2. DB変更案

### 2.1 teams テーブルに team_type 追加

```ruby
add_column :teams, :team_type, :string, null: false, default: "normal"
add_index :teams, :team_type
```

**team_type の値**:

| 値 | 説明 |
|----|------|
| `normal` | 通常チーム（東方がネイティブ） |
| `hachinai` | ハチナイチーム（ハチナイ/球詠がネイティブ） |

**設計判断**: `seasons.team_type` は廃止候補（将来的にteams.team_typeに統合）。
チームの種別はチーム作成時に決定し、シーズンごとに変わるものではないため。

### 2.2 マイグレーション

```ruby
class AddTeamTypeToTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :teams, :team_type, :string, null: false, default: "normal"
    add_index :teams, :team_type
  end
end
```

---

## 3. 外の世界枠判定ロジック変更案

### 3.1 team_type別ネイティブ判定

| team_type | ネイティブ series | 外の世界 series |
|-----------|-----------------|----------------|
| `normal` | `touhou` | `hachinai`, `tamayomi`, `original` |
| `hachinai` | `hachinai`, `tamayomi` | `touhou`, `original` |

**設計判断**:
- `hachinai` チームでは `tamayomi`（球詠）もネイティブ扱い。
  理由: 球詠は八月のシンデレラナインとの合同コラボ出典であり、ハチナイ系列と同カテゴリ。
- `original` は**どちらのチームでも外の世界枠**。

### 3.2 Team モデル変更

```ruby
class Team < ApplicationRecord
  VALID_TEAM_TYPES = %w[normal hachinai].freeze
  validates :team_type, inclusion: { in: VALID_TEAM_TYPES }

  # team_typeに応じたネイティブseries一覧
  NATIVE_SERIES = {
    "normal"   => %w[touhou].freeze,
    "hachinai" => %w[hachinai tamayomi].freeze
  }.freeze

  # 1軍の外の世界枠選手
  def outside_world_first_squad_memberships
    native = NATIVE_SERIES[team_type] || NATIVE_SERIES["normal"]
    team_memberships.where(squad: "first")
      .joins(:player)
      .where.not(players: { series: native })
  end

  # validate_outside_world_limit, validate_outside_world_balance は変更不要
  # （outside_world_first_squad_memberships の戻り値が変わるため、自動的に正しく動作）
end
```

**変更箇所**: `outside_world_first_squad_memberships` メソッドのみ。
他の2メソッド（`validate_outside_world_limit`, `validate_outside_world_balance`）はこのメソッドに依存しているため、自動的に正しく動作する。

### 3.3 TeamRostersController 変更

```ruby
# 現行: is_outside_world: tm.player.series != "touhou"
# 変更: team.team_type に応じた判定
native = Team::NATIVE_SERIES[team.team_type] || Team::NATIVE_SERIES["normal"]
is_outside_world: !native.include?(tm.player.series)
```

---

## 4. 選手排他バリデーション設計

### 4.1 ルール

同一Manager（director）が監督を務める複数チーム間で、同じ選手を登録できない。

**User単位ではなくManager(director)単位にする理由**:
- コミッショナー（User）は代理管理で複数チームの `user_id` を持つ場合がある
- User単位だと代理管理チーム間で誤って排他が発動する
- ゲーム上の「チームオーナー」= Manager(director) が排他の正しい単位

### 4.2 1 Manager = 最大2 Teams 制約

```ruby
# app/models/team_manager.rb
class TeamManager < ApplicationRecord
  belongs_to :team
  belongs_to :manager

  enum :role, { director: 0, coach: 1 }

  validates :role, presence: true
  validates :team_id, uniqueness: { scope: :role, if: -> { director? }, message: :director_already_exists }

  # 1 Manager が director を務められるアクティブチームは最大2つ
  validate :director_team_limit, on: [:create, :update], if: -> { director? }

  private

  def director_team_limit
    # is_active: true のチームのみカウント（非アクティブ化で枠解放可能）
    existing_count = TeamManager.joins(:team)
                                .where(manager_id: manager_id, role: :director)
                                .where(teams: { is_active: true })
                                .where.not(id: id)
                                .count
    if existing_count >= 2
      errors.add(:manager_id,
        I18n.t("activerecord.errors.models.team_manager.director_team_limit",
               manager_name: manager&.name, limit: 2))
    end
  end
end
```

**is_active と最大2チーム制約の関係**:
- `is_active: true` のチームのみ最大2チーム制約にカウント
- チームを非アクティブ化（`is_active: false`）すると枠が解放され、新チームを作成可能
- teams テーブルには既に `is_active` カラムが存在（default: true）→ マイグレーション不要
- 例: Manager Aが2チーム持ち → 1チーム目を `is_active: false` → 新しいチーム作成可能

### 4.3 選手排他バリデーション実装

```ruby
class TeamMembership < ApplicationRecord
  validate :player_not_in_director_sibling_team, on: :create

  private

  def player_not_in_director_sibling_team
    return unless team

    # このチームの director を取得
    director_tm = team.director_team_manager
    return unless director_tm  # director未設定のチームは排他チェックスキップ

    director_id = director_tm.manager_id

    # 同一 director が監督するアクティブな他チームのIDを取得
    sibling_team_ids = TeamManager.joins(:team)
                                   .where(manager_id: director_id, role: :director)
                                   .where(teams: { is_active: true })
                                   .where.not(team_id: team.id)
                                   .pluck(:team_id)
    return if sibling_team_ids.empty?

    if TeamMembership.where(team_id: sibling_team_ids, player_id: player_id).exists?
      sibling_team = Team.joins(:team_managers)
                         .where(team_managers: { manager_id: director_id, role: :director })
                         .where.not(id: team.id)
                         .first
      errors.add(:player_id,
        I18n.t("activerecord.errors.models.team_membership.player_in_sibling_team",
               player_name: player&.name,
               team_name: sibling_team&.name))
    end
  end
end
```

### 4.4 バリデーション発動タイミング

| 操作 | バリデーション | 備考 |
|------|-------------|------|
| メンバー追加（TeamPlayersController#create） | ✅ 排他チェック | 追加時に同一director他チームを確認 |
| メンバー移動（チーム間トレード） | ✅ 排他チェック | 移動先チームで発動 |
| director変更 | ⚠️ 要注意 | director変更時に既存メンバーの排他チェックが必要（後述） |
| チーム削除 | なし | 排他制約は自動解除 |
| 選手マスタ削除 | なし | cascadeで処理 |

### 4.5 director変更時の整合性チェック

director を変更すると、新director の他チームとの排他関係が変わる。

```ruby
# TeamsController#update での director 変更時
def update_managers(team, director_id, coach_ids)
  team.transaction do
    old_director_id = team.director_team_manager&.manager_id

    if director_id.present? && director_id.to_i != old_director_id
      # 新director の他チームとの選手重複チェック
      new_director_teams = TeamManager.where(manager_id: director_id, role: :director)
                                       .pluck(:team_id)
      if new_director_teams.any?
        overlapping = TeamMembership.where(team_id: new_director_teams, player_id:
          team.team_memberships.pluck(:player_id))
        if overlapping.exists?
          raise ActiveRecord::RecordInvalid,
            "Director変更不可: 新しい監督の他チームと選手が重複しています"
        end
      end
    end

    # ... 既存処理
  end
end
```

### 4.6 パフォーマンス考慮

- director検索: `TeamManager.where(manager_id: X, role: :director)` → manager_idインデックスは既存
- 排他チェック: `TeamMembership.where(team_id: [...], player_id: Y).exists?` → 既存インデックスで十分
- director経由の間接参照が1段増えるが、最大2チームなのでパフォーマンス影響は無視可能

---

## 5. FE変更箇所

### 5.1 TeamDialog.vue（チーム作成/編集）

**team_type選択UIを追加**:

```
┌─────────────── チーム作成 ──────────────────────────┐
│ チーム名: [                              ]          │
│ 略称:     [          ]                              │
│                                                     │
│ チームタイプ:                                        │
│ ○ 通常チーム（東方キャラがネイティブ）               │
│ ● ハチナイチーム（ハチナイ/球詠キャラがネイティブ）   │
│                                                     │
│ ⚠ チームタイプは作成後に変更できません                │
│                                                     │
│ 監督:     [▼ 選択          ]                        │
│ コーチ:   [▼ 選択          ]                        │
│                                                     │
│              [キャンセル]  [作成]                     │
└─────────────────────────────────────────────────────┘
```

**実装ポイント**:
- `v-radio-group` で team_type 選択（normal / hachinai）
- **作成後は変更不可**（編集時はdisabled表示）
  - 理由: チームタイプ変更で外の世界枠が一気に変わり、既存ロスター構成が無効になるリスク
- 説明テキストで各タイプのネイティブ枠を明示

### 5.2 team.ts 型定義更新

```typescript
export interface Team {
  id: number
  name: string
  short_name: string
  is_active: boolean
  has_season: boolean
  team_type: 'normal' | 'hachinai'  // 追加
  director: Manager | null
  coaches: Manager[]
}
```

### 5.3 TeamMembers.vue（メンバー追加時）

**排他バリデーションエラー表示**:
- メンバー追加APIが422を返した場合、エラーメッセージをsnackbarで表示
- 「この選手は別のチーム（○○）に所属しています」

### 5.4 TeamList.vue（チーム一覧）

- team_typeをチップ表示（通常: デフォルト / ハチナイ: 色付きチップ）
- チーム名の横に小さなバッジ表示

### 5.5 ロスター関連ビュー

- `CompetitionRosterView.vue`, `ActiveRoster.vue` での外の世界枠表示は変更不要
  - BE側の `is_outside_world` フラグがteam_typeに応じて正しく返されるため

### 5.6 TeamsController 変更

```ruby
# params許可リストに team_type を追加
def team_params
  params.require(:team).permit(:name, :short_name, :is_active, :team_type, :director_id, coach_ids: [])
end

# updateでのteam_type変更を禁止
def update
  if params[:team][:team_type].present? && params[:team][:team_type] != @team.team_type
    render json: { error: "team_type cannot be changed after creation" }, status: :unprocessable_entity
    return
  end
  # ...既存処理
end
```

---

## 6. 既存3チームのデータ移行方針

### 6.1 移行手順

```ruby
# db/scripts/migrate_team_types.rb

# Step 1: 複数チームのdirectorを務めるManagerを確認
multi_team_directors = Manager.joins(:team_managers)
  .where(team_managers: { role: :director })
  .group(:id)
  .having("COUNT(team_managers.id) > 1")

multi_team_directors.each do |manager|
  teams = manager.teams.joins(:team_managers)
    .where(team_managers: { role: :director })
  puts "Manager: #{manager.name} (#{manager.id})"
  teams.each do |t|
    members = t.team_memberships.includes(:player).map { |tm|
      "#{tm.player.name} (#{tm.player.series})"
    }
    puts "  Team: #{t.name} (user_id: #{t.user_id}) - Members: #{members.join(', ')}"
  end
end

# Step 2: 手動でteam_type設定（Pと協議して決定）
# 例:
# Team.find(XX).update!(team_type: "hachinai")
# Team.find(YY).update!(team_type: "normal")  # default

# Step 3: 選手排他チェック（同一directorの複数チーム間で選手重複がないか）
multi_team_directors.each do |manager|
  director_team_ids = TeamManager.where(manager_id: manager.id, role: :director).pluck(:team_id)
  all_player_ids = TeamMembership.where(team_id: director_team_ids).pluck(:player_id)
  duplicates = all_player_ids.group_by(&:itself).select { |_, v| v.size > 1 }.keys
  if duplicates.any?
    dup_names = Player.where(id: duplicates).pluck(:name)
    puts "WARNING: Manager #{manager.name} has duplicate players: #{dup_names.join(', ')}"
  end
end
```

### 6.2 移行判断基準

- **デフォルト**: 全既存チームは `team_type: "normal"` に設定
- **ハチナイチームの判定**: チーム構成でハチナイ/球詠選手が過半数のチームは `hachinai` 候補
- **最終判断はPに委ねる**: 3チーム分なので手動で十分

### 6.3 選手重複がある場合

- 既存データで同一director管理下の複数チームに同一選手が所属している場合は、バリデーション追加前に解消が必要
- 移行スクリプトで重複を検出 → Pに報告 → どちらのチームに残すか決定

---

## 7. 実装フェーズ分割案

→ **セクション12に統合**（認可制御・監督管理UI・コミッショナー導線を含む拡張版）

---

## 8. 考慮事項・リスク

### 8.1 seasons.team_type との関係

- 現在 `seasons.team_type` が存在する（schema.rb L572）
- teams.team_type を追加すると**同名カラムが2テーブルに存在**
- 方針: `seasons.team_type` は将来的に廃止し、`team.team_type` を参照する形に移行
- Phase 1では両方維持（互換性確保）、移行完了後に seasons.team_type を削除

### 8.2 チームタイプ変更の禁止

- チームタイプ変更を許可すると、既存ロスターの外の世界枠構成が一気に無効になる
- 例: normalチームにハチナイ選手4人（外の世界枠）→ hachinaiに変更 → 東方選手が外の世界枠に移動 → 4人超過の可能性
- **結論**: 作成後の変更は禁止。変更したい場合はチーム再作成

### 8.3 球詠選手のネイティブ扱い

- 球詠（tamayomi）をハチナイチームでネイティブにする設計判断
- 根拠: 球詠はハチナイコラボカードセットとして提供されており、同系統
- **P確認推奨**: 球詠をネイティブにしない場合は `NATIVE_SERIES["hachinai"]` から `tamayomi` を除外するだけ

### 8.4 将来のチームタイプ拡張

- `original` 専用チーム等の要望が出た場合、NATIVE_SERIES にエントリ追加のみで対応可能
- team_typeをenumではなくstringにしている理由はこの拡張性のため

### 8.5 コスト上限・人数制限

- タスク仕様: 「コスト上限(200)・人数制限は1チーム目と同じ」
- 現行ロジックはチーム単位で動作 → **変更不要**

---

## 9. 認可制御設計

### 9.1 既存の認可インフラ

| 要素 | 状態 | 場所 |
|------|------|------|
| `User.role` enum | **実装済み** | `player: 0, commissioner: 1` |
| `current_user` | **実装済み** | `ApplicationController` (session[:user_id]) |
| `authenticate_user!` | **実装済み** | `BaseController` (before_action) |
| `authorize_commissioner!` | **実装済み** | `BaseController` (privateメソッド) |
| `Commissioner::BaseController` | **実装済み** | コミッショナー専用コントローラー基底 |
| `current_user.commissioner?` | **実装済み** | User enum による判定 |

**結論**: 認可基盤は既に十分に整っている。追加実装は最小限。

### 9.2 User → Manager 紐付け

**現状**: `managers.user_id` カラムが存在する（string型）。ただしFK制約なし。

```
managers テーブル:
├── name (string)
├── short_name (string)
├── irc_name (string)
├── role (integer, default: 0)  ← Manager自体のrole enum（TeamManager.roleとは別）
├── user_id (string)            ← User紐付け（string型、FK未設定）
└── timestamps
```

**問題点**: `managers.user_id` が string型のため、FK制約が設定できていない。

**修正方針**: 型変更のマイグレーション（string → bigint）は既存データ影響が大きいため、
初期はstring型のままでアプリケーションレベルで紐付けを管理する。

```ruby
# app/models/manager.rb に追加
class Manager < ApplicationRecord
  belongs_to :user, optional: true  # user_idがstring型のため、型変換後に追加

  # string型のuser_idをinteger比較するヘルパー
  def linked_user
    return nil if user_id.blank?
    User.find_by(id: user_id.to_i)
  end
end
```

### 9.3 認可レベル設計

| 操作 | 認可レベル | 実装方法 |
|------|----------|---------|
| チーム閲覧 | **全ユーザー** | 変更なし（現行通り） |
| 自分のチーム管理（SeasonPortal） | **チームオーナー or コミッショナー** | `current_user_can_manage_team?` |
| チーム作成 | **コミッショナー** | `authorize_commissioner!` |
| チーム削除 | **コミッショナー** | `authorize_commissioner!` |
| Manager CRUD | **コミッショナー** | `authorize_commissioner!` |
| 全チーム一覧（管理用） | **コミッショナー** | `authorize_commissioner!` |

### 9.4 チームオーナー判定ヘルパー

```ruby
# app/controllers/api/v1/base_controller.rb に追加
def current_user_can_manage_team?(team)
  return true if current_user.commissioner?

  # 方法1: Team.user_id で判定（ログインアクセス権）
  return true if team.user_id == current_user.id

  # 方法2: Manager紐付けで判定（directorのlinked_user）
  director = team.director
  return true if director&.user_id.to_s == current_user.id.to_s

  false
end
```

### 9.5 適用するコントローラー

初期フェーズではコミッショナーのみ利用するため、大半の操作は `authorize_commissioner!` で十分。
将来的にプレイヤーが自チームを管理する場合に `current_user_can_manage_team?` を使う。

```ruby
# TeamsController: コミッショナーのみ作成/削除
before_action :authorize_commissioner!, only: [:create, :destroy]

# ManagersController: コミッショナーのみCRUD
before_action :authorize_commissioner!

# TeamPlayersController: チームオーナー or コミッショナー
before_action :authorize_team_management!, only: [:create, :destroy]

def authorize_team_management!
  team = Team.find(params[:team_id])
  unless current_user_can_manage_team?(team)
    render json: { errors: ["権限がありません"] }, status: :forbidden
  end
end
```

---

## 10. 監督（Manager）管理UI設計

### 10.1 現状

| 要素 | 状態 |
|------|------|
| `ManagersController` | **CRUD実装済み** — index(ページネーション), show, create, update, destroy |
| `Manager` モデル | **実装済み** — name, short_name, irc_name, user_id, role |
| `ManagerList.vue` | **実装済み** — データテーブル + 展開行でチーム表示 + CRUD |
| `ManagerDialog` | **実装済み**（ManagerList内） |
| routes | **実装済み** — `/managers` (full resources) |
| `manager_params` | **:name, :short_name, :irc_name, :user_id** を permit |

**結論**: Manager管理の基本UIは既に実装されている。セカンドチーム対応で必要な追加は限定的。

### 10.2 追加が必要な変更

#### 10.2.1 ManagerList.vue 拡張

- **User紐付け表示**: Manager行にlinked User名を表示（user_idが設定されている場合）
- **チーム数表示**: 各Managerが監督するアクティブチーム数を表示（0/1/2）
- **2チーム上限警告**: 既に2チーム持ちのManagerには「チーム追加不可」を表示

```
┌──────────────────────────────────────────────────────────────────────┐
│ 監督一覧                                                    [＋追加] │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ 名前       │ 略称 │ IRC名   │ ログインUser │ チーム数 │ 操作   │ │
│ │ 田中太郎   │ 田中 │ tanaka  │ tanaka      │ 1/2     │ ✏🗑   │ │
│ │ ▼ チーム: 東方オールスターズ(normal) ✅                          │ │
│ │                                                                │ │
│ │ 佐藤花子   │ 佐藤 │ sato    │ -           │ 2/2     │ ✏🗑   │ │
│ │ ▼ チーム: 星蓮船チーム(normal) ✅ / ハチナイドリームス(hachinai) ✅│ │
│ └──────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

#### 10.2.2 ManagerDialog 拡張

- **User選択ドロップダウン追加**: 既存Userを選択してManagerに紐付け（任意）
- **user_id を送信**: POST/PATCH時に `user_id` パラメータを送信（既にpermit済み）

#### 10.2.3 TeamDialog.vue の director 選択との関係

- TeamDialog の director 選択は `v-select` でManager一覧から選ぶ（既存実装）
- セカンドチーム対応: **2チーム上限に達したManagerは選択肢から除外** or 警告表示
- 実装: Manager一覧取得時に各Managerのアクティブdirectorチーム数を含めて返す

```ruby
# ManagersController#index のレスポンスに追加
def index
  # ... 既存処理
  render json: {
    data: @managers.as_json(include: { teams: { methods: [:has_season] } },
                            methods: [:active_director_team_count]),
    meta: { ... }
  }
end
```

```ruby
# Manager モデルに追加
def active_director_team_count
  team_managers.where(role: :director).joins(:team).where(teams: { is_active: true }).count
end
```

---

## 11. コミッショナー導線設計

### 11.1 現状の導線

```
TopMenu → TeamList → [カレンダーアイコン] → SeasonPortal (/teams/:teamId/season)
                    → [メンバーアイコン]   → TeamMembers (/teams/:teamId/members)
```

- TeamList は全チーム一覧を表示
- SeasonPortal は `:teamId` パラメータで特定チームのシーズンを表示
- **現状でもコミッショナーは任意チームのSeasonPortalに遷移可能**（route的に制限なし）

### 11.2 追加が必要な導線

現状の TeamList → SeasonPortal 遷移は既に動作している。
ただし以下の改善が必要:

#### 11.2.1 TeamList.vue の team_type 表示

```
┌──────────────────────────────────────────────────────────────────────┐
│ チーム一覧                                                  [＋追加] │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ チーム名           │ タイプ    │ 監督     │ 状態   │ 操作       │ │
│ │ 東方オールスターズ  │ 通常     │ 田中太郎 │ 有効   │ 📅👥✏🗑  │ │
│ │ ハチナイドリームス  │ ハチナイ │ 佐藤花子 │ 有効   │ 📅👥✏🗑  │ │
│ │ 旧チーム           │ 通常     │ 田中太郎 │ 非活性 │ 📅👥✏🗑  │ │
│ └──────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

- team_type チップ表示（通常: デフォルト色 / ハチナイ: ピンク系チップ）
- is_active=false のチームはグレーアウト表示
- 監督名を表示（director の Manager.name）

#### 11.2.2 プレイヤー向けチーム切替（将来）

プレイヤーが自チームのSeasonPortalにアクセスする導線:
- `GET /api/v1/users/me/teams` で自分のチーム一覧を取得（**既存API**）
- TopMenu またはサイドバーにチーム切替UIを追加
- 複数チーム持ちの場合、現在操作中のチームを明示

```
┌─ サイドバー ──────────────┐
│ 🏠 ホーム                │
│ 📋 チーム切替            │
│   ├ 東方オールスターズ ✅ │  ← 現在選択中
│   └ ハチナイドリームス    │
│ 📊 成績                  │
│ ⚙ 設定                   │
└──────────────────────────┘
```

#### 11.2.3 TeamSelect ストア

チーム選択状態をPiniaストアで管理:

```typescript
// src/stores/teamSelection.ts（既存 or 新規）
export const useTeamSelectionStore = defineStore('teamSelection', {
  state: () => ({
    selectedTeamId: null as number | null,
    teams: [] as Team[]
  }),
  actions: {
    async fetchMyTeams() {
      const res = await axios.get('/users/me/teams')
      this.teams = res.data
      if (!this.selectedTeamId && this.teams.length > 0) {
        this.selectedTeamId = this.teams[0].id
      }
    },
    selectTeam(teamId: number) {
      this.selectedTeamId = teamId
    }
  }
})
```

### 11.3 API変更

#### 11.3.1 TeamsController#index にdirector情報追加

```ruby
def index
  @teams = Team.all.includes(director_team_manager: :manager).order(:id)
  render json: @teams.map { |t|
    t.as_json(only: [:id, :name, :short_name, :is_active, :team_type, :user_id]).merge(
      director_name: t.director&.name
    )
  }
end
```

#### 11.3.2 UsersController#my_teams にteam_type追加

```ruby
def my_teams
  teams = current_user.teams.order(is_active: :desc, created_at: :asc)
  render json: teams.as_json(only: [:id, :name, :is_active, :user_id, :short_name, :team_type])
end
```

---

## 12. フェーズ分割案（更新）

### Phase 0: 認可基盤整備（コミッショナー権限強化）

**目標**: 既存の認可インフラにセカンドチーム関連の権限チェックを追加

| サブタスク | 内容 | Bloom Level |
|-----------|------|-------------|
| 0-1 | ManagersController に `authorize_commissioner!` 追加 | L2 |
| 0-2 | TeamsController に `authorize_commissioner!` (create/destroy) 追加 | L2 |
| 0-3 | Manager#active_director_team_count メソッド追加 | L2 |

### Phase 1: DB + BEコア（最小MVP）

**目標**: team_typeカラム追加 + 外の世界枠判定ロジック変更

| サブタスク | 内容 | Bloom Level |
|-----------|------|-------------|
| 1-1 | マイグレーション: teams.team_type追加 | L2 |
| 1-2 | Team モデル: NATIVE_SERIES定数 + outside_world_first_squad_memberships変更 | L3 |
| 1-3 | TeamRostersController: is_outside_world判定のteam_type対応 | L3 |
| 1-4 | 既存3チームデータ移行スクリプト | L2 |
| 1-5 | RSpecテスト: normal/hachinaiの外の世界枠判定 | L3 |

### Phase 2: 選手排他バリデーション + チーム数制約

**目標**: 同一director管理チーム間で選手重複を禁止 + 1 director = 最大2アクティブチーム

| サブタスク | 内容 | Bloom Level |
|-----------|------|-------------|
| 2-1 | TeamManager: director_team_limit バリデーション（is_active条件付き） | L3 |
| 2-2 | TeamMembership: player_not_in_director_sibling_team バリデーション | L3 |
| 2-3 | TeamsController: director変更時の整合性チェック | L3 |
| 2-4 | RSpecテスト: 排他バリデーション + チーム数制約 | L3 |

### Phase 3: FE対応（チーム作成・管理）

**目標**: チーム作成UI + team_type表示 + エラー表示

| サブタスク | 内容 | Bloom Level |
|-----------|------|-------------|
| 3-1 | TeamDialog.vue: team_type選択UI追加 | L3 |
| 3-2 | team.ts型定義更新 + TeamList.vue: team_type・director名・is_active表示 | L2 |
| 3-3 | TeamMembers.vue: 排他エラー表示 | L2 |
| 3-4 | TeamsController: team_type許可 + 変更禁止ガード + director_name付与 | L2 |

### Phase 4: 監督管理UI強化

**目標**: ManagerList/Dialog のセカンドチーム対応

| サブタスク | 内容 | Bloom Level |
|-----------|------|-------------|
| 4-1 | ManagerList.vue: User紐付け表示 + チーム数表示(N/2) | L3 |
| 4-2 | ManagerDialog: User選択ドロップダウン追加 | L2 |
| 4-3 | TeamDialog: 2チーム上限到達Managerの選択制限 | L3 |
| 4-4 | ManagersController: active_director_team_count をレスポンスに含める | L2 |

### Phase 5: コミッショナー導線・チーム切替

**目標**: 複数チーム管理の利便性向上

| サブタスク | 内容 | Bloom Level |
|-----------|------|-------------|
| 5-1 | UsersController#my_teams に team_type 追加 | L2 |
| 5-2 | チーム切替UI（サイドバー or TopMenu）の追加 | L3 |
| 5-3 | TeamSelectionストア（Pinia）のセカンドチーム対応 | L3 |

### フェーズ依存関係

```
Phase 0 (認可基盤)
    ↓
Phase 1 (DB + BEコア)
    ↓
Phase 2 (排他バリデーション)
    ↓
Phase 3 (FE チーム作成・管理)  ← Phase 0 + 1 + 2 に依存
    ↓
Phase 4 (監督管理UI)           ← Phase 2 + 3 に依存
    ↓
Phase 5 (コミッショナー導線)   ← Phase 3 に依存（Phase 4と並行可能）
```

**Phase 0-2 で**: BE側のセカンドチームルールが完成。
**Phase 3 まで**: コミッショナーがFEからチーム作成・管理可能。
**Phase 4-5**: 管理利便性の向上（段階的に追加可能）。
