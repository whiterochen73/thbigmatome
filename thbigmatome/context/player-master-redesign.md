# 選手マスタ画面リニューアル設計書

**作成**: subtask_514a (cmd_514)
**作成日**: 2026-03-09

---

## 1. 概要

### 1.1 背景

cmd_508〜513でPlayerテーブルの大規模クリーンアップを実施した結果、
Playerテーブルの実データカラムは `name`, `number`, `short_name` の3カラム
（＋削除漏れ疑い2カラム）にまで縮小された。

選手の能力値・守備値・投打情報はすべてPlayerCard側に集約されており、
Player = キャラクター不変属性、PlayerCard = カードセット毎の能力データ、
という分離が完了している。

現行の選手マスタ画面（Players.vue + PlayerDialog.vue + サブフォーム群）は
DB整理前のスキーマを前提に構築されており、大量の死んだフォーム項目・
存在しないAPIエンドポイントへのリクエスト・削除済みカラムへの参照が残っている。

### 1.2 スコープ

- **対象**: 選手マスタ一覧画面（GET /players）、選手詳細/編集画面
- **対象外**: コスト関連画面（別画面で対応予定）、選手カード画面（既に整備済み）
- **デザイン方針**: PlayerCardDetailView.vueのデザインテイスト（藍色帯ヘッダー、info-grid等）を踏襲

---

## 2. Playerテーブル現状（schema.rb確認結果）

### 2.1 残存カラム一覧

```ruby
create_table "players" do |t|
  t.string   "name",                         null: false
  t.string   "number",                       null: false
  t.string   "short_name"
  t.string   "pitching_style_description"    # ← 削除漏れ疑い
  t.integer  "special_throwing_c"            # ← 削除漏れ疑い
  t.datetime "created_at",                   null: false
  t.datetime "updated_at",                   null: false
end
```

### 2.2 削除漏れ疑いカラム

| カラム | 状況 | 判定 |
|--------|------|------|
| `pitching_style_description` | PlayerCard側にも同名カラムあり。Player側は投球特徴の自由記述。Phase 1で「全件NULLではない」として除外された可能性あり | **要P判断**: データ有無を確認し、PlayerCard側に統一するか決定 |
| `special_throwing_c` | PlayerCard側にも同名カラムあり。専属捕手の送球値。同上 | **要P判断**: 同上 |

**確認コマンド**:
```sql
SELECT COUNT(*) FROM players WHERE pitching_style_description IS NOT NULL;
SELECT COUNT(*) FROM players WHERE special_throwing_c IS NOT NULL;
```
→ 0件ならマイグレーションで即削除。データありならPlayerCard側との差異検証後に判断。

### 2.3 Player側の関連（associations）

```ruby
class Player < ApplicationRecord
  has_many :team_memberships    # チーム所属
  has_many :cost_players        # コスト情報
  has_many :player_cards        # カードデータ（1:N、カードセット毎）
  has_many :at_bats_as_batter   # 打席成績
  has_many :at_bats_as_pitcher  # 投球成績
  has_many :pitcher_game_states # 投手成績
  has_many :imported_stats      # インポート成績
end
```

---

## 3. 選手マスタ一覧画面（GET /players）

### 3.1 現行の問題

- `position`カラム（削除済み）でフィルタ・表示している
- ヘッダーに`position`列がある
- `PlayerDetail`型に大量の削除済みフィールドが残存

### 3.2 リニューアル設計

**表示項目**:

| 列 | ソース | 備考 |
|----|--------|------|
| 背番号 | Player.number | 既存 |
| 名前 | Player.name | 既存 |
| 短縮名 | Player.short_name | 既存 |
| 投打 | PlayerCard.handedness (via serializer) | 最新カードから取得 |
| カード数 | player_cards.count | 新規追加。カード画面へのリンク |
| 操作 | 編集/削除 | 既存 |

**削除する項目**: position列、positionフィルター

**フィルタ**:
- 名前検索（既存、維持）
- positionフィルターは削除（PlayerCard側のis_pitcherベースに変更検討、ただしMVPでは不要）

**ソート**: 背番号(default)、名前、短縮名

### 3.3 APIレスポンス設計

現行`PlayerDetailSerializer`の属性:
```ruby
attributes :id, :name, :short_name, :number, :handedness,
           :is_pitcher, :is_relief_only,
           :pitching_style_description, :special_throwing_c
```

**変更案**:
```ruby
# PlayerSerializer（一覧用: 軽量）
attributes :id, :name, :short_name, :number, :handedness
has_many :cost_players  # 既存

# PlayerDetailSerializer（詳細用: カード情報込み）
attributes :id, :name, :short_name, :number
has_many :player_cards, serializer: PlayerCardSummarySerializer  # 新規
```

一覧では`PlayerSerializer`（既存）を使用、詳細では`PlayerDetailSerializer`を拡張。
`is_pitcher`/`is_relief_only`/`pitching_style_description`/`special_throwing_c`は
PlayerCard側の情報なので、Player serializerからは削除し、
PlayerCard経由で返す形に統一。

---

## 4. 選手詳細画面（GET /players/:id）

### 4.1 画面構成

PlayerCardDetailView.vueのデザインテイストを踏襲:

```
┌─────────────────────────────────────────────┐
│ [← 一覧に戻る]                              │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ #背番号 選手名          [選手マスタ]     │ │  ← 藍色帯ヘッダー
│ │ 短縮名                                  │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ┌── 基本情報 ────────── [編集] ──┐          │
│ │ 名前: xxx                      │          │
│ │ 背番号: xxx                    │          │
│ │ 短縮名: xxx                    │          │
│ └────────────────────────────────┘          │
│                                             │
│ ┌── 選手カード一覧 ─────────────┐          │
│ │ カードセット名   投打  走力 ...│ → 詳細   │
│ │ PM2025          右投左打 3  ...│ → 詳細   │
│ │ PM2026          右投左打 4  ...│ → 詳細   │
│ └────────────────────────────────┘          │
│                                             │
│ ┌── 所属チーム ─────────────────┐          │
│ │ チーム名      1軍/2軍  コスト │          │
│ └────────────────────────────────┘          │
└─────────────────────────────────────────────┘
```

### 4.2 カード一覧セクション

選手詳細画面の本丸。各カードセットの選手カードをテーブルで表示:

| 列 | ソース | 備考 |
|----|--------|------|
| カードセット名 | card_set.name | リンク先: PlayerCardDetailView |
| タイプ | card_type (pitcher/fielder) | チップ表示 |
| 投打 | handedness | |
| 走力 | speed | |
| バント | bunt | |
| 怪我 | injury_rate | |
| コスト | cost_players経由 | あれば |

各行クリックで`/player-cards/:id`（既存のPlayerCardDetailView）へ遷移。

### 4.3 APIレスポンス設計（詳細）

```ruby
class PlayerDetailSerializer < ActiveModel::Serializer
  attributes :id, :name, :short_name, :number

  has_many :player_cards, serializer: PlayerCardSummarySerializer

  # 新規: カード概要用の軽量シリアライザ
  class PlayerCardSummarySerializer < ActiveModel::Serializer
    attributes :id, :card_type, :handedness, :speed, :bunt,
               :injury_rate, :is_pitcher, :is_relief_only,
               :starter_stamina, :relief_stamina
    belongs_to :card_set
  end
end
```

`players#show`のincludesに`player_cards: :card_set`を追加。

---

## 5. FE修正対象ファイル

### 5.1 削除対象（全体がPlayer旧スキーマ前提で死んでいるコンポーネント）

| ファイル | 理由 |
|----------|------|
| `components/players/DefenseAbilityForm.vue` | Player側の守備値(defense_p等)は全削除済み。player_card_defensesテーブルに移行済み |
| `components/players/FielderAbilityForm.vue` | batting_style_id, batting_skill_ids, biorhythm_ids — 全てPlayer側から削除済み |
| `components/players/PitchingAbilityForm.vue` | starter_stamina, relief_stamina, pitching_skill_ids等 — 全てPlayer側から削除済み。pitching-skillsエンドポイントも削除済み |

### 5.2 大幅改修対象

| ファイル | 修正内容 |
|----------|----------|
| `components/players/PlayerDialog.vue` | サブフォーム3つ(Fielder/Defense/PitchingAbility)の参照削除。is_pitcherチェックボックス削除。defaultItemを{name, number, short_name}に縮小 |
| `components/players/PlayerIdentityForm.vue` | position/throwing_hand/batting_hand/player_type_idsの削除。name/number/short_nameの3項目のみに |
| `views/Players.vue` | positionヘッダー・positionフィルター削除。headers={number, name, short_name, handedness, card_count, actions}に変更 |
| `types/playerDetail.ts` | 大幅縮小: `{id, name, number, short_name}` + player_cards配列（詳細用） |
| `types/player.ts` | player_type_ids削除 |

### 5.3 新規作成

| ファイル | 用途 |
|----------|------|
| `views/PlayerDetailView.vue` | 選手詳細画面（新規）。PlayerCardDetailView.vueのデザイン踏襲 |
| `types/playerCardSummary.ts` | カード概要型（詳細画面のカード一覧テーブル用） |

### 5.4 変更不要

| ファイル | 理由 |
|----------|------|
| `views/PlayerCardDetailView.vue` | カード画面は整備済み |
| `views/PlayerCardsView.vue` | カード一覧は整備済み |
| `views/PlayerAbsenceHistory.vue` | 離脱履歴は独立機能 |
| `components/shared/PlayerDetailSelect.vue` | 選手選択コンポーネント。API依存だが一覧APIが変わっても軽微な影響のみ |

---

## 6. BE修正対象

### 6.1 マイグレーション（要P判断後）

pitching_style_description / special_throwing_c のデータ有無を確認し:
- 全件NULL → マイグレーションで削除
- データあり → PlayerCard側との差異検証 → P判断

### 6.2 Serializer修正

| ファイル | 修正内容 |
|----------|----------|
| `player_serializer.rb` | 維持（一覧用: id, name, number, short_name, handedness） |
| `player_detail_serializer.rb` | pitching_style_description, special_throwing_c, is_pitcher, is_relief_only を削除。has_many :player_cardsを追加 |

### 6.3 Controller修正

| ファイル | 修正内容 |
|----------|----------|
| `players_controller.rb` | player_paramsからspecial_throwing_cを削除（削除漏れカラム対応後）。show actionにplayer_cards includesを追加 |

### 6.4 Model

Player.rb は変更不要（既にクリーン）。

---

## 7. 実装フェーズ案

### Phase A: 削除漏れカラム対応（独立subtask推奨）
1. DBでデータ有無確認
2. P判断を仰ぐ
3. マイグレーション実行
4. BE参照除去（serializer, controller）

### Phase B: BE API整備
1. PlayerDetailSerializer修正（player_cards包含）
2. PlayerCardSummarySerializer新規作成
3. players#showにincludes追加
4. RSpec修正

### Phase C: FE大掃除
1. 死んだコンポーネント3件削除（DefenseAbility/FielderAbility/PitchingAbility）
2. PlayerDialog.vue簡素化（name/number/short_nameのみ）
3. PlayerIdentityForm.vue簡素化
4. Players.vue（一覧）修正
5. types更新

### Phase D: 選手詳細画面新規作成
1. PlayerDetailView.vue新規作成
2. ルーティング追加
3. カード一覧セクション実装
4. 所属チームセクション実装

### 依存関係
```
Phase A → Phase B → Phase C → Phase D
              ↓
         Phase C は Phase B 完了後に並行可能
```

**推定subtask数**: Phase A(1) + Phase B(1) + Phase C(1-2) + Phase D(1-2) = 4〜6 subtask
