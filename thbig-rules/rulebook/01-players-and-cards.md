# 第1章: 選手とカード

**状態**: スケルトン（未着手）
**品質基準**: エミュレーターがカードデータを読み込み能力値を参照できるレベル

---

## 1.1 カード構造

TODO: カード種別（pitcher/batter）・能力値フィールド定義

## 1.2 能力値の定義と範囲

TODO: speed/bunt/steal_start/steal_end/injury_rate/stamina の意味・範囲・判定への使用方法
→ 値範囲は `../game_rules.yaml` の `thbig_baseball.player_card` を参照

## 1.3 守備値（defense）

TODO: 守備ポジション別の守備値・範囲チェック値の定義

## 1.4 特殊能力（traits）

TODO: 特殊能力の種別・発動条件
→ データは `../wiki/traits.md` 参照

## 1.5 カードセットとvariant

TODO: カードセット管理・variant概念
→ 定義は `../game_rules.yaml` の `thbig_baseball.player_card.variant` 参照

## 1.6 カードの一意性制約

TODO: (card_set_id, player_id, card_type, variant) のユニーク制約
