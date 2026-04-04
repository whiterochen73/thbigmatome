# 第9章: 投手管理

**状態**: スケルトン（未着手）
**品質基準**: エミュレーターが本章の処理を実装できるレベル

---

## 9.1 疲労P（Fatigue Points）

TODO: 疲労Pの計算・中日数との関係
→ 調査メモは `../sources/pitcher-rest-rules-analysis.md` 参照

## 9.2 KO判定

TODO: 5イニング未満での交代＋敗戦でKO扱い
→ 閾値は `../game_rules.yaml` の `thbig_baseball.game.ko_innings_threshold` 参照

## 9.3 投球番号決定

TODO: スタミナ・シーズン状態に基づく投球番号

## 9.4 負傷チェック

TODO: 休養不足時の負傷チェック発動条件
→ 調査メモは `../sources/pitcher-rest-rules-analysis.md` 参照
