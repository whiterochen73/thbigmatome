# 第2章: チームとロスター

**状態**: スケルトン（未着手）
**品質基準**: エミュレーターがチーム編成ルールを検証できるレベル

---

## 2.1 チーム種別

TODO: normal / hachinai の定義・native_series・外の世界枠の反転
→ 定義は `../game_rules.yaml` の `lpena.team_types` 参照

## 2.2 ロスター管理

TODO: ロスター上限50・下限25・試合未実施スキップ条件
→ 値は `../game_rules.yaml` の `lpena.team_composition.roster` 参照

## 2.3 1軍・2軍区分

TODO: first/secondの定義・移動ルール・クールダウン

## 2.4 外の世界枠

TODO: 上限4人・バランスルール（4人時に投手1以上AND野手1以上）
→ 値は `../game_rules.yaml` の `lpena.team_composition.outside_world` 参照

## 2.5 コスト制限

TODO: チーム全体コスト上限200・1軍コスト段階制（ティア）
→ 値は `../game_rules.yaml` の `lpena.team_composition.team_total_cost/first_squad_cost` 参照

## 2.6 監督とセカンドチーム

TODO: 1監督2チーム制限・選手排他制約
→ 値は `../game_rules.yaml` の `lpena.manager/team_composition.second_team` 参照
