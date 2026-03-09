# DB全テーブル カラム監査レポート

**作成**: 軍師マキノ (subtask_509a / cmd_509)
**日付**: 2026-03-09
**対象**: thbigmatome develop ブランチ (commit 132cb33時点)

## サマリ

| 分類 | 件数 |
|------|------|
| 即削除可 (Phase 1) | 23カラム + 5テーブル |
| 要移行 (Phase 2) | 8カラム |
| 要確認 (Phase 3) | 7カラム |
| 問題なし | 残り全て |

---

## 1. Player / PlayerCard 重複カラム分析 (17カラム)

### 現状

- **Player**: 377レコード。キャラクター不変属性のテーブルだが、カードセット毎の能力値カラムが多数混入
- **PlayerCard**: 425レコード。カードセット毎の能力値テーブル（正規化先）

### 重複カラム一覧

| カラム名 | Player NULL率 | PlayerCard NULL率 | コード参照先 | 正規化先 | 判定 |
|----------|:---:|:---:|---|---|---|
| `speed` | 0% (データあり) | 0% (データあり) | PlayerCard (validator/serializer) | **PlayerCard** | Player側を削除 |
| `bunt` | 0% (データあり) | 0% (データあり) | PlayerCard (validator/serializer) | **PlayerCard** | Player側を削除 |
| `injury_rate` | 0% (データあり) | 0% (データあり) | PlayerCard (validator/serializer) | **PlayerCard** | Player側を削除 |
| `is_pitcher` | 0% (データあり) | 0% (データあり) | 両方参照あり ※1 | **PlayerCard** | Player側を移行後削除 |
| `is_relief_only` | 0% (データあり) | 0% (データあり) | 両方参照あり ※2 | **PlayerCard** | Player側を移行後削除 |
| `steal_start` | 0% (データあり) | 0% (データあり) | PlayerCard (validator) | **PlayerCard** | Player側を削除 |
| `steal_end` | 0% (データあり) | 0% (データあり) | PlayerCard (validator) | **PlayerCard** | Player側を削除 |
| `starter_stamina` | **100% NULL** | 76.9% NULL (正常) | PlayerCard (validator) | **PlayerCard** | Player側を即削除 |
| `relief_stamina` | **100% NULL** | 71.5% NULL (正常) | PlayerCard (validator) | **PlayerCard** | Player側を即削除 |
| `batting_style_id` | **100% NULL** | **100% NULL** | なし（未実装） | **PlayerCard** | 両方保留 ※3 |
| `pitching_style_id` | **100% NULL** | **100% NULL** | なし（未実装） | **PlayerCard** | 両方保留 ※3 |
| `catcher_pitching_style_id` | **100% NULL** | **100% NULL** | なし（未実装） | **PlayerCard** | 両方保留 ※3 |
| `pinch_pitching_style_id` | **100% NULL** | **100% NULL** | なし（未実装） | **PlayerCard** | 両方保留 ※3 |
| `batting_style_description` | **100% NULL** | **100% NULL** | なし | **PlayerCard** | Player側を即削除 |
| `pitching_style_description` | **100% NULL** | **100% NULL** | なし | **PlayerCard** | Player側を即削除 |
| `special_defense_c` | **100% NULL** | **100% NULL** | PlayerCard (validator) | **PlayerCard** | Player側を即削除 |
| `special_throwing_c` | **100% NULL** | **100% NULL** | PlayerCard (validator) | **PlayerCard** | Player側を即削除 |

**※1 `is_pitcher`参照箇所**:
- `team.rb:95` — `tm.player.is_pitcher` (チームコスト計算)
- `team_rosters_controller.rb:48` — `tm.player.position == "pitcher"` (positionで代替判定)
- PlayerCard側: `cost_validator.rb:69`, `competition_rosters_controller.rb:109`

**※2 `is_relief_only`参照箇所**:
- `team_rosters_controller.rb:49` — `tm.player.player_cards.first&.is_relief_only` (既にPlayerCard参照に移行済み)
- PlayerCard側: `cost_validator.rb:67`, `competition_rosters_controller.rb:107`

**※3 style系FK**: batting_styles/pitching_stylesマスタはデータ存在(7/10件)だが、PlayerもPlayerCardも未紐付け。将来実装予定。Player側のFKは削除して、PlayerCard側のFKのみ残すべき。

---

## 2. Player固有の全件NULLカラム (Player側のみ・重複以外)

| カラム名 | NULL率 | コード参照 | 判定 |
|----------|:---:|---|---|
| `batting_hand` | **100% NULL** | `player_detail_serializer`, `roster_player_serializer`, `player_card_detail_serializer` (フォールバック) | **要移行** — PlayerCardに`handedness`として存在(60.2%非NULL)。Player.batting_handはenum定義あり |
| `throwing_hand` | **100% NULL** | 同上 | **要移行** — 同上 |
| `position` | **100% NULL** | `team_rosters_controller.rb:48` (pitcher判定), `player_serializer`, `player_detail_serializer` | **要移行** — PlayerCard.card_typeで代替可能 |
| `short_name` | **100% NULL** | `team_rosters_controller.rb:36`, `competition_rosters_controller.rb:93` | **要移行** — 表示用短縮名。データ投入が必要か、Player.name使用に統一 |
| `defense_p` ~ `defense_ss` (10カラム) | **100% NULL** | `player_serializer`, `player_detail_serializer`, `team_memberships_controller` | **要移行** — player_card_defenses テーブルに移行済み(867レコード)。旧カラムはコード参照あり |
| `throwing_c` ~ `throwing_rf` (5カラム) | **100% NULL** | `player_serializer`, `player_detail_serializer`, `team_memberships_controller` | **要移行** — player_card_defenses.throwing に移行済み |

---

## 3. 旧テーブル(Playerレベル関連テーブル) 使用状況

| テーブル | レコード数 | 新テーブル対応 | コード参照 | 判定 |
|----------|:---:|---|---|---|
| `catchers_players` | **0** | `player_card_exclusive_catchers` (4件) | Player model, player_detail_serializer | **Phase 2で廃止** |
| `player_biorhythms` | **0** | PlayerCard.biorhythm_period / biorhythm_date_ranges | Player model, player_detail_serializer | **Phase 2で廃止** |
| `player_batting_skills` | **0** | (player_card_traits/abilities で代替) | Player model, player_detail_serializer | **Phase 2で廃止** |
| `player_pitching_skills` | **0** | (player_card_traits/abilities で代替) | Player model, player_detail_serializer | **Phase 2で廃止** |
| `player_player_types` | **0** | `player_card_player_types` (0件だが構造済み) | Player model, player_serializer, player_detail_serializer | **Phase 2で廃止** |

### マスタテーブル（旧テーブルが参照）

| テーブル | レコード数 | 判定 |
|----------|:---:|---|
| `biorhythms` | 16 | PlayerCard.biorhythm_period移行後に廃止検討。ただし二十四節気マスタとして残す価値あり |
| `batting_skills` | 3 | player_card_abilities移行後に廃止検討 |
| `pitching_skills` | 14 | 同上 |
| `batting_styles` | 7 | PlayerCard.batting_style_id のFKターゲット。**残す** |
| `pitching_styles` | 10 | PlayerCard.pitching_style_id のFKターゲット。**残す** |

---

## 4. PlayerCard 全件NULLカラム

| カラム名 | NULL率 | 設計意図 | 判定 |
|----------|:---:|---|---|
| `batting_style_id` | 100% NULL | 将来実装（マスタデータ紐付け） | **保留** — マスタ(7件)は存在 |
| `pitching_style_id` | 100% NULL | 同上 | **保留** — マスタ(10件)は存在 |
| `catcher_pitching_style_id` | 100% NULL | 専属捕手時の投球特徴 | **保留** |
| `pinch_pitching_style_id` | 100% NULL | 走者あり時の投球特徴 | **保留** |
| `batting_style_description` | 100% NULL | テキスト説明（style_id実装前の代替） | **即削除可** — style_id実装時に不要 |
| `pitching_style_description` | 100% NULL | 同上 | **即削除可** |
| `card_image_path` | 100% NULL | ActiveStorage移行済み(card_image) | **即削除可** |
| `card_label` | 100% NULL | 完走/エイプリル等のラベル | **保留** — IRC連携で使用予定 |
| `irc_display_name` | 100% NULL | IRC表示名 | **保留** — IRC連携で使用予定 |
| `irc_macro_name` | 100% NULL | IRCマクロ起動名 | **保留** — IRC連携で使用予定 |
| `special_defense_c` | 100% NULL | 捕手の特殊守備値 | **保留** — カードインポート未完了 |
| `special_throwing_c` | 100% NULL | 捕手の特殊送球値 | **保留** — 同上 |
| `abilities` (JSONB) | 全件 `{}` | 旧形式（player_card_abilities移行済み） | **即削除可** |

---

## 5. その他のテーブル — 注意点

### game_lineups テーブル (0件)

- `lineup_data` JSONBに試合ラインアップを保存する設計だが、`game_lineup_entries` テーブル（正規化版）が存在
- **両方とも0件**。`game_lineups` は初期設計の名残で、`game_lineup_entries` が正式
- `game_lineups` は **Phase 3で廃止検討** — 使用コードの確認が必要

### league系テーブル (全0件)

- `leagues`, `league_seasons`, `league_games`, `league_memberships`, `league_pool_players`
- 全テーブル0レコード。competitions テーブル経由のリーグ管理に移行済みの可能性
- **Phase 3で廃止検討** — 使用コードの詳細確認が必要

---

## 6. 段階的整理計画

### Phase 1: 即削除可 (リスク低・コード変更なしor最小限)

**Player テーブルから削除 (23カラム)**:

全件NULLかつPlayerCard側にのみバリデーション・コード参照があるもの:

| # | カラム | 根拠 |
|---|--------|------|
| 1 | `starter_stamina` | 100% NULL, PlayerCardにデータ+validator |
| 2 | `relief_stamina` | 同上 |
| 3 | `batting_style_description` | 100% NULL, 未使用 |
| 4 | `pitching_style_description` | 100% NULL, 未使用 |
| 5 | `special_defense_c` | 100% NULL, PlayerCardにvalidator |
| 6 | `special_throwing_c` | 同上 |
| 7-16 | `defense_p` ~ `defense_ss` (10カラム) | 100% NULL, player_card_defenses移行済み |
| 17-21 | `throwing_c` ~ `throwing_rf` (5カラム) | 100% NULL, player_card_defenses.throwing移行済み |

**PlayerCard テーブルから削除 (3カラム)**:

| # | カラム | 根拠 |
|---|--------|------|
| 22 | `batting_style_description` | 100% NULL, style_id実装で不要 |
| 23 | `pitching_style_description` | 同上 |
| 24 | `card_image_path` | 100% NULL, ActiveStorage使用 |
| 25 | `abilities` (JSONB) | 全件`{}`, player_card_abilitiesテーブルに移行済み |

**影響範囲**:
- マイグレーションファイル追加のみ
- Player側defense_*はserializer参照あるが、返す値はすべてNULL
- 削除前にserializerからの参照除去が必要（player_serializer, player_detail_serializer, team_memberships_controller）

**リスク**: 低。全件NULLなので機能影響なし。ただしFEがこれらのフィールドを参照している場合はFE側の修正も必要。

### Phase 2: 要移行 (コード変更必須)

**2a. Player → PlayerCard 参照切り替え (8カラム)**:

| カラム | 現状の参照 | 移行先 | 作業内容 |
|--------|-----------|--------|---------|
| `is_pitcher` | team.rb, team_rosters_controller | PlayerCard.is_pitcher | 参照元をplayer_cards経由に変更 |
| `is_relief_only` | team_rosters_controller (既にPC参照) | PlayerCard.is_relief_only | team.rb等の残存参照を修正 |
| `batting_hand` | serializers (100% NULL) | PlayerCard.handedness (60.2% non-null) | serializerをPlayerCard参照に統一 |
| `throwing_hand` | serializers (100% NULL) | PlayerCard.handedness | 同上 |
| `position` | serializers, team_rosters_controller | PlayerCard.card_type | card_type (pitcher/batter) での判定に変更 |
| `short_name` | serializers, controllers | Player.name (統一) or 新規データ投入 | P判断が必要 |
| `speed` | Player側データあり | PlayerCard (データあり) | Player側削除。参照がないことを確認済み |
| `bunt` | Player側データあり | PlayerCard (データあり) | 同上 |

**2b. 旧テーブル廃止 (5テーブル)**:

| テーブル | 依存コード | 作業内容 |
|----------|-----------|---------|
| `catchers_players` | Player model, serializer | player_card_exclusive_catchers使用に統一 |
| `player_biorhythms` | Player model, serializer | PlayerCard.biorhythm_period使用に統一 |
| `player_batting_skills` | Player model, serializer | player_card_traits/abilities使用に統一 |
| `player_pitching_skills` | Player model, serializer | 同上 |
| `player_player_types` | Player model, serializer | player_card_player_types使用に統一 |

**2c. Player.batting_style_id等のFK削除**:

Player側の4つのstyle系FK (`batting_style_id`, `pitching_style_id`, `catcher_pitching_style_id`, `pinch_pitching_style_id`) は全件NULL。PlayerCard側にも同名FKがあり、そちらが正規化先。Player側のFK・belongs_to・インデックスを削除。

**影響範囲**: Player model, PlayerDetailSerializer, PlayerSerializer, team_memberships_controller, team_rosters_controller, team.rb。FEのplayers APIレスポンス形式が変わる。

**リスク**: 中。serializer出力の変更によりFE側の修正が必要。旧Player詳細画面が影響を受ける。

### Phase 3: 要確認 (P判断が必要)

| 対象 | 確認事項 |
|------|---------|
| `game_lineups` テーブル | `game_lineup_entries`と役割が重複。廃止してよいか |
| league系 5テーブル | competitions系と役割が重複する可能性。将来利用予定があるか |
| `biorhythms` マスタ | PlayerCard.biorhythm_period移行後も二十四節気マスタとして残すか |
| `batting_skills` / `pitching_skills` マスタ | trait_definitions / ability_definitions移行後に残すか |
| `PlayerCard.handedness` フォーマット | 現在39.8% NULL。Player.throwing_hand/batting_hand (enum) からの移行方法 |
| `Player.speed` / `bunt` 等のデータ保持カラム | Player側にもデータがある。PlayerCard側にもある。差異がないことの検証 |
| `Player.steal_start` / `steal_end` / `injury_rate` | 同上 |

---

## 7. 推奨実行順

1. **Phase 1** (即削除可): Player側の全件NULLカラム23個 + PlayerCard側3カラム削除。1〜2cmd。
2. **Phase 2a** (参照切り替え): is_pitcher/is_relief_only/position/handedness のPlayer→PlayerCard切り替え。3〜4cmd。
3. **Phase 2b** (旧テーブル廃止): serializer書き換え + 旧テーブルDROP。2〜3cmd。
4. **Phase 2c** (FK整理): Player側style系FK削除。1cmd。
5. **Phase 3** (要P判断): game_lineups/league系テーブル廃止検討。

**総見積り**: 8〜11cmd相当。Phase 1は即着手可能、Phase 2以降はFE影響確認が必要。
