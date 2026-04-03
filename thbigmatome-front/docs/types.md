# TypeScript 型定義一覧

最終更新日: 2026-03-10

## 参照ソースファイル一覧

- `src/types/index.ts`
- `src/types/player.ts`
- `src/types/playerDetail.ts`
- `src/types/playerCost.ts`
- `src/types/team.ts`
- `src/types/manager.ts`
- `src/types/game-record.ts`
- `src/types/gameData.ts`
- `src/types/scoreboard.ts`
- `src/types/seasonDetail.ts`
- `src/types/seasonSchedule.ts`
- `src/types/scheduleDetail.ts`
- `src/types/scheduleList.ts`
- `src/types/rosterPlayer.ts`
- `src/types/playerAbsence.ts`
- `src/types/cost.ts`
- `src/types/costList.ts`
- `src/types/costPlayer.ts`
- `src/types/skill.ts`
- `src/types/battingSkill.ts`
- `src/types/pitchingSkill.ts`
- `src/types/battingStyle.ts`
- `src/types/pitchingStyle.ts`
- `src/types/biorhythm.ts`
- `src/types/playerType.ts`
- `src/types/startingMember.ts`
- `src/types/pagination.ts`

---

## 選手関連

### `Player` (`src/types/player.ts`)

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `id` | `number` | ✓ | 選手ID |
| `name` | `string` | ✓ | 選手名 |
| `short_name` | `string` | ✓ | 略称 |
| `number` | `string` | ✓ | 背番号 |
| `handedness` | `string \| null` | ✓ | 投打（例: `right_throw/right_bat`） |
| `cost_players` | `PlayerCost[]` | ✓ | コスト表別コスト情報 |

**使用箇所**: `StartingMemberDialog.vue`, `PlayerSelect.vue`, `useLineupTemplate.ts`（`RosterPlayer`経由で間接的に）

**BEシリアライザ対応**: `PlayerSerializer`（BE）

---

### `PlayerDetail` (`src/types/playerDetail.ts`)

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `id` | `number \| null` | ✓ | 選手ID（新規作成時はnull） |
| `name` | `string` | ✓ | 選手名 |
| `number` | `string \| null` | ✓ | 背番号 |
| `short_name` | `string \| null` | ✓ | 略称 |
| `player_cards` | `PlayerCardSummary[] \| undefined` | - | 選手カード一覧 |

**使用箇所**: `PlayerDialog.vue`, `PlayerIdentityForm.vue`, `PlayerDetailSelect.vue`, `PlayersView`

**BEシリアライザ対応**: `PlayerDetailSerializer`

---

### `PlayerCardSummary` (`src/types/playerDetail.ts`)

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `id` | `number` | ✓ | カードID |
| `card_type` | `string` | ✓ | 種別（pitcher/batter） |
| `handedness` | `string \| null` | ✓ | 投打 |
| `speed` | `number \| null` | ✓ | 走力 |
| `bunt` | `number \| null` | ✓ | バント値 |
| `injury_rate` | `number \| null` | ✓ | 故障率 |
| `is_pitcher` | `boolean` | ✓ | 投手フラグ |
| `is_relief_only` | `boolean` | ✓ | リリーフ専門フラグ |
| `starter_stamina` | `number \| null` | ✓ | 先発スタミナ |
| `relief_stamina` | `number \| null` | ✓ | リリーフスタミナ |
| `card_set` | `{ id: number; name: string }` | ✓ | カードセット情報 |

**使用箇所**: `PlayerDetail.player_cards`として`PlayerDetailView.vue`

---

### `PlayerCost` (`src/types/playerCost.ts`)

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `id` | `number` | ✓ | レコードID |
| `cost_id` | `number` | ✓ | コスト表ID |
| `player_id` | `number` | ✓ | 選手ID |
| `normal_cost` | `number \| null` | ✓ | 通常コスト |
| `relief_only_cost` | `number \| null` | ✓ | リリーフ専門コスト |
| `pitcher_only_cost` | `number \| null` | ✓ | 投手専門コスト |
| `fielder_only_cost` | `number \| null` | ✓ | 野手専門コスト |
| `two_way_cost` | `number \| null` | ✓ | 二刀流コスト |

**使用箇所**: `Player.cost_players`として参照。`CostAssignment.vue`

**BEシリアライザ対応**: `PlayerCostSerializer`

---

### `RosterPlayer` (`src/types/rosterPlayer.ts`)

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `team_membership_id` | `number` | ✓ | チーム所属ID |
| `player_id` | `number` | ✓ | 選手ID |
| `number` | `string` | ✓ | 背番号 |
| `player_name` | `string` | ✓ | 選手名 |
| `squad` | `'first' \| 'second'` | ✓ | 軍（1軍/2軍） |
| `cost` | `number` | ✓ | 現在のコスト値 |
| `selected_cost_type` | `string` | ✓ | 適用中のコスト種別 |
| `handedness` | `string \| null` | ✓ | 投打 |
| `player_types` | `string[]` | ✓ | プレイヤータイプ一覧 |
| `cooldown_until` | `string \| undefined` | - | 昇格クールダウン終了日 |
| `same_day_exempt` | `boolean \| undefined` | - | 当日昇格免除フラグ |
| `is_outside_world` | `boolean \| undefined` | - | 外の世界キャラフラグ |
| `is_starter_pitcher` | `boolean \| undefined` | - | 先発投手フラグ |
| `is_relief_only` | `boolean \| undefined` | - | リリーフ専門フラグ |
| `is_absent` | `boolean \| undefined` | - | 離脱中フラグ |
| `absence_info` | `AbsenceInfo \| null \| undefined` | - | 離脱情報 |

**使用箇所**: `SeasonRosterTab.vue`, `PromotionCooldownInfo.vue`, `useLineupTemplate.ts`, `useSquadTextGenerator.ts`, `SquadTextGenerator.vue`, `LineupTemplateEditor.vue`

**BEシリアライザ対応**: `RosterPlayerSerializer`

---

### `AbsenceInfo` (`src/types/rosterPlayer.ts`)

`RosterPlayer.absence_info`として内包される型。

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `absence_type` | `'injury' \| 'suspension' \| 'reconditioning'` | ✓ | 離脱種別 |
| `reason` | `string \| null` | ✓ | 離脱理由 |
| `effective_end_date` | `string \| null` | ✓ | 実効終了日 |
| `remaining_days` | `number \| null` | ✓ | 残日数 |
| `duration_unit` | `'days' \| 'games'` | ✓ | 日数単位 |

---

### `PlayerAbsence` (`src/types/playerAbsence.ts`)

離脱記録のDBモデル対応型。`AbsenceInfo`はロスタービュー用、こちらはCRUD用。

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `id` | `number` | ✓ | レコードID |
| `team_membership_id` | `number` | ✓ | チーム所属ID |
| `season_id` | `number` | ✓ | シーズンID |
| `absence_type` | `'injury' \| 'suspension' \| 'reconditioning'` | ✓ | 離脱種別 |
| `reason` | `string \| null` | ✓ | 理由 |
| `start_date` | `string` | ✓ | 開始日 |
| `duration` | `number` | ✓ | 期間 |
| `duration_unit` | `'days' \| 'games'` | ✓ | 単位 |
| `effective_end_date` | `string \| null` | ✓ | 実効終了日 |
| `created_at` | `string` | ✓ | 作成日時 |
| `updated_at` | `string` | ✓ | 更新日時 |
| `player_name` | `string` | ✓ | 選手名（表示用） |

**使用箇所**: `AbsenceInfo.vue`, `PlayerAbsenceFormDialog.vue`, `SeasonAbsenceTab.vue`

**BEシリアライザ対応**: `PlayerAbsenceSerializer`

---

## チーム・スタッフ関連

### `Team` (`src/types/team.ts`)

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `id` | `number` | ✓ | チームID |
| `name` | `string` | ✓ | チーム名 |
| `short_name` | `string` | ✓ | 略称 |
| `is_active` | `boolean` | ✓ | アクティブフラグ |
| `has_season` | `boolean` | ✓ | シーズン有無 |
| `user_id` | `number \| null \| undefined` | - | 所有ユーザーID |
| `director` | `Manager \| undefined` | - | 監督 |
| `coaches` | `Manager[] \| undefined` | - | コーチ一覧 |

**使用箇所**: `TeamDialog.vue`, `TeamSelect.vue`, `SeasonInitializationDialog.vue`, `TeamList.vue`

**BEシリアライザ対応**: `TeamSerializer`

---

### `Manager` (`src/types/manager.ts`)

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `id` | `number` | ✓ | 監督/コーチID |
| `name` | `string` | ✓ | 名前 |
| `short_name` | `string \| null \| undefined` | - | 略称 |
| `irc_name` | `string \| null \| undefined` | - | IRC名 |
| `user_id` | `string \| null \| undefined` | - | ユーザーID |
| `teams` | `Team[] \| undefined` | - | 所属チーム一覧 |
| `role` | `'director' \| 'coach'` | ✓ | 役割 |

**使用箇所**: `TeamDialog.vue`, `ManagerDialog.vue`, `ManagerList.vue`

**BEシリアライザ対応**: `ManagerSerializer`

---

## 試合記録関連

### `AtBatRecord` (`src/types/game-record.ts`)

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `id` | `number` | ✓ | 打席ID |
| `game_record_id` | `number` | ✓ | 試合記録ID |
| `inning` | `number` | ✓ | イニング |
| `half` | `'top' \| 'bottom'` | ✓ | 表/裏 |
| `ab_num` | `number` | ✓ | 打席番号 |
| `batter_name` | `string` | ✓ | 打者名 |
| `pitcher_name` | `string` | ✓ | 投手名 |
| `result_code` | `string \| null` | ✓ | 結果コード |
| `runs_scored` | `number \| null` | ✓ | 得点 |
| `runners_before` | `unknown` | ✓ | 打席前走者 |
| `runners_after` | `unknown` | ✓ | 打席後走者 |
| `outs_before` | `number \| null` | ✓ | 打席前アウト数 |
| `outs_after` | `number \| null` | ✓ | 打席後アウト数 |
| `strategy` | `string \| null` | ✓ | 作戦 |
| `play_description` | `string \| null` | ✓ | 原文テキスト |
| `is_modified` | `boolean` | ✓ | 修正済みフラグ |
| `is_reviewed` | `boolean` | ✓ | 確認済みフラグ |
| `review_notes` | `string \| null` | ✓ | レビューメモ |
| `modified_fields` | `unknown` | ✓ | 修正フィールド |
| `discrepancies` | `Discrepancy[]` | ✓ | 差異一覧 |
| `source_events` | `SourceEvent[] \| null` | ✓ | ソースイベント列 |

**使用箇所**: `AtBatCard.vue`, `GameRecordDetailView.vue`

**BEシリアライザ対応**: `AtBatRecordSerializer`

---

### `SourceEvent` (`src/types/game-record.ts`)

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `seq` | `number \| undefined` | - | シーケンス番号 |
| `type` | `'declaration' \| 'dice' \| 'auto' \| 'skip'` | ✓ | イベント種別 |
| `dice_type` | `string \| undefined` | - | ダイス種別 |
| `action` | `string \| undefined` | - | アクション |
| `text` | `string \| undefined` | - | テキスト |
| `roll` | `number \| number[] \| undefined` | - | ダイス出目 |
| `result` | `string \| undefined` | - | 結果 |
| `reason` | `string \| undefined` | - | スキップ理由 |
| `from` | `string \| undefined` | - | 起点（走者移動等） |
| `to` | `string \| undefined` | - | 終点 |
| `[key]` | `unknown` | - | 拡張フィールド |

**使用箇所**: `AtBatCard.vue`の表示フィルタリング

---

### `Discrepancy` (`src/types/game-record.ts`)

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `field` | `string` | ✓ | フィールド名 |
| `text_value` | `unknown` | ✓ | テキスト解析値 |
| `gsm_value` | `unknown` | ✓ | GSM計算値 |
| `cause` | `'parser_misread' \| 'human_error' \| 'gsm_limitation' \| 'ambiguous' \| 'unknown'` | ✓ | 原因種別 |
| `resolution` | `'gsm' \| 'text' \| 'manual' \| null` | ✓ | 解決策 |
| `resolution_value` | `unknown \| undefined` | - | 解決値 |
| `note` | `string \| undefined` | - | 備考 |

---

### `PlayerCard` (`src/types/game-record.ts`)

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `id` | `number` | ✓ | カードID |
| `card_set_id` | `number` | ✓ | カードセットID |
| `player_id` | `number` | ✓ | 選手ID |
| `card_type` | `'pitcher' \| 'batter'` | ✓ | 種別 |
| `player_name` | `string` | ✓ | 選手名 |
| `player_number` | `string` | ✓ | 背番号 |
| `card_set_name` | `string` | ✓ | カードセット名 |
| `speed` | `number` | ✓ | 走力 |
| `steal_start` | `number` | ✓ | 盗塁開始値 |
| `steal_end` | `number` | ✓ | 盗塁終了値 |
| `injury_rate` | `number` | ✓ | 故障率 |
| `cost` | `number \| null \| undefined` | - | コスト |
| `defenses` | `Defense[] \| undefined` | - | 守備情報 |
| `unique_traits` | `string \| null \| undefined` | - | 特殊能力テキスト |
| `image_url` | `string \| null \| undefined` | - | カード画像URL |

**使用箇所**: `PlayerCardItem.vue`, `PlayerCardsView.vue`, `PlayerCardDetailView.vue`

**BEシリアライザ対応**: `PlayerCardSerializer`

---

### `Defense` (`src/types/game-record.ts`)

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `id` | `number \| undefined` | - | レコードID |
| `position` | `string` | ✓ | ポジション（例: `C`, `1B`） |
| `range_value` | `number \| undefined` | - | レンジ値 |
| `error_rank` | `string \| undefined` | - | エラーランク |
| `throwing` | `string \| null \| undefined` | - | 肩 |

---

### 試合前情報関連（`src/types/game-record.ts`）

#### `LineupEntry`（game-record）

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `order` | `number` | ✓ | 打順 |
| `position` | `string` | ✓ | ポジション |
| `name` | `string` | ✓ | 選手名 |

#### `BenchEntry`

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `name` | `string` | ✓ | 選手名 |
| `role` | `'pitcher' \| 'fielder' \| 'unknown'` | ✓ | 役割 |

#### `StarterInfo`

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `name` | `string` | ✓ | 投手名 |
| `jersey` | `number \| undefined` | - | 背番号 |
| `rest_days` | `number \| undefined` | - | 休養日数 |
| `fatigue` | `number \| undefined` | - | 疲労度 |
| `wins` | `number \| undefined` | - | 勝利数 |
| `losses` | `number \| undefined` | - | 敗北数 |
| `era` | `number \| undefined` | - | 防御率 |
| `appearances` | `number \| undefined` | - | 登板数 |

#### `InjuryCheck`

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `player` | `string` | ✓ | 選手名 |
| `roll` | `number` | ✓ | ダイス結果 |
| `injured` | `boolean` | ✓ | 故障フラグ |
| `injury_days` | `number \| undefined` | - | 故障日数 |
| `injury_level` | `number \| undefined` | - | 故障レベル |
| `note` | `string \| undefined` | - | 備考 |

#### `PregameInfo`

試合前情報（対戦表・ラインナップ・先発情報等）。

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `venue` | `string \| null` | ✓ | 球場名 |
| `venue_code_1112` | `string \| null` | ✓ | 球場コード（11/12版） |
| `venue_code_1314` | `string \| null` | ✓ | 球場コード（13/14版） |
| `dh_enabled` | `boolean \| null` | ✓ | DH制フラグ |
| `home_team` | `string \| null` | ✓ | ホームチーム名 |
| `visitor_team` | `string \| null` | ✓ | ビジターチーム名 |
| `rain_canceled` | `boolean` | ✓ | 雨天中止フラグ |
| `home_lineup` | `LineupEntry[]` | ✓ | ホームラインナップ |
| `visitor_lineup` | `LineupEntry[]` | ✓ | ビジターラインナップ |
| `home_bench` | `BenchEntry[]` | ✓ | ホームベンチ |
| `visitor_bench` | `BenchEntry[]` | ✓ | ビジターベンチ |
| `home_starter` | `string \| null` | ✓ | ホーム先発投手名 |
| `visitor_starter` | `string \| null` | ✓ | ビジター先発投手名 |
| `home_starter_info` | `StarterInfo \| null` | ✓ | ホーム先発詳細 |
| `visitor_starter_info` | `StarterInfo \| null` | ✓ | ビジター先発詳細 |
| `injury_check_result` | `InjuryCheck \| null` | ✓ | 故障チェック結果 |

**使用箇所**: `GameRecordDetailView.vue`

---

## 試合データ関連

### `GameData` (`src/types/gameData.ts`)

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `team_id` | `number` | ✓ | チームID |
| `team_name` | `string` | ✓ | チーム名 |
| `season_id` | `number` | ✓ | シーズンID |
| `game_date` | `string` | ✓ | 試合日 |
| `game_number` | `number` | ✓ | 試合番号 |
| `announced_starter_id` | `number \| null` | ✓ | 先発投手ID |
| `stadium` | `string` | ✓ | 球場 |
| `home_away` | `'home' \| 'visitor' \| null` | ✓ | ホーム/ビジター |
| `designated_hitter_enabled` | `boolean \| null` | ✓ | DH制 |
| `opponent_team_id` | `number \| null` | ✓ | 対戦相手ID |
| `opponent_team_name` | `string` | ✓ | 対戦相手名 |
| `score` | `number \| null` | ✓ | 自チームスコア |
| `opponent_score` | `number \| null` | ✓ | 相手チームスコア |
| `winning_pitcher_id` | `number \| null` | ✓ | 勝利投手ID |
| `losing_pitcher_id` | `number \| null` | ✓ | 敗戦投手ID |
| `save_pitcher_id` | `number \| null` | ✓ | セーブ投手ID |
| `scoreboard` | `Scoreboard \| null` | ✓ | スコアボード |
| `starting_lineup` | `LineupItem[] \| null` | ✓ | スターティングラインナップ |

**使用箇所**: `GameResult.vue`, `GameDetailView.vue`, `GameLineupView.vue`

**BEシリアライザ対応**: `GameDataSerializer`

---

### `LineupItem` (`src/types/gameData.ts`)

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `player_id` | `number` | ✓ | 選手ID |
| `position` | `string` | ✓ | ポジション |
| `order` | `number` | ✓ | 打順 |

---

### `Scoreboard` (`src/types/scoreboard.ts`)

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `home` | `(number \| null)[]` | ✓ | ホームイニング別得点 |
| `away` | `(number \| null)[]` | ✓ | アウェイイニング別得点 |

**使用箇所**: `Scoreboard.vue`, `GameData.scoreboard`

---

## シーズン・スケジュール関連

### `SeasonDetail` (`src/types/seasonDetail.ts`)

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `id` | `number` | ✓ | シーズンID |
| `name` | `string` | ✓ | シーズン名 |
| `current_date` | `string` | ✓ | 現在日付 |
| `start_date` | `string` | ✓ | 開始日 |
| `end_date` | `string` | ✓ | 終了日 |
| `season_schedules` | `SeasonSchedule[]` | ✓ | スケジュール一覧 |

**使用箇所**: `SeasonAbsenceTab.vue`, `SeasonPortal.vue`

**BEシリアライザ対応**: `SeasonDetailSerializer`

---

### `SeasonSchedule` (`src/types/seasonSchedule.ts`)

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `id` | `number` | ✓ | スケジュールID |
| `date` | `string` | ✓ | 日付 |
| `date_type` | `string` | ✓ | 日付種別（試合/休日等） |
| `announced_starter` | `{ id: number; name: string } \| undefined` | - | 先発予告情報 |
| `game_result` | `{ opponent_short_name: string; score: string; result: 'win' \| 'lose' \| 'draw' } \| undefined` | - | 試合結果 |

**使用箇所**: `SeasonDetail.season_schedules`として`SeasonPortal.vue`

---

### `ScheduleList` (`src/types/scheduleList.ts`)

スケジュールマスタ（シーズン初期化時に選択するもの）。

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `id` | `number \| null \| undefined` | ✓ | スケジュールID |
| `name` | `string` | ✓ | スケジュール名 |
| `start_date` | `Date \| null` | ✓ | 開始日 |
| `end_date` | `Date \| null` | ✓ | 終了日 |
| `effective_date` | `Date \| null` | ✓ | 適用日 |

**使用箇所**: `SeasonInitializationDialog.vue`, `ScheduleSettings.vue`

---

### `ScheduleDetail` (`src/types/scheduleDetail.ts`)

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `schedule_id` | `number` | ✓ | スケジュールID |
| `date` | `string` | ✓ | 日付 |
| `date_type` | `string` | ✓ | 日付種別 |

**使用箇所**: `ScheduleDetailEditor.vue`

---

### `Schedule` (`src/types/index.ts`)

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `id` | `number \| null` | ✓ | スケジュールID |
| `name` | `string` | ✓ | 名称 |
| `start_date` | `string` | ✓ | 開始日 |
| `end_date` | `string` | ✓ | 終了日 |

---

### `StartingMember` (`src/types/startingMember.ts`)

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `battingOrder` | `number` | ✓ | 打順 |
| `position` | `string \| null` | ✓ | ポジション |
| `player` | `Player \| null` | ✓ | 選手情報 |

---

## コスト関連

### `Cost` (`src/types/cost.ts`)

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `id` | `number` | ✓ | コスト表ID |
| `name` | `string` | ✓ | コスト表名 |
| `start_date` | `string` | ✓ | 有効開始日 |
| `end_date` | `string` | ✓ | 有効終了日 |
| `normal_cost` | `number \| null` | ✓ | 通常コスト |
| `relief_only_cost` | `number \| null` | ✓ | リリーフ専門コスト |
| `pitcher_only_cost` | `number \| null` | ✓ | 投手専門コスト |
| `fielder_only_cost` | `number \| null` | ✓ | 野手専門コスト |
| `two_way_cost` | `number \| null` | ✓ | 二刀流コスト |

---

### `CostList` (`src/types/costList.ts`)

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `id` | `number` | ✓ | コスト表ID |
| `name` | `string` | ✓ | コスト表名 |
| `start_date` | `string \| null` | ✓ | 有効開始日 |
| `end_date` | `string \| null` | ✓ | 有効終了日 |

**使用箇所**: `CostListSelect.vue`, `CostSettings.vue`

---

### `CostPlayer` (`src/types/costPlayer.ts`)

コスト表別選手コスト（CostAssignment画面用）。

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `id` | `number` | ✓ | レコードID |
| `number` | `string \| null` | ✓ | 背番号 |
| `name` | `string` | ✓ | 選手名 |
| `player_types` | `{ id: number; name: string }[]` | ✓ | プレイヤータイプ一覧 |
| `normal_cost` | `number \| null` | ✓ | 通常コスト |
| `relief_only_cost` | `number \| null` | ✓ | リリーフ専門コスト |
| `pitcher_only_cost` | `number \| null` | ✓ | 投手専門コスト |
| `fielder_only_cost` | `number \| null` | ✓ | 野手専門コスト |
| `two_way_cost` | `number \| null` | ✓ | 二刀流コスト |

**使用箇所**: `CostAssignment.vue`

---

## マスタ関連

### `BattingSkill` (`src/types/battingSkill.ts`)

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `id` | `number` | ✓ | スキルID |
| `name` | `string` | ✓ | スキル名 |
| `description` | `string \| null` | ✓ | 説明 |
| `skill_type` | `SkillType` | ✓ | 種別（positive/negative/neutral） |

**使用箇所**: `BattingSkillSettings.vue`, `BattingSkillDialog.vue`

**BEシリアライザ対応**: `BattingSkillSerializer`

---

### `PitchingSkill` (`src/types/pitchingSkill.ts`)

`BattingSkill`と同構造（投手スキル用）。

**使用箇所**: `PitchingSkillSettings.vue`, `PitchingSkillDialog.vue`

---

### `BattingStyle` (`src/types/battingStyle.ts`)

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `id` | `number` | ✓ | ID |
| `name` | `string` | ✓ | 名前 |
| `description` | `string \| null` | ✓ | 説明 |

**使用箇所**: `BattingStyleSettings.vue`, `BattingStyleDialog.vue`

---

### `PitchingStyle` (`src/types/pitchingStyle.ts`)

`BattingStyle`と同構造（投球スタイル用）。

**使用箇所**: `PitchingStyleSettings.vue`, `PitchingStyleDialog.vue`

---

### `Biorhythm` (`src/types/biorhythm.ts`)

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `id` | `number` | ✓ | ID |
| `name` | `string` | ✓ | 名前 |
| `start_date` | `string` | ✓ | 開始日（YYYY-MM-DD） |
| `end_date` | `string` | ✓ | 終了日（YYYY-MM-DD） |

**使用箇所**: `BiorhythmSettings.vue`, `BiorhythmDialog.vue`

---

### `PlayerType` (`src/types/playerType.ts`)

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `id` | `number` | ✓ | ID |
| `name` | `string` | ✓ | 名前 |
| `description` | `string \| null` | ✓ | 説明 |
| `category` | `'touhou' \| 'outside_world' \| 'cost_regulation' \| null` | ✓ | カテゴリ |

**使用箇所**: `PlayerTypeSettings.vue`, `PlayerTypeDialog.vue`

---

### `SkillType` (`src/types/skill.ts`)

```typescript
type SkillType = 'positive' | 'negative' | 'neutral'
```

**使用箇所**: `BattingSkill`, `PitchingSkill`の`skill_type`フィールド

---

## ユーティリティ関連

### `PaginationMeta` (`src/types/pagination.ts`)

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `total_count` | `number` | ✓ | 総件数 |
| `per_page` | `number` | ✓ | 1ページあたり件数 |
| `current_page` | `number` | ✓ | 現在ページ |
| `total_pages` | `number` | ✓ | 総ページ数 |

### `PaginatedResponse<T>` (`src/types/pagination.ts`)

| 属性 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `data` | `T[]` | ✓ | データ一覧 |
| `meta` | `PaginationMeta` | ✓ | ページネーションメタ |

**使用箇所**: ページネーション対応のAPIレスポンス全般（選手一覧等）
