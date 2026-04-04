# THBIG Dugout 日付概念の定義

**作成**: 2026-03-28 マキノ（gunshi / subtask_784a）
**用途**: LLMがコンテキストとして読む定義文書

---

## 1. ゲーム内日付（チーム単位）

**定義**: 各チームが独立して進行するゲーム内カレンダーの日付。チームごとに異なる速度で進む。

| 項目 | 値 |
|------|-----|
| 粒度 | **チーム単位** — チームAが4月10日でもチームBが4月3日ということがある |
| DBカラム | `seasons.current_date` (date, NOT NULL) — そのチームのシーズンの「今日」 |
| 更新契機 | コミッショナーが手動で日付を進める（`team_seasons_controller#update` → `current_date`更新） |
| 初期値 | シーズン作成時に `schedule.start_date` で設定 |

**関連テーブル:**
- `season_schedules.date` — チームのシーズン日程の各日（ゲーム内日付の1日に対応）
- `season_schedules.date_type` — `game_day`（試合日）/ `interleague_game_day`（交流戦日）/ その他（休息日等）

**注意点:**
- `seasons.current_date` はチーム→シーズン→current_dateの経路でアクセス
- 1チーム1シーズン制（`team_id` uniqueness制約）
- 離脱（player_absences）の回復日計算は `season_schedules` の試合日カウントで行う

---

## 2. リアル日付（グローバル）

**定義**: 実際のカレンダー上の日付。試合がリアルに行われた日。

| 項目 | 値 |
|------|-----|
| 粒度 | **グローバル** — 全チーム共通 |
| DBカラム | `games.real_date` (date) — 試合が実際に行われた日 |
| 用途 | 試合ログの日付特定、時系列表示、統計集計の基準日 |

**関連カラム:**
- `game_records.played_at` (datetime) — 試合の実施日時（より精密なタイムスタンプ）
- `game_records.game_date` (date) — 試合記録に紐づくゲーム内日付（チーム視点での日付）

**注意点:**
- `games.real_date` と `game_records.game_date` は別物。前者はリアル日付、後者はゲーム内日付
- 同一のリアル日（例: 土曜日）に複数チームが試合する場合、各チームのゲーム内日付は異なりうる

---

## 3. シーズン日付（チーム単位）

**定義**: シーズンの開始日と終了日の範囲。シーズンスケジュール（日程表）の期間を定義する。

| 項目 | 値 |
|------|-----|
| 粒度 | **チーム単位**（各チームが独立したシーズンを持つ） |
| DBカラム | `schedules.start_date` / `schedules.end_date` (date) — スケジュールテンプレートの期間 |
| | `schedules.effective_date` (date) — スケジュールの適用開始日 |
| 関連 | `schedule_details.date` + `date_type` — 日程表の各日とその種別 |

**date_type の種別:**
| date_type | 意味 |
|-----------|------|
| `game_day` | 通常の試合日 |
| `interleague_game_day` | 交流戦の試合日 |
| （その他） | 休息日・イベント日等 |

**スケジュールの2層構造:**
1. `schedules` + `schedule_details` — テンプレート（コミッショナーが設計するマスター日程）
2. `season_schedules` — チーム実績（テンプレートからコピーされ、試合結果が記録される）

---

## 4. 試合スケジュール日付（ゲーム単位）

**定義**: 対戦する2チーム間で、それぞれのスケジュール上の日付を記録するためのフィールド。

| 項目 | 値 |
|------|-----|
| 粒度 | **試合単位** — 1試合に対してホーム/ビジターそれぞれの日付 |
| DBカラム | `games.home_schedule_date` (string) — ホームチームのスケジュール上の日付 |
| | `games.visitor_schedule_date` (string) — ビジターチームのスケジュール上の日付 |
| | `games.setting_date` (string) — 試合設定上の日付（IRC上で表示される日付） |
| 用途 | 投手登板管理（`pitcher_appearances_controller`）で使用 |

**注意点:**
- string型（date型ではない） — IRCログから取得した文字列をそのまま格納
- 同一試合でもホーム/ビジターのスケジュール日付が異なる（各チームのゲーム内日付が異なるため）
- `setting_date` はIRC上で「試合ルール」コマンドで表示される日付文字列

---

## 5. コスト有効期間

**定義**: 選手コスト（能力値に基づくチーム編成コスト）の有効期間。

| 項目 | 値 |
|------|-----|
| 粒度 | **グローバル**（全チーム共通のコストテーブル） |
| DBカラム | `costs.start_date` / `costs.end_date` (date) — コストの有効期間 |
| 用途 | end_dateがNULLなら現行コスト。end_dateが設定済みなら過去のコスト |

---

## 6. バイオリズム（二十四節気）

**定義**: ゲーム内日付に連動する選手の調子変動システム。二十四節気をベースにした期間区分。

| 項目 | 値 |
|------|-----|
| 粒度 | **グローバル**（期間定義は共通）× **選手単位**（効果は選手カードごとに異なる） |
| DBカラム | `biorhythms.start_date` / `biorhythms.end_date` (date, NOT NULL) — 節気の期間 |
| | `biorhythms.name` — 節気名（例: 立春、雨水、啓蟄...） |
| | `player_cards.biorhythm_date_ranges` (jsonb) — 選手カードごとの好調/不調期間 |
| | `player_cards.biorhythm_period` — 選手のバイオリズム周期 |
| 状態 | 将来設計あり。現在はDB定義+CRUD APIのみ存在 |

**注意点:**
- 二十四節気は太陽暦ベースだが、ゲーム内ではゲーム内日付に連動する前提
- `player_cards.biorhythm_date_ranges` (jsonb) に選手ごとの好調/不調レンジを格納する設計
- v0.1.0スコープ外（将来のゲームメカニクス拡張）

---

## 7. 離脱期間

**定義**: 選手がチームから一時的に離脱している期間。ゲーム内日付の試合日数でカウント。

| 項目 | 値 |
|------|-----|
| 粒度 | **チーム単位**（シーズンに紐づく） |
| DBカラム | `player_absences.start_date` (date, NOT NULL) — 離脱開始日 |
| | `player_absences.duration` — 離脱期間（試合日数） |
| 回復日計算 | `season_schedules` から `date_type = game_day/interleague_game_day` をカウントして算出 |

---

## 8. 1軍登録日

**定義**: 選手が1軍ロスターに登録された日。

| 項目 | 値 |
|------|-----|
| 粒度 | **チーム単位** |
| DBカラム | `season_rosters.registered_on` (date, NOT NULL) |
| 用途 | 1軍登録状況の管理、CSVエクスポートの基準日 |

---

## 9. 表示フォーマット設定

**定義**: チームごとの日付表示形式の設定。

| 項目 | 値 |
|------|-----|
| DBカラム | `squad_text_settings.date_format` (string, default: "absolute") |
| 値 | `"absolute"` — 実日付表示 / その他の形式（将来拡張） |

---

## 10. 試合日（試合ルールマクロ生成）

**定義**: 試合ルールマクロ（sianボット）が試合開始時に出力する、その試合の「設定上の日付」。試合内の日付依存処理（季節判定・バイオリズム・天候チェック等）の基準となる。

| 項目 | 値 |
|------|-----|
| 粒度 | **試合単位** — 1試合につき1つの設定日付 |
| DBカラム | `games.setting_date` (string) — 試合ルールマクロで出力された日付文字列 |
| 生成元 | sianボットの試合ルールマクロ出力: `設定【8月20日】季節【立秋：リグル】` |
| 用途 | 季節（二十四節気）の判定基準 → バイオリズム計算・天候チェック |

**IRCマクロ出力例:**
```
(sian) (p1) DH【有り】 設定【8月20日】季節【立秋：リグル】
```

**他の日付概念との違い:**

| 比較対象 | 違い |
|----------|------|
| `seasons.current_date`（ゲーム内日付） | チーム単位で進行する管理上の日付。試合日はその日のスケジュールから決まるが、`setting_date` はマクロが出力する試合固有の設定値 |
| `games.real_date`（リアル日付） | 試合が実際に行われた現実の日付。`setting_date` はゲーム内世界の日付 |
| `games.home/visitor_schedule_date` | 各チームのスケジュール上の日付（チーム視点）。`setting_date` は試合そのものに紐づく設定日付 |

**季節判定の仕組み:**
- `setting_date` の日付から二十四節気を特定（例: 8月20日 → 立秋）
- 特定された節気により、その試合で適用されるバイオリズム効果・天候条件が決まる
- `biorhythms` テーブルの `start_date` / `end_date` と照合して該当期間を判定

**注意点:**
- string型（date型ではない） — IRCログからの文字列をそのまま格納（`home/visitor_schedule_date` と同様）
- 現時点でthbig-irc-parserは `設定【】` `季節【】` フィールドを未抽出（DH情報のみ抽出済み）
- バイオリズムシステム自体はv0.1.0スコープ外だが、`setting_date` の格納は実装済み

---

## まとめ: 日付概念の対応表

| 概念 | 粒度 | 主DBカラム | 型 | 進行管理者 |
|------|------|-----------|-----|-----------|
| ゲーム内日付 | チーム | `seasons.current_date` | date | コミッショナー（手動） |
| リアル日付 | グローバル | `games.real_date` | date | 試合実施時に自動 |
| シーズン期間 | チーム | `schedules.start_date/end_date` | date | コミッショナー（設計時） |
| 試合スケジュール日付 | 試合 | `games.home/visitor_schedule_date` | string | IRCログから取得 |
| コスト有効期間 | グローバル | `costs.start_date/end_date` | date | コミッショナー |
| バイオリズム期間 | グローバル | `biorhythms.start_date/end_date` | date | マスターデータ |
| 離脱期間 | チーム | `player_absences.start_date` + `duration` | date+int | ゲーム内イベント |
| 1軍登録日 | チーム | `season_rosters.registered_on` | date | コミッショナー |
| 試合日（設定日付） | 試合 | `games.setting_date` | string | 試合ルールマクロ（sian） |

**最重要の区別**: `games.real_date`（リアル日付）と `game_records.game_date`（ゲーム内日付）は混同しやすいが、完全に独立した概念。各チームのゲーム内日付は独立して進行するため、同じリアル日に行われた試合でもゲーム内日付は異なる。
