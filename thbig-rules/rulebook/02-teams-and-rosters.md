# 第2章: チームとロスター

**状態**: 実装済み
**品質基準**: エミュレーターがチーム編成ルールをバリデーションできるレベル

---

## 概要

東方BIG野球のチーム編成は、ロスター人数制限・コスト制度・外の世界枠・チーム種別・セカンドチーム制約・監督制度の6つのルールで構成される。これらは公平性と世界観の維持を目的としている。

本章では、チーム構成に関わるすべての制約条件とバリデーションロジックを定義する。

---

## 2.1 チーム種別

チーム作成時に選択する。後から変更不可。

### normal（通常チーム）

```yaml
native_series: ["touhou"]
outside_series_condition: "series != touhou"
# → touhou以外のシリーズが「外の世界」枠にカウントされる
```

### hachinai（ハチナイチーム）

```yaml
native_series: ["hachinai", "tamayomi"]
outside_series_condition: "series == touhou"
# → touhouシリーズが「外の世界」枠にカウントされる（反転）
```

### original（オリジナル選手）

```yaml
classification: "always_outside"
# → チーム種別に関わらず常に外の世界枠
```

### 外の世界判定の擬似コード

```python
def is_outside_world(player, team_type):
    if player.series == "original":
        return True  # オリジナルは常に外の世界
    
    native = NATIVE_SERIES[team_type]
    # native = ["touhou"] for normal
    # native = ["hachinai", "tamayomi"] for hachinai
    
    return player.series not in native
```

→ `game_rules.yaml`: `lpena.team_types`

---

## 2.2 ロスター管理

### 登録人数制限

| 制約 | 値 | 理由 |
|------|-----|------|
| 最大 | 50人 | 管理可能な規模の上限 |
| 最小 | 25人 | 1軍登録の最低人数（試合成立条件） |

→ `game_rules.yaml`: `lpena.team_composition.roster` (max: 50, min: 25)

**例外**: 試合が1試合も行われていない場合は下限バリデーションをスキップする（シーズン前の一時保存登録を許容）。

### 1軍・2軍区分

| 区分 | 識別名 | 説明 |
|------|--------|------|
| 1軍 | `first` | 試合に出場可能な選手 |
| 2軍 | `second` | 控え選手（試合出場不可） |

- チームの全選手はいずれかの区分に所属する
- 1軍⇔2軍の移動にはクールダウン制約がある（第3章参照）

---

## 2.3 コスト制限

### チーム全体コスト上限

```
ルール: チームに所属する全選手（除外選手を除く）のコスト合計 ≤ 200
```

→ `game_rules.yaml`: `lpena.team_composition.team_total_cost` (max: 200)

**除外選手**: `excluded_from_team_total = true` の選手（助っ人枠等）はコスト計算対象外。

### コストの種別

選手のコストは、カード種別（投手/野手/リリーフ専任）により異なる場合がある。

```python
def player_cost(player_card, cost_list):
    if player_card.is_relief_only:
        return cost_list.relief_only_cost or cost_list.normal_cost or 0
    elif player_card.is_pitcher:
        return cost_list.pitcher_only_cost or cost_list.normal_cost or 0
    else:
        return cost_list.fielder_only_cost or cost_list.normal_cost or 0
```

### 1軍コスト上限（スライド制）

1軍登録人数に応じてコスト上限が段階的に変動する。

| 1軍人数 | コスト上限 |
|---------|-----------|
| 28人以上 | 120 |
| 27人 | 119 |
| 26人 | 117 |
| 25人 | 114 |
| 24人以下 | 登録不可（シーズン開始不可） |

→ `game_rules.yaml`: `lpena.team_composition.first_squad_cost`

**1軍最低人数**: 25人（これ未満ではシーズン開始ができない）

### バリデーション擬似コード

```python
def validate_cost(team, cost_list_id):
    errors = []
    
    first_squad = team.memberships.where(squad="first")
    second_squad = team.memberships.where(squad="second")
    
    # 1. 1軍人数チェック
    if len(first_squad) < 25:
        errors.append("1軍人数が不足（最低25人必要）")
    
    # 2. 1軍コスト上限（段階制）
    first_cost = sum(player_cost(m) for m in first_squad)
    limit = first_squad_limit_for(len(first_squad))
    if limit and first_cost > limit:
        errors.append(f"1軍コスト超過（{first_cost}/{limit}）")
    
    # 3. チーム全体コスト上限
    total_cost = sum(player_cost(m) for m in included_memberships)
    if total_cost > 200:
        errors.append(f"チーム全体コスト超過（{total_cost}/200）")
    
    return errors
```

---

## 2.4 外の世界枠

### 基本ルール

```
ルール: 1軍に登録できる外の世界選手 ≤ 4人
```

→ `game_rules.yaml`: `lpena.team_composition.outside_world` (max: 4)

### バランスルール

外の世界選手を4人フル活用する場合のみ追加制約が発生する。

```
条件: 外の世界選手が4人のとき
制約: 投手に数える選手1名以上 AND 野手に数える選手1名以上
```

→ `game_rules.yaml`: `lpena.team_composition.outside_world.balance`

**判定基準**: 投手・野手のどちらに数えるかは、契約の種類（契約したコスト区分）で決まる。

| 契約の種類 | 投手に数える | 野手に数える |
|-----------|:-----------:|:-----------:|
| 投手専任・救援専任コスト | ○ | × |
| 野手専任コスト | × | ○ |
| 二刀流コスト（二刀流契約） | ○ | ○ |
| それ以外（通常コストなど） | 選んだカードの主な位置が投手なら○ | 選んだカードの主な位置が内野手・外野手・捕手なら○ |

- 専任契約（投手専任・救援専任・野手専任のコスト）は契約した役だけに数える。救援専任は投手としての専任契約なので投手だけに数える
- 投手・野手のどちらにも数える（都合の良い方として扱う）のは二刀流契約のときだけ。投手カードと野手カードの両方を持つ選手でも、二刀流契約でなければ契約の種類どおりに数える
- 二刀流契約ができる範囲は、二刀流コストを選べる選手と同じ（投手カードと野手カードの両方を持つ選手と、ハチナイの二刀流の選手。Dugout の `Player#available_cost_types`）。ハチナイのカードを持つ背番号 39 以下の選手は、片方のカードしか持たなくても二刀流契約ができる
- それ以外の契約（通常コストなど）では、選んだカードの主な位置（投手 / 内野手 / 外野手 / 捕手）で数える。カードの主な位置は、Dugout では守備位置の 1 つ目で、取込データの position に当たる。カードの種類（`card_type`）や、守備位置に P があるかどうかでは決めない
- 4 人全員が投手だけに数えられる編成と、4 人全員が野手だけに数えられる編成が違反になる

例（2025THBIG・hachinai6.1 のカード）:

- 霧雨魔理沙: 通常契約なら投手（主な位置が投手）。野手専任で契約したら野手。二刀流契約はできない
- 天弓千亦: 通常契約なら野手（救援専任のカードでも主な位置は内野手）
- 涼宮ハルヒ: 通常契約で野手（ハチナイ 6.1 のカードだが背番号 46 で 39 以下でなく、カードも 1 枚なので二刀流契約はできない。カードの主な位置は内野手）。実際に問題になったら裁定を確認する
- ハチナイの二刀流の選手: 契約次第。二刀流契約なら投手・野手のどちらにも数え、専任契約ならその役だけに数える

> 欠落補充（2026-11-02、Operator 裁定）: 旧版は判定を `player_cards` の `card_type` だけで書いており、二刀流と専任契約の扱いが無かった。
> 改訂（2026-11-02、Operator 決定・暫定）: 二刀流をハチナイの二刀流に限り、それ以外は選んだカードの主な位置で数える形に改めた。
> 再改訂（2026-11-02、Operator 決定・暫定）: 両方に数えるのを二刀流契約のときだけに改め、数え方を契約の種類で決める形にした（上の改訂の「ハチナイの二刀流は両方」を置き換え）。リーグの正式な裁定を聞けたら改める。
> 裁定: `context/thbig-bench-rule-adjudications.md`（multi-agent-shogun リポジトリ）AMB-29 節（Operator 裁定 2026-11-02、同日改訂・再改訂・暫定）

### バリデーション擬似コード

```python
# m = 1軍の所属（チームと選手の契約）。selected_cost_type は契約したコスト区分
# （normal_cost / relief_only_cost / pitcher_only_cost / fielder_only_cost / two_way_cost）、
# player_card は選んだカード。two_way_cost を選べるのは二刀流契約ができる選手だけ
# （範囲はコストの検査で決まる。Dugout の Player#available_cost_types）。
#
# primary_position(card): 選んだカードの主な位置（"投手" / "内野手" / "外野手" / "捕手"）。
#   Dugout では守備位置の 1 つ目（取込データの position に当たる）。
#   card_type や守備位置に P があるかでは判定しない

PITCHER_ONLY_COSTS = ("pitcher_only_cost", "relief_only_cost")  # 投手としての専任契約
FIELDER_ONLY_COSTS = ("fielder_only_cost",)                      # 野手としての専任契約
TWO_WAY_COST = "two_way_cost"                                    # 二刀流契約
FIELDER_POSITIONS = ("内野手", "外野手", "捕手")

# 契約の種類で決める（AMB-29 再改訂）。カードの種類や選手の属性だけで両方に数えることはない
def counts_as_pitcher(m):
    if m.selected_cost_type in FIELDER_ONLY_COSTS:
        return False  # 野手専任契約: 野手だけ
    if m.selected_cost_type in PITCHER_ONLY_COSTS:
        return True   # 投手専任・救援専任契約: 投手だけ
    if m.selected_cost_type == TWO_WAY_COST:
        return True   # 二刀流契約: 両方
    # それ以外（通常など）は選んだカードの主な位置で数える
    return m.player_card is not None and primary_position(m.player_card) == "投手"

def counts_as_fielder(m):
    if m.selected_cost_type in PITCHER_ONLY_COSTS:
        return False  # 投手専任・救援専任契約: 投手だけ
    if m.selected_cost_type in FIELDER_ONLY_COSTS:
        return True   # 野手専任契約: 野手だけ
    if m.selected_cost_type == TWO_WAY_COST:
        return True   # 二刀流契約: 両方
    # それ以外（通常など）は選んだカードの主な位置で数える
    return m.player_card is not None and primary_position(m.player_card) in FIELDER_POSITIONS

def validate_outside_world(team):
    native_series = NATIVE_SERIES[team.team_type]
    
    ow_first_squad = [m for m in team.first_squad
                      if m.player.series not in native_series]
    
    # 人数チェック
    if len(ow_first_squad) > 4:
        return "外の世界枠超過"
    
    # バランスチェック（4人ちょうどの場合のみ）
    if len(ow_first_squad) == 4:
        has_pitcher = any(counts_as_pitcher(m) for m in ow_first_squad)
        has_fielder = any(counts_as_fielder(m) for m in ow_first_squad)
        if not (has_pitcher and has_fielder):
            return "外の世界4人使用時は投手1名以上・野手1名以上必須"
    
    return None
```

---

## 2.5 セカンドチーム

### 制約

| ルール | 値 |
|--------|-----|
| 1オーナーの最大チーム数 | 2 |
| 選手排他制約 | 同一選手を両方のチームに登録不可 |

→ `game_rules.yaml`: `lpena.team_composition.second_team`

**例外**: コミッショナーによる排他チェック一時無効化を許可（移籍処理用途）。

---

## 2.6 監督制度

### 基本ルール

| ルール | 値 |
|--------|-----|
| 1チームの監督数 | 1人のみ |
| 1人の監督が管理できるチーム数 | 最大2チーム |

→ `game_rules.yaml`: `lpena.manager`

- 監督（director）は意思決定の責任者
- セカンドチーム制度と連動し、1人が2チームの監督を兼任可能
- 監督とは別にコーチ（coach）を配置可能（補佐役）

---

---

## 2.7 借金特例

負け越しが大きいチームが補強できる特例枠。

### 発動条件

```
負け越し数が5増えるごとに、1人追加補強可能
例: 負け越し5 → 1人補強可、負け越し10 → 2人補強可
```

### 補強の条件

| ルール | 値 |
|--------|-----|
| コスト制限 | **コスト200の枠外**（チーム全体コスト200を超えて獲得可能） |
| ロスター制限 | **50人の枠外**（ロスター50人を超えて獲得可能） |

**Dugout実装**: `excluded_from_team_total = true` フラグで管理（通常の助っ人枠と同じ仕組み）。

### 目的

負け越しが続くチームへの救済措置として、通常の制約を超えた補強を許可する。

---

## 関連章

- → 第1章: カード種別・二刀流（外の世界バランスルールでは、第1章の二刀流選手でも二刀流契約でなければ両方には数えない）
- → 第3章: クールダウン制度（1軍⇔2軍移動の制約）
- → 第3章: 大会ルール・特例選手ルール（大会ごとのルール値上書き機構・特例選手指定）
