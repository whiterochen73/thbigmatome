# 打撃フロー概要

**Layer B 概念定義書 — 雛形**
作成: 2026-04-04 ashigaru4 (subtask_907a)
実装: `thbig-irc-parser/src/thbig_irc_parser/game_state.py`, `atbat_parser.py`

---

## 1. 概要

THBIG野球の1打席は、IRCチャットコマンド→ダイスロール→結果コード解釈→GSM状態更新という
一連のフローで処理される。

---

## 2. フロー図（概要）

```
[IRC打席コマンド]
      ↓
[atbat_parser: ログ解析]
      ↓
[result_code: コード正規化・エイリアス変換]
      ↓
     ┌────────────────────────────────┐
     │ UP表トリガー？（特殊イベント）  │
     │ コード外またはd20結果に応じて   │
     └────────────┬───────────────────┘
                  │ YES                  NO
                  ↓                      ↓
          [up_table: 4桁コード解決]  [通常GSM処理]
                  ↓
     [gsm_result_code上書き or 特殊処理]
                  ↓
     [game_state: 状態更新（走者・アウト・得点）]
                  ↓
     [AtBatOutcome: 打席結果オブジェクト]
                  ↓
     [post_processor: イベント付与・盗塁処理・統計集計]
```

---

## 3. 主要フェーズ詳細

### 3.1 IRC打席コマンド解析（atbat_parser）

IRCログ行から以下を抽出:
- 打者名・打席番号
- 結果コード（例: `H6`、`K`、`G4D`）
- 特殊コマンド（バント、盗塁、エンドラン、投手交代、代打/代走など）

### 3.2 結果コード正規化（result_code）

1. 全角→半角変換
2. エイリアス変換（`死球` → `DB` など）
3. パターンマッチング → コード種別 + 守備手番号の抽出

### 3.3 UP表トリガー（up_table）

通常の打席結果ではなく、追加ダイスで UP表コードが生成された場合:
1. 4桁コードを `resolve_up_code(code_str, has_runners, stadium_setting)` で解決
2. カテゴリに応じた処理（エラーチェック / 走者進塁 / 特殊プレイ）
3. `gsm_result_code` がある場合は通常GSMコードを上書きして状態機械へ

### 3.4 GSM状態更新（game_state）

`GameStateMachine` が管理する状態:

| 状態 | 説明 |
|------|------|
| `runners` | 走者辞書 `{'1B': bool, '2B': bool, '3B': bool}` |
| `outs` | 現在のアウト数（0〜3） |
| `score` | `{'home': int, 'visitor': int}` |
| `inning` | 現在のイニング |
| `is_bottom` | 表/裏フラグ |

打席処理は走者状況キー（`empty`, `1`, `2`, `3`, `1,2`, `1,3`, `2,3`, `full`）でハンドラーをルックアップし、
コード種別（`H`, `G`, `F`, `K`, `BB` など）に応じた走者移動ロジックを適用する。

### 3.5 保留処理（AtBatOutcome flags）

一部イベントは1打席で完結せず「保留フラグ」をセットして後続処理に委譲:

| フラグ | 後続処理 |
|--------|---------|
| `pending_baserunning` | 走塁表（baserunning table）でアウト/進塁を判定 |
| `at_bat_redo` | WP/PBにより同打者が再打席 |
| `pending_steal` | エンドランK時、1塁走者の盗塁成否を判定 |

### 3.6 後処理（post_processor）

- `attach_events`: 打席にゲームイベント（得点・アウト・特殊プレイ）を付与
- `classify_extra_rolls`: 追加ダイス（走塁表・エラーチェックなど）を分類
- `attach_steal_attempts`: 盗塁試み結果を走者情報に付与

---

## 4. 特殊打席シナリオ

### 4.1 バント

`_BUNT_CMD_RE` で検出。バント時は特定の結果コードテーブルを参照（通常と異なる守備分布）。

### 4.2 盗塁・エンドラン

`_STEAL_CMD_RE` / `_ENDRUN_RE` で検出。
エンドランK時は `pending_steal = True` をセットし、後続フローで1塁走者の盗塁成否を解決。

### 4.3 投手交代・代打/代走

ログ行単位で検出し、打席外の状態変更として処理。打席結果には影響しない。

---

## 5. チャンネル対応

IRC本番環境は4チャンネル並行 (`#thc_BIGbaseball` 〜 `#thc_BIGbaseball4`)。
Parserは `channel` パラメータで各チャンネルのログを独立処理する。
ゲーム境界（試合開始/終了）は `context/irc-game-boundary-results.json` で管理。

---

*詳細はParser実装 `game_state.py`、`atbat_parser.py`、`post_processor.py` を参照すること*
