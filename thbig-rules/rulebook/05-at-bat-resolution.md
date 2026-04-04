# 第5章: 打席処理

**状態**: スケルトン（未着手）
**品質基準**: エミュレーターが本章の処理を実装できるレベル

---

## 5.1 打席フロー概要

TODO: IRCコマンド→ダイスロール→結果コード→状態更新の全フロー
→ 概要は `../mechanics/batting-flow.md` 参照

## 5.2 結果コード体系

TODO: H/2H/3H/HR/G/F/K/BB/DB等の全コード定義と走者移動ルール
→ コード定義は `../mechanics/result-codes.md` 参照

## 5.3 走者状況別処理（8パターン）

TODO: empty/1/2/3/1,2/1,3/2,3/full それぞれの走者移動ロジック
→ データは `../wiki/batting_result_table.md` 参照

## 5.4 保留処理（pending flags）

TODO: pending_baserunning/at_bat_redo/pending_steal の発生条件と解決フロー
