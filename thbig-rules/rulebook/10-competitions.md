# 第10章: 大会・シーズンルール

**状態**: 実装済み（cmd_915 / subtask_915b）
**品質基準**: エミュレーターが本章の処理を実装できるレベル

---

## 概要

この章は **Lペナ（IRCリーグ東方BIG野球ペナントレース）の運営ルール**を扱う。
ゲーム本体のルール（東方BIG野球）に対して、Lペナが「上書き」する形で成立する二層構造を理解することが重要。

```
Layer 1: 東方BIG野球（ゲーム本体ルール）← game_rules.yaml の thbig_baseball セクション
Layer 2: Lペナ運営ルール               ← game_rules.yaml の lpena セクション
         ↓
         大会固有ルール（override）
```

関連:
- `game_rules.yaml` の `lpena.season` / `lpena.competition` が値の正本
- 大会固有ルールは大会ごとのYAML定義が最優先

---

## 10.1 シーズン制度

```
SEASON:
  基本構造:
    1チームにつき1シーズンのみ存在する
    シーズンを複数持つことはできない（二重管理禁止）

  出典: game_rules.yaml lpena.season.one_team_one_season = true
```

### 10.1.1 シーズン開始条件

```
SEASON_START_CONDITIONS:
  1. ロスター登録人数: 25人以上（game_rules.yaml lpena.team_composition.roster.min）
  2. チーム総コスト: 200以下（同 team_total_cost.max）
  3. 1軍コスト上限の充足（人数に応じたスライド制）:
     - 28人以上: 120以下
     - 27人: 119以下
     - 26人: 117以下
     - 25人: 114以下
  4. 監督の登録

  例外: 試合が1試合も行われていない場合は最低人数チェックをスキップ
        （シーズン前の一時保存登録を許容）
```

---

## 10.2 クールダウン制度

```
COOLDOWN:
  定義: メンバー変更後10日間は再変更不可

  出典: game_rules.yaml lpena.season.cooldown_days = 10

  目的: 頻繁な入れ替えによる戦術的不公平を防ぐ

  例外: コミッショナーはクールダウン制限なしでメンバー変更できる

COOLDOWN_CHECK:
  INPUT: last_roster_change_date, current_date
  CONDITION: (current_date - last_roster_change_date) >= 10日
  PASS → 変更可能
  FAIL → 変更不可（コミッショナー操作の場合のみ例外）
```

---

## 10.3 大会上書き機構（override_mechanism）

```
OVERRIDE_MECHANISM:
  原則: すべてのルール値は大会ごとに上書き可能
  優先順位: 大会固有ルール > game_rules.yaml のデフォルト値

  上書き可能なルール例:
    - DH制の有無（§4.3）
    - 延長回数上限（§10.5）
    - コスト上限
    - 外の世界枠の数
    - 指定選手の扱い

  実装上の注意:
    大会固有ルールが存在する場合は必ずそちらを参照してから
    game_rules.yaml のデフォルト値を適用する。
    「デフォルト → 大会上書きで変更」の二段階ルックアップが必要。

  出典: game_rules.yaml lpena.competition.override_mechanism
```

---

## 10.4 大会固有ルールの記述方式

```
COMPETITION_RULE_FORMAT:
  各大会は以下の情報を持つ:

  基本情報:
    - competition_id: 大会識別子
    - name: 大会名
    - season_id: 所属シーズン

  上書きルール（override）:
    規定する場合のみ記載。未記載はgame_rules.yamlのデフォルト値を使用。
    例:
      dh_enabled: true/false
      max_innings: 12（延長回数上限）
      tiebreak: true/false（タイブレーク有無）
      outside_world_max: 4

  エントリー制約:
    no_duplicate_entry: true（同一チームの重複エントリー禁止）
    no_duplicate_roster: true（同一大会ロスターへの同一選手カード重複登録禁止）

  出典: game_rules.yaml lpena.competition
```

---

## 10.5 延長戦ルール

```
EXTRA_INNINGS:
  通常（Lペナデフォルト）:
    上限: 12回（12回裏終了で引き分け）
    タイブレーク: なし

  12回引き分け処理:
    IF inning >= 12 AND half == 'bottom' AND outs >= 3:
      is_finished = true
      result = 'draw'

  大会固有の上書き:
    大会ルールでmax_innings / tiebreakを変更可能（§10.3参照）
    一部の大会（大会固有ルールで tiebreak: true を指定）では
    タイブレークを採用する場合がある。
    その場合の方式・開始回は大会ルールに従う。

  ※ Lペナ本戦（ペナントレース）にはタイブレークなし。
     タイブレークは大会固有ルールとしてのみ存在する。
```

---

## 10.6 Lペナ大会ルールとゲームルールの境界

```
LAYER_BOUNDARY:
  ゲームルール（Layer 1）:
    東方BIG野球そのものの判定ロジック
    例: 打席処理・走塁・投手判定・怪我テーブル
    → 大会で変更できない（カード値・ダイス処理は固定）

  Lペナ運営ルール（Layer 2）:
    IRCリーグ独自の制度・制約
    例: コスト制度・外の世界枠・ロスター人数・クールダウン
    → 大会固有ルールで上書き可能

  境界例:
    投手休養ルール: ゲームルールとLペナ運営ルールの**境界上**にある
                    （game_rules.yamlに定義なし、sources/pitcher-rest-rules-analysis.md が正本）
```

---

## 10.7 ルール間の関係

| 関連ルール | 参照先 |
|-----------|--------|
| チーム構成・コスト制度 | 第2章（チームとロスター） |
| DH制 | 第4章 §4.3 |
| 試合終了条件（12回引き分け） | `context/rulebook-restructure-design.md` §1.3 |
| 投手休養ルール（Lペナ境界） | `sources/pitcher-rest-rules-analysis.md` |
| 大会固有上書きの値定義 | `game_rules.yaml` lpena.competition |
| 指定選手特例 | 第9章 §9.2 STEP 1 |
