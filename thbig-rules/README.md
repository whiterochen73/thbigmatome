# thbig-rules — THBIG野球ゲームルール管理リポジトリ

**AIエージェント向けゲームルール正本リポジトリ**

---

## このリポジトリの役割

このリポジトリは THBIG野球（東方BIG野球）のゲームルールを一元管理する **Single Source of Truth（正本）** です。

- **対象読者**: AIエージェント（足軽・マキノ等）、エミュレーター実装者、実装担当者
- **目的**: 各アプリ（Dugout / Clubhouse / Parser）が参照するルールを統一し、実装間の整合性を維持する
- **方針**: ルールはここだけで更新する。各アプリは `sync-rules` でコピーを取り込む

---

## ディレクトリ構成と役割

```
thbig-rules/
├── game_rules.yaml        # ルール定数・制約値（2レイヤー: 東方BIG野球 / Lペナ）
├── README.md              # このファイル
│
├── rulebook/              # AIエージェント・エミュレーター向け構造化ルール仕様（★主役）
│   ├── 01-players-and-cards.md
│   ├── 02-teams-and-rosters.md
│   ├── 03-seasons-and-schedules.md
│   ├── 04-game-setup.md
│   ├── 05-at-bat-resolution.md   # ★エミュレーター中核
│   ├── 06-special-events.md
│   ├── 07-baserunning.md
│   ├── 08-bunt-system.md
│   ├── 09-pitching.md
│   ├── 10-injuries-and-traits.md
│   └── data/              # 機械可読形式のテーブル値（YAML等）
│
├── wiki/                  # Wikiスクレイプの生データ（ゲームテーブル）
├── sources/               # Wiki以外のデータソース（P口頭確認・調査メモ・仕様書素材）
├── docs/                  # 人間向け解説文書
└── mechanics/             # Layer B概念定義書（Parserとの連携用）
```

### 各ディレクトリの役割詳細

| ディレクトリ | 対象読者 | 内容 |
|-------------|---------|------|
| `rulebook/` | AIエージェント・エミュレーター実装者 | 全判定の入力→条件→出力を定義した構造化仕様 |
| `wiki/` | — | Wikiから取得した生データテーブル |
| `sources/` | ルールブック執筆者 | P口頭確認・調査メモ・仕様書素材（Wiki以外） |
| `docs/` | 人間（監督・コミッショナー） | ゲームルールの自然言語解説 |
| `mechanics/` | Parserエージェント | IRCパーサーのゲームロジック概念定義 |

### 導出関係

```
wiki/ ─────────┐
               ├──▶ rulebook/ ──▶ docs/
sources/ ──────┘       │
                        └──▶ game_rules.yaml（定数・制約値抽出）
```

---

## game_rules.yaml の2レイヤー構造

```yaml
thbig_baseball:    # 東方BIG野球ゲーム本体のルール（カード能力値・試合メカニクス）
  player_card: ...
  game: ...

lpena:             # Lペナ（IRCリーグ）運営ルール
  team_composition: ...
  season: ...
  competition: ...
  manager: ...
```

---

## 参照方法（各アプリから）

### Dugout（Rails）

```bash
make sync-rules        # game_rules.yaml を config/game_rules.yaml に同期
bundle exec rake rules:check  # バージョン照合
```

### Clubhouse（予定）

`Makefile` に `sync-rules` ターゲットを追加予定。

---

## 変更手順

1. **thbig-rules でルールを更新**（`game_rules.yaml` または `rulebook/` 等）
2. **各アプリで sync を実行**: `make sync-rules` → `bundle exec rake rules:check`
3. **関連コードとテストを更新**
4. **コミット**（thbig-rules と各アプリ両方）

---

*管理: AI整合性フレームワーク（cmd_907/cmd_910/cmd_914）*
