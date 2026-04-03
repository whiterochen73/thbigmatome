# thbigmatome-front UI統廃合設計

**作成**: 軍師マキノ (subtask_463a / cmd_463)
**日付**: 2026-03-04

---

## 1. 現状分析

### 1.1 全28ファイル一覧（views/ + commissioner/）

| # | ファイル | ルート | 行数 | カテゴリ | 利用頻度 |
|---|---------|--------|------|---------|---------|
| 1 | HomeView | `/` | 256 | ハブ | 高（ランディング） |
| 2 | SeasonPortal | `/teams/:teamId/season` | 479 | シーズン運営 | 高（日次利用） |
| 3 | ActiveRoster | `/teams/:teamId/roster` | 736 | シーズン運営 | 中（ロスター変更時） |
| 4 | GameResult | `/teams/:teamId/season/games/:scheduleId` | 314 | シーズン運営 | 高（試合後） |
| 5 | ScoreSheet | `.../:scheduleId/scoresheet` | 543 | シーズン運営 | 高（試合後） |
| 6 | PlayerAbsenceHistory | `/teams/:teamId/season/player_absences` | 138 | シーズン運営 | 低（怪我発生時） |
| 7 | GameImportView | `/games/import` | 791 | IRCログ検証 | 中（試合取り込み時） |
| 8 | GameRecordListView | `/game-records` | 148 | IRCログ検証 | 中（レビュー時） |
| 9 | GameRecordDetailView | `/game-records/:id` | 417 | IRCログ検証 | 中（レビュー時） |
| 10 | GamesView | `/games` | 169 | 試合データ | 中（一覧閲覧） |
| 11 | GameDetailView | `/games/:id` | 248 | 試合データ | 中（詳細確認） |
| 12 | GameLineupView | `/games/:id/lineup` | 220 | 試合データ | 低（ラインナップ確認） |
| 13 | StatsView | `/stats` | 179 | 成績集計 | 高（成績確認） |
| 14 | TeamList | `/teams` | 149 | マスタ/ナビ | 中（チーム選択） |
| 15 | TeamMembers | `/teams/:teamId/members` | 473 | マスタ管理 | 低（初期登録・入替時） |
| 16 | Players | `/players` | 167 | マスタ管理 | 低（マスタ参照） |
| 17 | ManagerList | `/managers` | 227 | マスタ管理 | 低（マスタ参照） |
| 18 | CostAssignment | `/cost_assignment` | 163 | マスタ管理 | 低（年1回コスト会議後） |
| 19 | PlayerCardsView | `/player-cards` | 424 | マスタ管理 | 中（カード参照） |
| 20 | PlayerCardDetailView | `/player-cards/:id` | 1297 | マスタ管理 | 中（カード詳細） |
| 21 | CompetitionRosterView | `/competitions/:id/roster/:teamId` | 344 | マスタ管理 | 低（大会登録時） |
| 22 | Settings | `/settings` | 72 | 設定 | 低 |
| 23 | LoginForm | `/login` | 159 | 認証 | — |
| 24 | StadiumsView | `/commissioner/stadiums` | 255 | コミッショナー | 低 |
| 25 | CardSetsView | `/commissioner/card_sets` | 115 | コミッショナー | 低 |
| 26 | CompetitionsView | `/commissioner/competitions` | 283 | コミッショナー | 低 |
| 27 | UsersView | `/commissioner/users` | 270 | コミッショナー | 低 |
| 28 | LeaguesView | `/commissioner/leagues` | 687 | レガシー | なし（リダイレクト済み） |

### 1.2 現状のナビゲーション構造

```
サイドバー（NavigationDrawer）:
  ├─ ホーム (/)
  ├─ 試合記録 (/games)
  ├─ 成績まとめ (/stats)
  ├─ チーム編成 (/teams)
  ├─ 選手カード (/player-cards)
  └─ [管理] (コミッショナーのみ)
      ├─ 大会管理
      ├─ カードセット
      ├─ 球場
      ├─ 選手マスタ
      └─ ユーザー管理
```

**問題点**:
- サイドバーに「シーズンポータル」「IRCログ取り込み」「パーサーレビュー」への直接導線がない
- ホーム → チーム選択 → SeasonPortal のステップが多い
- 試合記録（手動入力系）とIRCログ検証系が混在（/games配下）
- 試合データの2系統（Game = 手動入力 / GameRecord = パーサー結果）の関係が不明確

### 1.3 試合データ2系統の現状

| 概念 | モデル | 入力経路 | 主な画面 |
|------|--------|---------|---------|
| **Game** (手動) | games テーブル | SeasonPortal → GameResult | GamesView, GameDetailView, GameLineupView |
| **GameRecord** (パーサー) | game_records テーブル | GameImportView → parse_log → import_log | GameRecordListView, GameRecordDetailView |

現状は2系統が独立。将来的にGameRecord確定 → Game生成の連携が必要（レビューUIで確認後に成績反映）。

---

## 2. 設計方針

### 2.1 2大軸の定義

**軸A: シーズン運営（メイン動線）**
- 対象ユーザー: 全プレイヤー（ペルソナA〜D）
- サイクル: ロスター編成 → 試合実施 → 結果入力 → 成績確認
- ハブ: SeasonPortal（カレンダー + 当日試合 + 離脱者情報）
- 利用頻度: 高（日次〜週次）

**軸B: IRCログ検証（運営ツール）**
- 対象ユーザー: 主にプレイヤー本人 + コミッショナー
- フロー: ログ貼り付け → 解析 → レビュー → 確定 → 成績反映
- 入口: GameImportView（独立した入口を維持）
- 利用頻度: 中（試合のたびに1回）

### 2.2 統合基準

| 基準 | 統合する | 維持する |
|------|---------|---------|
| 利用頻度が高く同じフローで使う | SeasonPortal内にタブ/セクション化 | — |
| 独立したワークフローを持つ | — | 別画面として維持 |
| 年数回以下の低頻度操作 | マスタ管理に集約 | — |
| レガシーで代替済み | 削除 | — |

---

## 3. 新画面構成案

### 3.1 サイドバー（再構成）

```
サイドバー:
  ├─ ホーム (/)                          ← 大会選択 + シーズン概要
  ├─ シーズン (/teams/:id/season)        ← NEW: チーム選択後の主導線
  │    ├─ [カレンダー]                    ← SeasonPortalのタブ1
  │    ├─ [ロスター]                      ← SeasonPortalのタブ2 (ActiveRoster統合)
  │    ├─ [離脱者]                        ← SeasonPortalのタブ3 (PlayerAbsenceHistory統合)
  │    └─ [成績]                          ← SeasonPortalのタブ4 (StatsView統合 or リンク)
  ├─ 試合ログ (/games/import)            ← IRCログ検証の入口
  │    └─ レビュー (/game-records)        ← パーサーレビュー
  ├─ 試合一覧 (/games)                   ← 確定済み試合データ
  ├─ 選手カード (/player-cards)           ← マスタ参照
  └─ [管理] (コミッショナー)
      ├─ 大会管理
      ├─ カードセット
      ├─ 球場
      ├─ 選手マスタ
      ├─ チーム管理                       ← TeamList + TeamMembers を集約
      ├─ コスト登録                       ← CostAssignment
      ├─ 監督一覧                         ← ManagerList
      └─ ユーザー管理
```

### 3.2 ルーティング案

```typescript
// === 軸A: シーズン運営 ===
'/'                                          // HomeView（変更なし）
'/teams/:teamId/season'                      // SeasonPortal（タブ化拡張）
'/teams/:teamId/season?tab=calendar'         //   カレンダー（既存）
'/teams/:teamId/season?tab=roster'           //   ロスター（ActiveRoster統合）
'/teams/:teamId/season?tab=absences'         //   離脱者（PlayerAbsenceHistory統合）
'/teams/:teamId/season/games/:scheduleId'    // GameResult（変更なし）
'/teams/:teamId/season/games/:scheduleId/scoresheet'  // ScoreSheet（変更なし）

// === 軸B: IRCログ検証 ===
'/games/import'                              // GameImportView（変更なし）
'/game-records'                              // GameRecordListView（変更なし）
'/game-records/:id'                          // GameRecordDetailView（変更なし）

// === 試合データ（確定済み） ===
'/games'                                     // GamesView（変更なし）
'/games/:id'                                 // GameDetailView（変更なし）
'/games/:id/lineup'                          // GameLineupView（変更なし）

// === 成績集計 ===
'/stats'                                     // StatsView（変更なし）

// === マスタデータ管理 ===
'/teams'                                     // TeamList（変更なし）
'/teams/:teamId/members'                     // TeamMembers（変更なし）
'/players'                                   // Players（変更なし）
'/player-cards'                              // PlayerCardsView（変更なし）
'/player-cards/:id'                          // PlayerCardDetailView（変更なし）
'/competitions/:id/roster/:teamId'           // CompetitionRosterView（変更なし）
'/cost_assignment'                           // CostAssignment（変更なし）
'/managers'                                  // ManagerList（変更なし）
'/settings'                                  // Settings（変更なし）

// === コミッショナー ===
// 変更なし（既存のcommissioner/*を維持）

// === 削除 ===
// LeaguesView — リダイレクト済み、ファイル削除
// '/teams/:teamId/roster' — SeasonPortal?tab=rosterに統合
// '/teams/:teamId/season/player_absences' — SeasonPortal?tab=absencesに統合
```

### 3.3 SeasonPortal タブ化設計

```
SeasonPortal.vue (拡張)
├─ タブ1: カレンダー（既存内容をそのまま維持）
├─ タブ2: ロスター
│    └─ ActiveRoster.vue のコンテンツを <SeasonRosterTab> コンポーネント化
├─ タブ3: 離脱者
│    └─ PlayerAbsenceHistory.vue のコンテンツを <SeasonAbsenceTab> コンポーネント化
└─ ツールバー（既存: 日付ナビ + 試合結果ボタン + 離脱登録ボタン）
```

**重要**: ActiveRoster.vue / PlayerAbsenceHistory.vue のロジックをコンポーネントに抽出し、
SeasonPortal からタブとして呼び出す。元のルートはリダイレクトに変更。

---

## 4. 統合/廃止/維持/新設 判定表

| 画面 | 判定 | 理由 | Phase |
|------|------|------|-------|
| HomeView | **維持** | ランディングページ。大会選択+概要表示 | — |
| SeasonPortal | **拡張** | タブ化（カレンダー/ロスター/離脱者）。シーズン運営のハブに | 1 |
| ActiveRoster | **統合→SeasonPortal** | タブ2としてSeasonPortal内に移動 | 1 |
| PlayerAbsenceHistory | **統合→SeasonPortal** | タブ3としてSeasonPortal内に移動 | 1 |
| GameResult | **維持** | 個別試合の結果入力。SeasonPortalから遷移 | — |
| ScoreSheet | **維持** | スコアシート表示。GameResultから遷移 | — |
| GameImportView | **維持** | IRCログ検証の入口。独立ワークフロー | — |
| GameRecordListView | **維持** | パーサーレビュー一覧。IRCログ検証系 | — |
| GameRecordDetailView | **維持** | パーサーレビュー詳細。IRCログ検証系 | — |
| GamesView | **維持** | 確定済み試合一覧 | — |
| GameDetailView | **維持** | 試合詳細表示 | — |
| GameLineupView | **維持** | ラインナップ表示 | — |
| StatsView | **維持** | 成績集計。独立ページとして維持 | — |
| TeamList | **維持** | チーム選択ナビ | — |
| TeamMembers | **維持** | チームメンバー管理 | — |
| Players | **維持** | 選手マスタ参照 | — |
| ManagerList | **維持** | 監督一覧（低頻度だが独立機能） | — |
| CostAssignment | **維持** | コスト登録（年1回、独立ワークフロー） | — |
| PlayerCardsView | **維持** | カード一覧参照 | — |
| PlayerCardDetailView | **維持** | カード詳細（1297行、最大の画面） | — |
| CompetitionRosterView | **維持** | 大会ロスター管理 | — |
| Settings | **維持** | ユーザー設定 | — |
| LoginForm | **維持** | 認証 | — |
| StadiumsView | **維持** | コミッショナー機能 | — |
| CardSetsView | **維持** | コミッショナー機能 | — |
| CompetitionsView | **維持** | コミッショナー機能 | — |
| UsersView | **維持** | コミッショナー機能 | — |
| **LeaguesView** | **削除** | レガシー。リダイレクト済み（→CompetitionsView）| 1 |

### サイドバー再構成

| 判定 | 内容 | Phase |
|------|------|-------|
| **変更** | 「試合ログ」をサイドバーに追加（/games/import） | 2 |
| **変更** | 「チーム編成」→チーム選択→SeasonPortalへの導線改善 | 2 |
| **検討** | サイドバーにチーム直リンク（選択チームのSeasonPortal）追加 | 2 |

---

## 5. マイグレーション順序

### Phase 1: SeasonPortal統合 + レガシー削除（最小変更・最大効果）

**スコープ**:
1. SeasonPortal.vue にタブUI（v-tabs）を追加
2. ActiveRoster.vue のテンプレート+ロジックを `<SeasonRosterTab>` コンポーネントに抽出
3. PlayerAbsenceHistory.vue のテンプレート+ロジックを `<SeasonAbsenceTab>` コンポーネントに抽出
4. SeasonPortal.vue で3タブ表示（カレンダー / ロスター / 離脱者）
5. 旧ルート `/teams/:teamId/roster` → `/teams/:teamId/season?tab=roster` にリダイレクト
6. 旧ルート `/teams/:teamId/season/player_absences` → `/teams/:teamId/season?tab=absences` にリダイレクト
7. LeaguesView.vue ファイル削除（ルートは既にリダイレクト済み）

**工数見積**: 中規模（SeasonPortal 479行 + ActiveRoster 736行 + PlayerAbsenceHistory 138行のリファクタ）

**リスク**: ActiveRoster.vue が736行と大きく、TeamNavigation コンポーネント依存がある。コンポーネント化時に props/emit の整理が必要。

### Phase 2: サイドバー再構成

**スコープ**:
1. NavigationDrawer.vue のメニュー項目を再構成
2. 「試合ログ」（/games/import）をメインメニューに追加
3. チーム選択状態の永続化（Pinia store）
4. 選択チームがある場合、「シーズン」メニューを動的に表示

**前提**: Phase 1完了後

### Phase 3: 将来検討

- GameRecord確定 → Game自動生成の連携（バックエンド変更必要）
- StatsView を SeasonPortal のタブ4として統合するか検討
- マスタ管理画面のグルーピング（管理メニュー下に集約）

---

## 6. P確認事項

### Q1: SeasonPortalタブ化の方針

SeasonPortalにロスター・離脱者をタブ統合する案を採用してよいか？

- **案A（推奨）**: タブ化（カレンダー/ロスター/離脱者の3タブ）
  - 利点: 1画面で全操作可能、画面遷移が減る
  - 欠点: SeasonPortalが大きくなる（コンポーネント分割で対処）
- **案B**: 現状維持（別画面のまま、サイドバーにリンク追加のみ）
  - 利点: 変更最小
  - 欠点: ナビゲーションの改善が限定的

### Q2: StatsViewの扱い

- **案A**: 独立ページとして維持（現状通り）
- **案B（推奨）**: 独立ページ維持 + SeasonPortalからのクイックリンク追加
- **案C**: SeasonPortalのタブ4として完全統合

### Q3: 試合データ2系統の将来方針

GameRecord（パーサー）確定後に Game（手動入力系）に自動変換する連携は、
Phase 3で着手する想定でよいか？ バックエンドのAPI設計が必要なため、
FEリデザインとは別cmdで進める方が安全。

### Q4: LeaguesView削除の確認

LeaguesView.vue（687行）はルートが既にリダイレクト済み。ファイル自体を削除してよいか？
（gitに履歴は残るため復元可能）

### Q5: サイドバーにIRCログ検証の直リンクを追加するか

現状「試合記録」(/games) → 「ログ取り込み」ボタンという導線だが、
サイドバーに「試合ログ」を直接追加したほうが到達が早い。
ただしサイドバー項目が増えるトレードオフあり。
