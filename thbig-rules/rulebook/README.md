# rulebook/ — AIエージェント・エミュレーター向け構造化ルール仕様

品質基準: **「このルールブックがあればゲームのエミュレーターが作れる」**（P決定 2026-04-04）

## 構成方針

- 定数辞書ではなく **状態遷移仕様書** を目指す
- 全判定の **入力→条件→出力** を定義する
- テーブルの全セル値は `../wiki/` に委譲し、ルールブックには **構造・判定ロジック・適用条件** を記載
- 機械可読データは `data/` に置く

## 章立て

| ファイル | 内容 | 状態 |
|----------|------|------|
| `01-players-and-cards.md` | カード構造・能力値・守備値 | 未着手 |
| `02-teams-and-rosters.md` | チーム構成・ロスター・コスト・監督 | 未着手 |
| `03-seasons-and-schedules.md` | シーズン・日程・大会・離脱管理 | 未着手 |
| `04-game-setup.md` | 試合準備（オーダー・先発・球場・天候） | 未着手 |
| `05-at-bat-resolution.md` | 打席処理（エミュレーター中核） | 未着手 |
| `06-special-events.md` | UP表・エラー・レンジ・特徴 | 未着手 |
| `07-baserunning.md` | 走塁表・盗塁・エンドラン | 未着手 |
| `08-bunt-system.md` | バント3テーブル・FC判定 | 未着手 |
| `09-pitching.md` | 投手管理（疲労・KO・交代・投球番号決定） | 未着手 |
| `10-injuries-and-traits.md` | 怪我テーブル・特殊能力一覧 | 未着手 |

## data/ サブディレクトリ

機械可読形式（YAML等）のテーブル値を置く。

| ファイル（予定） | 内容 |
|-----------------|------|
| `batting-result-ranges.yaml` | 打撃結果コードの数値範囲 |
| `up-table-codes.yaml` | UP表4桁コード→カテゴリ対応 |
| `steal-table.yaml` | 盗塁判定テーブル |
| `bunt-table.yaml` | バント結果テーブル |

## 導出関係

```
wiki/（Wikiテーブル生データ）
sources/（調査メモ・口頭確認ルール）
  ↓
rulebook/（構造化ルール仕様） ← ここ
  ↓
docs/（人間向け解説文書）
game_rules.yaml（定数・制約値のみ）
```

## 設計ドキュメント

`context/rulebook-restructure-design.md`（Shogunリポジトリ）参照。
