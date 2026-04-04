# 第3章: シーズンと日程

**状態**: 実装済み
**品質基準**: エミュレーターがシーズン管理・日程生成・大会運営の処理を実装できるレベル

---

## 概要

東方BIG野球のリーグ運営は、シーズン制度・日程管理・クールダウン制度・大会ルール・離脱管理で構成される。これらは試合の公平性と運営の安定性を維持するために設けられている。

本章では、シーズンのライフサイクル・日程構造・メンバー変更制約・大会の上書き機構・離脱管理を定義する。

---

## 3.1 シーズン制度

### 1チーム1シーズン

```
ルール: 1つのチームにつき、存在するシーズンは常に1つだけ
制約:  team_id に対するユニーク制約
```

→ `game_rules.yaml`: `lpena.season.one_team_one_season` (value: true)

複数シーズンの並行管理は行わない。シーズン管理を単純化し、二重管理を防ぐ。

### シーズン作成条件

- チームがロスター制約（第2章）を満たしていること
- 試合未実施時はロスター下限（25人）のバリデーションをスキップ（一時保存を許容）

### シーズンの構成要素

| 要素 | 説明 |
|------|------|
| name | シーズン名 |
| team | 所属チーム（1対1） |
| key_player | キープレイヤー（チームの中心選手） |
| season_schedules | 日程表（1対多） |
| player_absences | 離脱管理（1対多） |

---

## 3.2 日程（SeasonSchedule）

### 日程エントリの構造

1つの日程エントリは1日分の予定を表す。

| フィールド | 型 | 説明 |
|-----------|-----|------|
| date | 日付 | 試合日・休養日等の日付 |
| date_type | 文字列 | 日程の種別（後述） |
| home_away | "home" / "visitor" | ホーム/ビジター |
| opponent_team | チーム | 対戦相手 |
| announced_starter | チームメンバー | 予告先発投手 |
| game_number | 整数 | 試合番号（自動計算可能） |
| designated_hitter_enabled | 真偽値 | DH制の有無 |
| score / opponent_score | 整数 | 試合結果スコア |
| winning_pitcher / losing_pitcher / save_pitcher | 選手 | 勝利/敗戦/セーブ投手 |

### 日程種別（date_type）

| date_type | 意味 |
|-----------|------|
| game_day | 通常試合日 |
| interleague_game_day | インターリーグ（交流戦）試合日 |
| rest_day | 休養日 |
| travel_day | 移動日 |

### 試合番号の計算

```python
def calculated_game_number(schedule_entry):
    """date_typeがgame_day/interleague_game_dayのエントリを数えて試合番号を算出"""
    if schedule_entry.game_number is not None:
        return schedule_entry.game_number
    
    return count(
        s for s in season.schedules
        if s.date_type in ["game_day", "interleague_game_day"]
        and s.date < schedule_entry.date
    ) + 1
```

### 試合結果の判定

```python
def game_result(schedule_entry):
    if schedule_entry.score > schedule_entry.opponent_score:
        return "win"
    elif schedule_entry.score < schedule_entry.opponent_score:
        return "lose"
    else:
        return "draw"
```

---

## 3.3 クールダウン制度

### 基本ルール

```
ルール: メンバー変更（1軍→2軍降格）後、10日間は再変更不可
```

→ `game_rules.yaml`: `lpena.season.cooldown_days` (value: 10)

**例外**: コミッショナーはクールダウン制限なしでメンバー変更可能。

### クールダウンの計算

```python
def calculate_cooldown(team_membership, current_date):
    """直近の降格日から10日間のクールダウンを計算"""
    
    # 直近の2軍登録（降格）を取得
    last_demotion = team_membership.season_rosters
        .where(squad="second")
        .order_by(registered_on="desc")
        .first()
    
    if not last_demotion:
        return None  # 降格歴なし → クールダウンなし
    
    # 降格前の直近の1軍登録（昇格）を確認
    previous_promotion = team_membership.season_rosters
        .where(squad="first")
        .where(registered_on < last_demotion.registered_on)
        .order_by(registered_on="desc")
        .first()
    
    if not previous_promotion:
        return None  # 昇格歴なし → クールダウンなし
    
    cooldown_end = last_demotion.registered_on + 10  # 日
    
    if current_date >= cooldown_end:
        return None  # クールダウン終了済み
    
    # 同日昇格→降格は特殊ケース（same_day_exempt）
    same_day = (previous_promotion.registered_on == last_demotion.registered_on)
    
    return {
        "cooldown_until": cooldown_end,
        "same_day_exempt": same_day,
        "demotion_date": last_demotion.registered_on
    }
```

### 同日例外

同日中に昇格→降格が行われた場合は `same_day_exempt = true` となる。UI表示で区別する用途。

---

## 3.4 大会（Competition）

### 大会エントリー

| ルール | 値 |
|--------|-----|
| 重複エントリー禁止 | 同一チームが同一大会に2回以上エントリー不可 |
| 重複ロスター禁止 | 同一大会ロスターに同一選手カードの重複登録不可 |

→ `game_rules.yaml`: `lpena.competition.no_duplicate_entry`, `no_duplicate_roster`

### ルール値の上書き機構

大会ごとに、`game_rules.yaml`のデフォルト値を上書きできる。

```
優先順: 大会固有ルール > game_rules.yaml デフォルト値
```

→ `game_rules.yaml`: `lpena.competition.override_mechanism`

例えば、特定の大会でコスト上限を変更したり、外の世界枠の制限を緩和することが可能。

### 大会ロスターのバリデーション

大会ロスターは通常のチームロスターとは別に管理される。大会固有のルール値が設定されている場合はそちらで検証する。

```python
def validate_competition_roster(competition_entry):
    """大会ロスターのバリデーション（CostValidatorが担当）"""
    
    first_squad = competition_entry.rosters.where(squad="first")
    
    # 1. 1軍人数チェック（≥ 25人）
    # 2. 1軍コスト上限チェック（段階制）
    # 3. チーム全体コスト上限チェック（≤ 200）
    # → 大会固有ルール値がある場合はそちらを適用
    
    return errors
```

---

## 3.5 離脱管理（PlayerAbsence）

### 離脱の構造

| フィールド | 型 | 説明 |
|-----------|-----|------|
| absence_type | enum | injury（怪我）/ suspension（出場停止）/ reconditioning（調整） |
| start_date | 日付 | 離脱開始日 |
| duration | 整数 | 離脱期間（正の整数） |
| duration_unit | 文字列 | "days"（日数）/ "games"（試合数） |

### 離脱終了日の計算

```python
def effective_end_date(absence):
    """離脱期間の終了日を計算（排他的: この日に復帰可能）"""
    
    if absence.duration_unit == "days":
        return absence.start_date + absence.duration  # 日
    
    elif absence.duration_unit == "games":
        # start_date以降のN試合目の翌日
        game_dates = season.schedules
            .where(date_type in ["game_day", "interleague_game_day"])
            .where(date >= absence.start_date)
            .order_by(date="asc")
            .limit(absence.duration)
            .pluck("date")
        
        if len(game_dates) < absence.duration:
            return None  # 試合数不足
        
        return game_dates[-1] + 1  # 日
```

### 離脱と投手休養の関係

負傷離脱中の投手について:
- 離脱期間は「中○日」カウントに含めない（離脱日は中日数に不算入）
- 離脱除外で中10日以上空けば、疲労なし（カード記載疲労P）で登板可能
- → 詳細は投手休養ルール（第9章）を参照

---

## 3.6 スタメン変更・登録変更のタイミング

### 変更可能なタイミング

| 操作 | タイミング | 制約 |
|------|-----------|------|
| 1軍⇔2軍移動 | 試合日以外（またはクールダウン終了後） | クールダウン10日 |
| スタメン変更 | 試合前 | なし（シーズン中随時） |
| 予告先発の変更 | 試合前 | なし |
| 代打・代走・投手交代 | 試合中 | イニング内で随時 |

### 試合未実施時の特例

試合が1試合も行われていない場合:
- ロスター下限（25人）のバリデーションをスキップ
- チーム構成の一時保存状態を許容

→ `game_rules.yaml`: `lpena.team_composition.roster.exception`

---

## 関連章

- → 第2章: チーム構成ルール（ロスター制約・コスト制度）
- → 第9章: 投手休養ルール（中日数計算・離脱期間の不算入）
- → 第10章: 負傷とけが判定（離脱期間の決定方法）
