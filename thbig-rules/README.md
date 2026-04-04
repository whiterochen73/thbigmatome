# thbig-rules — THBIG野球ゲームルール管理リポジトリ

**AIエージェント向けゲームルール正本リポジトリ**

---

## このリポジトリの役割

このリポジトリは THBIG野球（東方BIG野球）のゲームルールを一元管理する **Single Source of Truth（正本）** です。

- **対象読者**: AIエージェント（足軽・マキノ等）、実装担当者
- **目的**: 各アプリ（Dugout / Clubhouse / Parser）が参照するルールを統一し、実装間の整合性を維持する
- **方針**: ルールはここだけで更新する。各アプリは `sync-rules` でコピーを取り込む

---

## ルール管理の2層構造

### Layer A — アプリビジネスルール（`game_rules.yaml`）

Dugout 等のアプリが直接参照するバリデーションルール。

- チーム構成（roster上限・下限・コスト制限・外の世界枠）
- 選手カードルール（スタミナ・速力・バント等の数値範囲）
- シーズン・大会・監督ルール
- 整合性リスク管理（既知のP1/P2リスクと対処状況）

各ルールには `why`（理由）・`exception`（例外）・`related`（関連ルール）・`implementation`（実装ガイド）を含む。
AIエージェントはこれだけ読めば正しいバリデーションコードを書ける粒度を目指している。

### Layer B — ゲームメカニクス定義（`mechanics/`）

Parserが実装しているゲームロジック（打席処理・UP表・結果コード体系）の概念定義書。

| ファイル | 内容 |
|----------|------|
| `mechanics/up-table.md` | UP表（好プレイ珍プレイ表）の構造・コード範囲・解釈ルール |
| `mechanics/result-codes.md` | 打席結果コード体系の定義（H/G/F/K/BB等） |
| `mechanics/batting-flow.md` | 打撃フロー全体の概要（IRC→Parser→GSMの処理経路） |

---

## 参照方法（各アプリから）

### Dugout（Rails）

```bash
make sync-rules   # thbig-rulesのgame_rules.yamlをconfig/game_rules.yamlに同期
```

同期後、バージョン照合を確認:

```bash
bundle exec rake rules:check
```

### Clubhouse（予定）

`Makefile` に `sync-rules` ターゲットを追加予定（cmd_908で実装）。

### Parser（Python）

`mechanics/` ドキュメントを参照して実装を理解する。実装の正本は Parserコード自体。

---

## 変更手順

1. **thbig-rules でルールを更新**
   - `game_rules.yaml` を編集し、`version` と `changelog` を更新する
   - `why` / `exception` / `related` / `implementation` も必ず更新する

2. **各アプリで sync を実行**
   ```bash
   # Dugout
   cd /path/to/thbigmatome
   make sync-rules
   bundle exec rake rules:check   # バージョン一致を確認

   # Clubhouse（実装後）
   cd /path/to/thbig-clubhouse
   make sync-rules
   ```

3. **関連コードとテストを更新**
   - 変更したルールに対応するバリデーション・テストを更新する
   - `known_integrity_risks` に新しいリスクがあれば追記する

4. **コミット・プッシュ**
   - thbig-rules の変更をコミット
   - 各アプリの変更もコミット（sync済みの `game_rules.yaml` を含む）

---

## ファイル構成

```
thbig-rules/
├── README.md                  # このファイル（ルール管理方針）
├── game_rules.yaml            # Layer A: アプリビジネスルール正本
├── date-concepts.md           # 日付概念定義書（ゲーム内日付 vs 実日付）
├── mechanics/                 # Layer B: ゲームメカニクス概念定義書
│   ├── up-table.md            # UP表の構造・コード範囲
│   ├── result-codes.md        # 打席結果コード体系
│   └── batting-flow.md        # 打撃フロー概要
└── (既存の分析・仕様書類)
    ├── card-structure.md
    ├── game-flow.md
    ├── irc-log-analysis.md
    ├── player-card-spec.md
    ├── procedures.md
    └── review-report.md
```

---

## バージョン管理

`game_rules.yaml` の `version` フィールドで追跡する。

- 現在のバージョン: **v1.1**（2026-04-04、AIエージェント向けフォーマット）
- breaking change がある場合は `breaking: true` を記録する

---

*管理: AI整合性フレームワーク（cmd_907）*
*更新時は `game_rules.yaml` の `changelog` も必ず更新すること*
