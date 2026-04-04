# 第8章: 投手管理

**品質基準**: エミュレーターが本章の処理を実装できるレベル
**出典**: sources/pitcher-rest-rules-analysis.md（正本）、game_rules.yaml、Dugout pitcher_game_state.rb

---

## 8.0 概要

投手管理は「試合中の疲労」と「試合間の休養」の2層構造を持つ。

| 層 | フェーズ | 内容 |
|----|---------|------|
| 試合中 | Phase4_InGame | 疲労P超過による投球番号劣化・KO判定 |
| 試合間 | Phase5_PostGame〜Phase3_GameSetup | 中日数に基づく疲労P計算・負傷チェック |

**ゲームルールとLペナの境界**:
- 試合中の疲労（疲労P・KO条件）: 東方BIG野球本体のルール（thbig_baseball層）
- 休養計算・連戦制限: Lペナ（IRCリーグ）の大会運営ルール（lpena層）

---

## 8.1 投手区分の判定ロジック

投手の役割（先発/リリーフ/スラッシュ）は以下の優先順位で判定する。

```
INPUT: player_card, pitching_history

STEP 1: 直近登板履歴が存在するか確認
  IF 直近登板あり:
    → 直近登板の role（starter / reliever / opener）を使用
    → 以降の処理はそのroleに基づく

STEP 2: 履歴なし → カード属性で判定
  IF is_relief_only == true:
    → リリーフ
  ELSE:
    → 先発

スラッシュ選手の判定:
  starter_stamina IS NOT NULL
  AND relief_stamina IS NOT NULL
  AND is_relief_only == false
  → スラッシュ（先発・リリーフ兼任可能）

OUTPUT: role = "starter" | "reliever" | "opener"
```

---

## 8.2 試合中の疲労判定

### 8.2.1 基本疲労ルール

```
INNING_FATIGUE_CHECK（各イニング終了時 or 交代時）:
  INPUT: pitcher.stamina, innings_pitched, runs_allowed

  # 基本: 投球イニング > 疲労P値で疲労状態
  is_fatigued = (innings_pitched > pitcher.stamina)

  # 5イニング以上無失点特例
  IF innings_pitched >= 5 AND runs_allowed == 0:
    is_fatigued = false  # 疲労状態も解除
    # 例外1: 10回以降はランナーを出すと疲労
    # 例外2: 11回以降は最初から疲労状態

  # 疲労P猶予
  IF 前イニングで疲労P回数を投げた:
    敬遠以外のランナーを出すまで is_fatigued = false

OUTPUT: is_fatigued (bool)
```

### 8.2.2 疲労状態の効果

疲労状態（is_fatigued=true）の投手は、投球番号決定時に「*マーク付き」行の投球番号が劣化する。

```
FATIGUE_DEGRADATION（*マーク付き行に限る）:
  2 → 1
  3 → 2
  5 → 4
  ※ 1と4には*マークが付かないため劣化なし
```

### 8.2.3 KO判定

```
KO_CALCULATION:
  INPUT:
    role: str                # "starter"
    innings_pitched: float   # 例: 4.67（4回2/3）
    game_result: str         # "lose"
    pitchers_in_game: int    # この試合での同チーム投手総数
    decision: str            # "L"（負け投手）

  KO_THRESHOLD = 5  # game_rules.yaml: thbig_baseball.game.ko_innings_threshold.value

  ko = (
    role == "starter"
    AND innings_pitched > 0
    AND innings_pitched < KO_THRESHOLD  # 4回2/3以下
    AND pitchers_in_game > 1            # 後続投手あり
    AND game_result == "lose"
    AND decision == "L"                 # 負け投手
  )

OUTPUT: result_category = "ko" | "normal" | "long_loss" | "no_game"

result_category判定順序（Dugout: PitcherGameState#calculate_result_category）:
  1. game_result == "no_game" → "no_game"
  2. role != "starter" → "normal"
  3. KO条件に該当 → "ko"
  4. 長イニング敗戦条件に該当 → "long_loss"
  5. それ以外 → "normal"

長イニング敗戦条件:
  game_result == "lose"
  AND innings_pitched > pitcher.stamina + 1  # 疲労P + 1イニング超過
```

---

## 8.3 投手休養ルール（試合間）

### 8.3.1 先発→先発

**前提**: 中2日以内は登板不可（疲労P計算以前に登録不可）

#### 通常（result_category = "normal"）

| 中日数 | 疲労P | 負傷チェック |
|--------|-------|------------|
| 中2日以内 | **登板不可** | — |
| 中3日 | 0 | **発動** |
| 中4日 | −3 | 2回連続で**発動** |
| 中5日 | −1 | なし |
| 中6日以上 | カード記載疲労P | なし |

#### KO・ノーゲーム時（result_category = "ko" または "no_game"）

| 中日数 | 疲労P | 負傷チェック |
|--------|-------|------------|
| 中2日以内 | **登板不可** | — |
| 中3日 | −3 | なし |
| 中4日以上 | カード記載疲労P | なし |

→ 通常より**2日短縮**（中4日〜がカード値で登板可）

#### 長イニング敗戦時（result_category = "long_loss"）

| 中日数 | 疲労P | 負傷チェック |
|--------|-------|------------|
| 中2日以内 | **登板不可** | — |
| 中3日 | 0 | **発動** |
| 中4日 | −4 | なし |
| 中5日 | −2 | なし |
| 中6日 | −1 | なし |
| 中7日以上 | カード記載疲労P | なし |

→ 通常より**1日延長**（中7日〜がカード値）

**まとめ（早見表）**:

| 前登板結果 | 中2日 | 中3日 | 中4日 | 中5日 | 中6日 | 中7日以上 |
|-----------|-------|-------|-------|-------|-------|---------|
| 通常 | 不可 | P0※ | P-3(2連続で※) | P-1 | カード値 | カード値 |
| KO・ノーゲーム | 不可 | P-3 | カード値 | カード値 | カード値 | カード値 |
| 長イニング敗戦 | 不可 | P0※ | P-4 | P-2 | P-1 | カード値 |

※ = 負傷チェック発動

---

### 8.3.2 リリーフ→リリーフ（累積イニング管理）

#### 累積イニング加算・減衰

```
RELIEF_INNINGS_MANAGEMENT:

【加算】
  1登板 = +1イニング（回跨ぎも1イニングとカウント）

【減衰】（登板しなかった日ごと）
  IF accumulated_innings <= 3:
    accumulated_innings -= 2  # 下限: 0
  ELSE:  # accumulated_innings >= 4
    accumulated_innings -= 1  # 下限: 0

  MIN = 0（マイナスにはならない）
```

#### 登板時の疲労P計算

| 累積イニング数 | 疲労P |
|--------------|-------|
| 0 | カード記載疲労P |
| 1 | 0 |
| 2以上 | 0相当（疲労状態） |

#### 中日数による回復

| 中日数 | 疲労P |
|--------|-------|
| 中5日 | 0 |
| 中6日以上 | カード記載疲労P |

#### 負傷チェック発動

累積3イニング以上での登板時に発動（§8.5参照）

---

### 8.3.3 先発→リリーフ

| 前登板結果 | カードP値回復（P0→カード値） |
|-----------|--------------------------|
| 通常 | 中3日→P0、中4日以上→カード値 |
| KO・ノーゲーム | 中2日→P0、中3日以上→カード値 |
| 長イニング敗戦 | 中4日→P0、中5日以上→カード値 |

**スラッシュ選手優遇**: 各ケースより1日短い間隔でリリーフ回転可能
- 通常: 中2日→P0、中3日以上→カード値
- KO後: 中1日→P0、中2日以上→カード値
- 長イニング後: 中3日→P0、中4日以上→カード値

---

### 8.3.4 リリーフ→先発

#### 通常選手

| 中日数 | 疲労P |
|--------|-------|
| 中3日 | 0 |
| 中4日 | −3 |
| 中5日 | −1 |
| 中6日以上 | カード記載疲労P |

#### スラッシュ選手

直近リリーフ登板の累積イニングに応じて短縮可能（詳細はsources/pitcher-rest-rules-analysis.md §4-b参照）

---

## 8.4 オープナー起用

### 8.4.1 適用条件

- 「オープナー可」アビリティ保有選手のみ
- 予告先発で「オープナー起用」を明言必須
- 同時に第二先発候補を宣言（ゼロや複数も可）。指定された投手は2番手での登板時、先発投手として扱う。

### 8.4.2 役割分担と休養計算

| 役割 | 疲労計算ルール |
|------|--------------|
| オープナー本人 | この登板を**リリーフ**での登板として扱う |
| 第二先発候補の2番手投手 | この登板を**先発**での登板として扱う |
| その他のリリーフ投手 | 通常通り**リリーフ**登板として扱う |

### 8.4.3 オープナー負傷チェック発動条件

以下のいずれかで負傷チェック発動（§8.5参照）:
- 中2日以内の連続オープナー登板
- 前日登板
- 累積1イニング以上での登板時

---

## 8.5 負傷チェック（投手休養起因）

### 8.5.1 発動条件一覧

| # | 条件 | 状況 |
|---|------|------|
| 1 | 先発: 疲労P 0での先発登板 | 中3日先発 / 長イニング後中3日先発 |
| 2 | 先発: 2回連続での中4日先発 | consecutive_short_rest_count >= 1 の中4日先発 |
| 3 | リリーフ: 累積3イニング以上での登板 | accumulated_innings >= 3 |
| 4 | オープナー: 中2日以内の連続登板 / 前日登板 / 累積1イニング以上 | — |

### 8.5.2 判定

```
INJURY_CHECK:
  INPUT: trigger_condition (上記1〜4のいずれか)

  STEP 1: 1d20をロール
  STEP 2:
    IF dice_roll <= 6:
      → 負傷（けが特徴レベル2で怪我チェックへ）
    ELSE:
      → 安全（通常通り登板）

  → 怪我チェックの詳細: 10-injuries-and-traits.md
```

**Dugout実装**: `pitcher_game_state.injury_check` カラム（"safe" / "injured"）

---

## 8.6 負傷離脱中の扱い

```
INJURY_ABSENCE_RULES:

  # 中日数カウントに離脱期間を含めない
  rest_days = 実際の試合日数差 - absence_days

  # 10日（離脱除外）空ければ疲労なしで登板可能
  IF rest_days >= 10:
    fatigue_p = card_stamina  # カード記載値で登板可能
```

---

## 8.7 投手管理の完全フロー

### 8.7.1 試合後（Phase5_PostGame）

```
POST_GAME_PITCHER_FLOW:
  FOREACH pitcher in game.pitchers:
    1. result_category を計算（§8.2.3）
    2. 疲労P の記録
    3. 連続中4日先発カウントの更新（consecutive_short_rest_count）
    4. 累積イニングの更新（リリーフの場合）
    5. 負傷チェック実施（条件該当時、§8.5）
    6. pitcher_game_state に保存
```

### 8.7.2 次試合予告先発時（Phase3_GameSetup）

```
PRE_GAME_PITCHER_VALIDATION:
  INPUT: pitcher, next_game_date, last_game_state

  STEP 1: 中日数を計算
    rest_days = (next_game_date - last_game_date) - 1
    有効中日数 = rest_days - absence_days（離脱期間を除外）

  STEP 2: 登板可否判定
    IF role == "starter" AND effective_rest_days <= 2:
      → 登板不可（エラー）
    IF role == "reliever":
      → 登板不可制限なし（中0日=連投も可能）
        累積イニング管理で疲労は蓄積するが、登板自体に日数制限はない

  STEP 3: 疲労P計算
    → §8.3の対応テーブルを参照

  STEP 4: 負傷チェック発動判定
    → §8.5の条件確認

  OUTPUT: fatigue_p, injury_check_required
```

---

## 8.8 他章との関係

| 参照先 | 内容 |
|--------|------|
| `01-players-and-cards.md` | スタミナ値（starter:4-9 / relief:0-3）・is_relief_only |
| `04-game-setup.md` | 予告先発・オープナー起用宣言のタイミング |
| `05-at-bat-resolution.md §1.7` | 試合中の投球番号決定 |
| `05-at-bat-resolution.md §1.8` | 試合中の疲労判定 |
| `10-injuries-and-traits.md` | 怪我チェック（けが表参照・休場日数決定） |
| `game_rules.yaml` | `thbig_baseball.game.ko_innings_threshold.value = 5` |
| `sources/pitcher-rest-rules-analysis.md` | 投手休養ルール調査メモ（正本参照元） |

---

## 8.9 警告試合

```
WARNING_GAME:

  # 発動条件（以下のいずれかが発生すると警告試合になる）
  発動条件:
    1. DB乱闘が発生した後
    2. 危険球退場が発生した後、その死球を受けたチームの選手が死球を与えた場合
    3. 両チームが1試合で3個以上ずつ死球を与えた場合

  ※ sources/procedures.md §9.3 の記述との対応:
    - 「DB乱闘後に危険球を受けた側がDB発生」= 条件1（DB乱闘後）+ 条件2（危険球後に被DB側が発生）
    - 「互いにDB3個以上」= 条件3

  # 警告試合中のDB処理
  WARNING_GAME_DB:
    死球が発生した場合:
      1. 打者は通常通りDB処理で出塁
      2. 投手は即退場（危険球退場と同じ扱い、投手交代が必要）
      3. 打者の負傷判定はなし（通常の警告試合DB退場には負傷判定なし）

  ※ 警告試合に「なる前」のDB（発動条件3の3個目等）は通常のDB処理。
  ※ 解除条件: Wikiに明記なし（試合終了まで継続と解釈）
```

> 出典: https://thbigbaseball.wiki.fc2.com/wiki/追加ルール / sources/procedures.md §9.3

---

## 8.10 精神疲労ルール

⚠️ **「精神疲労」は2つの別概念**:

| 概念 | 種別 | 定義 | 現在の該当 |
|------|------|------|-----------|
| 投手特徴「精神疲労」 | カード記載の選手特徴 | 失点した時点で疲労状態になる（通常は一定投球数で疲労するが、失点で即疲労） | 現在該当なし |
| 精神疲労ルール | 全投手共通のルールメカニクス | 累積10失点/15失点で発動する試合後処理 | 全投手に適用 |

- 選手特徴「精神疲労」は01-players-and-cards.md §1.13の特徴表に記載
- 精神疲労ルール（以下）は選手特徴と無関係に、全投手に適用される

```
MENTAL_FATIGUE_RULE:

  # 精神疲労（10失点）
  MENTAL_FATIGUE:
    発動条件: 全ての投手が10失点（非自責を含む）した場合
    効果: イニング数に関わらず疲労状態（fatigue_p = 0）となる

    先発投手の追加ペナルティ:
      精神疲労した次のイニングも投げた場合
      → result_category = "long_loss"（長いイニングを投げて敗戦）扱い
      → 次登板の回復に中7日を要する（§8.3.1 長イニング敗戦ルール適用）

      ※ KO敗戦と重複した場合: "long_loss" が優先

  # 精神崩壊（15失点）
  MENTAL_COLLAPSE:
    発動条件: 全ての投手が15失点（非自責を含む）した場合
    効果: 試合終了時に負傷チェックを行う

    負傷チェック:
      1d20 を実行
      6以下 → 負傷確定
      7以上 → 負傷なし

      負傷確定時:
        → けが特徴2でけがチェック（§9章 負傷判定プロトコル）

      ⚠️ この負傷は特例（§3.7 特例選手ルール）でも回避不可

    先発投手の追加ペナルティ（負傷回避時も適用）:
      → result_category = "long_loss" 扱い（中7日回復）

    中継ぎ投手の追加ペナルティ:
      → 累積イニング + 4 を追加

  # 救済措置（精神疲労状態の投手が降板した試合中）
  MENTAL_FATIGUE_RELIEF:
    適用条件:
      - 精神疲労状態（10失点以上）の投手が降板した試合中
      - 登板する投手が「累積イニング0」かつ「コスト1」の選手

    効果:
      → 本来の疲労P より +2イニング分疲労せずに登板できる
      （累積イニングの計算は通常通り行う）

    例:
      疲労P=1R の投手 → 3Rまで疲労なし
      4イニング目に走者を出すと疲労、5イニング目から疲労状態

    ※ 例外: 天弓千亦（固有名）もこのルール適用可（コスト制限なし）
```

> 出典: https://thbigbaseball.wiki.fc2.com/wiki/追加ルール
