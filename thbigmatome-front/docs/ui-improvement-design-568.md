# cmd_568: UIデザイン品質改善 設計書

**作成日**: 2026-03-15
**作成者**: 軍師マキノ（subtask_design_568a）
**対象**: thbigmatome-front（Vue.js 3 + Vuetify 3）

---

## 1. 現状分析

### 1.1 NavigationDrawer 現状メニュー構成

現在の `src/components/NavigationDrawer.vue` のメニュー構成:

**メインメニュー（全ユーザー）:**

| # | ラベル | アイコン | パス | 機能カテゴリ |
|---|--------|---------|------|------------|
| 1 | ホーム | mdi-home | / | ダッシュボード |
| 2 | 試合ログ | mdi-file-import | /games/import | 試合記録 |
| 3 | レビュー | mdi-clipboard-check | /game-records | 試合記録 |
| 4 | 試合一覧 | mdi-scoreboard | /games | 試合記録 |
| 5 | 成績 | mdi-chart-bar | /stats | 成績 |
| 6 | 選手カード | mdi-card-account-details | /player-cards | 選手 |
| 7 | シーズン* | mdi-calendar-star | /teams/{id}/season | チーム |

*シーズンはチーム選択済み時のみ表示

**管理メニュー（コミッショナーモード時のみ）:**

| # | ラベル | アイコン | パス |
|---|--------|---------|------|
| 1 | ダッシュボード | mdi-view-dashboard | /commissioner/dashboard |
| 2 | 大会管理 | mdi-trophy-outline | /commissioner/competitions |
| 3 | カードセット | mdi-cards | /commissioner/card_sets |
| 4 | 球場 | mdi-stadium | /commissioner/stadiums |
| 5 | 選手マスタ | mdi-account | /commissioner/players |
| 6 | 監督一覧 | mdi-account-tie | /managers |
| 7 | ユーザー管理 | mdi-account-cog | /commissioner/users |

**外部リンク:**
- 公式Wiki（mdi-baseball-diamond）

**問題点:**
- メインメニューに論理的グルーピングがない（試合系3項目が連続するが視覚的区切りなし）
- 「シーズン」がチーム選択依存で動的出現するが、他のチーム操作項目（ロスター・メンバー等）はメニューにない
- 管理メニューに「監督一覧」がある一方、通常メニューにチーム系の項目がない（ホームからのインライン遷移に依存）
- 設定（/settings）への導線がAppBarのユーザーメニュー内にしかない

### 1.2 既存テーマ設定

**Vuetify theme（vuetify.ts）:**
- Light/Dark 2テーマ定義済み
- 和色ベースのカラーパレット（藍・千草・朱・萌黄・山吹・紅・浅葱）
- テキストカラー4階層（high/medium/caption/disabled）

**Vuetify defaults:**
- VDataTable: density="compact", hover=true
- VBtn: variant="tonal"
- VCard: elevation=1
- VTextField: density="compact", variant="outlined"
- VSelect: density="compact", variant="outlined"

**base.css:**
- Vue Theme由来のCSS変数（--vt-c-*）がそのまま残存 — Vuetifyテーマと二重管理状態
- --color-home / --color-visitor はゲーム固有色（こちらは必要）
- body font-family: 'Zen Kaku Gothic New'がプライマリ指定だが、Google Fontsの読み込みは'Noto Sans JP'と'Shippori Mincho'のみ → 不一致の可能性

**App.vue:**
- Google Fonts: Noto Sans JP + Shippori Mincho + JetBrains Mono
- CSS: h1-h3にShippori Mincho、UIにNoto Sans JP → design-guide.md準拠

### 1.3 改善が必要なView/コンポーネントの特定

**ダイアログ不整合（15ファイル）:**

| 問題 | 該当ファイル数 | 詳細 |
|------|-------------|------|
| max-widthの単位不統一 | 15 | px付き/なし混在（400 vs 500px） |
| v-model binding 3パターン混在 | 15 | computed g/s, defineModel, 直接props |
| persistent属性の不統一 | 15 | 確認ダイアログなのに未設定のものあり |

**サイズ分布:**
- 360-400: 確認ダイアログ（3件）
- 480: 離脱確認（2件）
- 500px: 標準フォーム（10件）
- 600px: 中規模フォーム（2件）
- 900px: 大規模フォーム（1件: PlayerDialog）
- 1200px: テーブル付き（1件: StartingMemberDialog）

**共通コンポーネント適用状況:**

| コンポーネント | 適用済み | 未適用 |
|---------------|---------|-------|
| PageHeader | GamesView, GameRecordListView, StatsView, CompetitionsView, CardSetsView, StadiumsView, UsersView, CommissionerDashboardView | PlayerCardsView, PlayerDetailView, CostAssignment, ActiveRoster |
| DataCard | ManagerList, TeamList, PasswordChangeForm, Players, Settings各タブ | GamesView一部, SeasonPortal一部 |
| FilterBar | Players, GamesView, TeamMembers, GameRecordListView | PlayerCardsView, CompetitionsView |
| StatusChip | Players, PlayerDetailView, CommissionerDashboard | TeamMembers（一部独自チップ） |

---

## 2. 設計方針（軸1: 統一感 — カラー・スペーシング・タイポグラフィ）

### 2.1 Vuetify defaults 拡張

現在のdefaultsに以下を追加し、グローバルで統一する:

```typescript
defaults: {
  // 既存
  VDataTable: { density: 'compact', hover: true },
  VBtn: { variant: 'tonal' },
  VCard: { elevation: 1 },
  VTextField: { density: 'compact', variant: 'outlined' },
  VSelect: { density: 'compact', variant: 'outlined' },

  // 追加: ダイアログ統一
  VDialog: { scrollable: true },

  // 追加: チップ統一
  VChip: { size: 'small', variant: 'tonal' },

  // 追加: リスト統一
  VList: { density: 'compact' },

  // 追加: ツールチップ統一
  VTooltip: { location: 'bottom' },

  // 追加: スナックバー統一
  VSnackbar: { location: 'top', timeout: 3000 },

  // 追加: オートコンプリート統一
  VAutocomplete: { density: 'compact', variant: 'outlined' },

  // 追加: テキストエリア統一
  VTextarea: { density: 'compact', variant: 'outlined' },

  // 追加: タブ統一
  VTabs: { color: 'primary' },
}
```

### 2.2 カラーパレット方針

既存のカラーパレットは和色コンセプトが良好。追加/調整すべき点:

**a) base.cssの整理:**
- `--vt-c-*` 系CSS変数を削除（Vue Themeテンプレの残骸、Vuetifyテーマで代替済み）
- `--color-home`, `--color-visitor` はゲーム固有色として残す
- `--section-gap: 160px` は使用箇所を確認して不要なら削除

**b) Vuetifyテーマにゲーム固有色を追加:**
```typescript
colors: {
  // 既存色はそのまま
  // 追加: ゲーム固有色
  'game-home': '#2c5f2e',    // ホームチーム色（緑）
  'game-visitor': '#1B3A6B', // ビジターチーム色（藍）
  'game-win': '#C0392B',     // 勝利（朱 = accent）
  'game-lose': '#1B3A6B',    // 敗戦（藍 = primary）
  'game-draw': '#777777',    // 引分（灰）
}
```

**c) body font-family修正:**
- base.cssの`Zen Kaku Gothic New`をGoogle Fonts読み込みリストに追加するか、
- 読み込んでいない`Zen Kaku Gothic New`を削除してNoto Sans JPを先頭にする
- 推奨: `Zen Kaku Gothic New`を削除（design-guideにも記載なし、フォールバック動作）

### 2.3 タイポグラフィ・スペーシング方針

**タイポグラフィ:**
- 見出し: Shippori Mincho（App.vueのスタイルで適用済み） → 変更不要
- 本文・UI: Noto Sans JP → 変更不要
- 数値: JetBrains Mono → `.font-mono`クラスが定義済み → 統計テーブルで一貫して使用されているか確認が必要

**スペーシング統一:**
- ページコンテナ: `<v-container>` のVuetifyデフォルトを使用（変更不要）
- セクション間: `mb-4` を標準とする（現状 mb-2〜mb-6 がバラつき）
- カード内余白: VCard defaultsで統一済み
- PageHeader下: `mb-2`（PageHeader内部で設定済み） → `mb-4`に変更推奨（ヘッダーと本文の間隔が狭い）

---

## 3. 設計方針（軸2: ダイアログ・フォームパーツの洗練）

### 3.1 ダイアログサイズ規格の定義

5段階のサイズスケールを標準化:

| サイズ名 | max-width | 用途 | 例 |
|---------|-----------|------|----|
| xs | 400px | 確認・削除・短い選択 | ConfirmDialog |
| sm | 500px | 標準フォーム（3-5フィールド） | TeamDialog, CostDialog |
| md | 640px | 中規模フォーム（6+フィールド） | PlayerAbsenceFormDialog |
| lg | 900px | 大規模フォーム・詳細ビュー | PlayerDialog |
| xl | 1200px | テーブル付きダイアログ | StartingMemberDialog |

**実装:**
- 各ダイアログのmax-widthを規格値に統一（単位は常にpx付き）
- 現在の480は400pxに統合（軽微な差異）
- 現在の360は400pxに統合

### 3.2 ダイアログv-model統一

**推奨: defineModel（Vue 3.4+標準）に統一**

```typescript
// Before（3パターン混在）
// パターンA: computed getter/setter
const internalIsVisible = computed({ get: () => props.isVisible, set: (v) => emit(...) })
// パターンB: defineModel
const isOpen = defineModel({ type: Boolean, default: false })
// パターンC: props + emit
defineProps<{ modelValue: boolean }>()

// After（統一）
const isOpen = defineModel<boolean>({ default: false })
```

**対象ファイル（15件）:**
- パターンA→defineModel: ManagerDialog, TeamDialog, CostDialog, BattingStyleDialog, PitchingStyleDialog, BattingSkillDialog, PitchingSkillDialog, PlayerTypeDialog, BiorhythmDialog, ScheduleDialog
- パターンC→defineModel: PlayerDialog, StartingMemberDialog

### 3.3 persistent属性の統一

**ルール:**
- 確認ダイアログ（xs: 削除・実行確認）→ `persistent`
- フォームダイアログ（sm以上: 入力があるもの）→ `persistent`（入力途中での誤クローズ防止）
- 表示のみダイアログ → persistentなし

### 3.4 フォームフィールドのスタイル統一

Vuetify defaultsで基本は統一済み。追加で:

**a) v-form のバリデーション統一:**
- 全フォームダイアログで `v-form ref="formRef"` を使用
- 送信前に `formRef.value?.validate()` を呼ぶ

**b) ボタンパターン（現状統一済み — 維持）:**
```html
<v-card-actions>
  <v-spacer />
  <v-btn variant="text" @click="close">キャンセル</v-btn>
  <v-btn color="accent" variant="flat" @click="save" :disabled="!valid">保存</v-btn>
</v-card-actions>
```

### 3.5 実装単位の分割

| バッチ | 対象 | ファイル数 | 変更内容 |
|--------|------|-----------|---------|
| Batch 1 | vuetify.ts defaults拡張 + base.css整理 | 2 | defaults追加 + CSS変数削除 |
| Batch 2 | ダイアログmax-width統一 + persistent統一 | 15 | テンプレート属性変更のみ |
| Batch 3 | ダイアログv-model→defineModel統一 | 12 | script部分のリファクタ |

---

## 4. 設計方針（軸3: NavigationDrawer整理）

### 4.1 グルーピング案

現在のフラットなメニューを論理的にグループ化:

```
メインメニュー
├── ホーム                    [mdi-home]           /
│
├── 試合 ──────────────────── (グループ: 試合関連)
│   ├── ログ取り込み          [mdi-file-import]    /games/import
│   ├── レビュー              [mdi-clipboard-check] /game-records
│   └── 試合一覧              [mdi-scoreboard]     /games
│
├── チーム ─────────────────── (グループ: チーム関連)
│   ├── シーズン*             [mdi-calendar-star]   /teams/{id}/season
│   └── 成績                  [mdi-chart-bar]      /stats
│
├── 選手 ──────────────────── (グループ: 選手関連)
│   └── 選手カード            [mdi-card-account-details] /player-cards
│
── 管理（コミッショナーモード時） ───────────────
├── ダッシュボード            [mdi-view-dashboard]  /commissioner/dashboard
├── 大会管理                  [mdi-trophy-outline]  /commissioner/competitions
├── カードセット              [mdi-cards]           /commissioner/card_sets
├── 球場                      [mdi-stadium]         /commissioner/stadiums
├── 選手マスタ                [mdi-account]         /commissioner/players
├── 監督一覧                  [mdi-account-tie]     /managers
├── ユーザー管理              [mdi-account-cog]     /commissioner/users
│
── 外部リンク ─────────────────────────────────
└── 公式Wiki                  [mdi-baseball-diamond] (external)
```

### 4.2 実装方法

**v-list-subheader によるグルーピング:**

```html
<v-list nav density="compact">
  <!-- ホーム（単独） -->
  <v-list-item ... />

  <!-- 試合グループ -->
  <v-list-subheader v-if="!rail">試合</v-list-subheader>
  <v-list-item v-for="item in gameMenuItems" ... />

  <!-- チームグループ -->
  <v-list-subheader v-if="!rail">チーム</v-list-subheader>
  <v-list-item v-for="item in teamMenuItems" ... />

  <!-- 選手グループ -->
  <v-list-subheader v-if="!rail">選手</v-list-subheader>
  <v-list-item v-for="item in playerMenuItems" ... />
</v-list>
```

**ポイント:**
- `v-list-subheader` はrailモード時に非表示（`v-if="!rail"`）→ アイコンのみで十分
- v-list-groupによる折りたたみは不要（項目数が少ないため展開状態で十分）
- グループ間にはv-dividerは不要（subheaderで十分区別できる）

### 4.3 管理メニューの整理

現状の管理メニューは良好な構成。変更点:
- 「監督一覧」のパスが `/managers`（commissioner配下でない）→ `/commissioner/managers` に統一するか検討（ルーティング変更が必要なのでバックエンド側の対応も要）
- 現時点ではパスはそのまま、メニュー上のグルーピングのみ変更

### 4.4 変更量見積もり

- NavigationDrawer.vue: メニュー配列を3分割（game/team/player）+ テンプレートにsubheader追加
- 変更ファイル: 1ファイル（NavigationDrawer.vue）
- 影響範囲: UIのみ、ルーティング変更なし

---

## 5. 実装フェーズ分割案

### Phase A: 基盤整備（優先度: 高）

| サブタスク | 内容 | ファイル数 | 見積もり |
|-----------|------|-----------|---------|
| A-1 | vuetify.ts defaults拡張（VDialog, VChip, VList, VTooltip, VSnackbar, VAutocomplete, VTextarea, VTabs） | 1 | 小 |
| A-2 | base.css整理（--vt-c-*変数削除、font-family修正） | 1 | 小 |
| A-3 | Vuetifyテーマにゲーム固有色追加 | 1 | 小 |

**Phase A合計: 3サブタスク、3ファイル**

### Phase B: ダイアログ統一（優先度: 中）

| サブタスク | 内容 | ファイル数 | 見積もり |
|-----------|------|-----------|---------|
| B-1 | ダイアログmax-width規格化 + persistent統一 | 15 | 中（テンプレート属性のみ） |
| B-2 | ダイアログv-model→defineModel統一（バッチ1: settings系10件） | 10 | 中 |
| B-3 | ダイアログv-model→defineModel統一（バッチ2: その他5件） | 5 | 小 |

**Phase B合計: 3サブタスク、15ファイル（ユニーク）**

### Phase C: NavigationDrawer整理（優先度: 中）

| サブタスク | 内容 | ファイル数 | 見積もり |
|-----------|------|-----------|---------|
| C-1 | メニューグルーピング（subheader追加 + 配列分割） | 1 | 小 |

**Phase C合計: 1サブタスク、1ファイル**

### Phase D: 共通コンポーネント適用残り（優先度: 低）

| サブタスク | 内容 | ファイル数 | 見積もり |
|-----------|------|-----------|---------|
| D-1 | PageHeader未適用画面への適用 | 4 | 小 |
| D-2 | FilterBar未適用画面への適用 | 2 | 小 |

**Phase D合計: 2サブタスク、6ファイル**

### 推奨実行順序

```
Phase A（基盤） → Phase C（ナビ整理） → Phase B（ダイアログ） → Phase D（残適用）
```

**理由:**
- Phase Aはグローバル設定なので最初に入れる（後続の変更に影響）
- Phase Cは1ファイル変更で即効果あり、他と依存なし
- Phase Bは件数が多いがテンプレート変更主体で安全
- Phase Dは余力があれば（リリース前に必須ではない）

### 総サブタスク数: 9タスク / 影響ファイル数: 約25ファイル（ユニーク）

---

## 付録: 既存design-guide.mdとの関係

- `docs/design-guide.md` はカラーパレット・タイポグラフィ・ワイヤーフレーム等の**設計仕様書**
- 本ドキュメントは**現状分析と改善計画**
- 実装完了後、design-guide.mdの「Vuetifyカスタマイズ方針」セクションを更新することを推奨
