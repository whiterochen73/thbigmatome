# 汎用UIデザインセット設計書

**バージョン**: 1.0
**作成日**: 2026-03-14
**作成者**: 軍師マキノ (subtask_design_552a)
**関連**: design-guide.md（カラー・タイポグラフィ・ワイヤーフレーム）、cmd_468承認済みUIルール

---

## 1. レイアウトパターン分類

全29 View（+ レガシー2件）を構造分析し、6つのレイアウトパターンに分類した。

### パターン一覧

| ID | パターン名 | 該当View数 | 特徴 |
|----|-----------|-----------|------|
| LP-1 | CRUD一覧 | 12 | v-container > v-card > v-data-table + Dialog |
| LP-2 | マルチカード | 5 | v-container > 複数v-card（セクション分割） |
| LP-3 | タブポータル | 3 | v-toolbar + v-tabs + v-tabs-window |
| LP-4 | カスタム詳細 | 3 | 独自CSS + ヘッダー帯 + セクション分割 |
| LP-5 | デュアルカラム | 2 | v-row > v-col×2（1軍/2軍等の対比表示） |
| LP-6 | セレクションポータル | 1 | 中央寄せ単一カード + 選択UI |

---

### LP-1: CRUD一覧パターン（12件）

最も多いパターン。マスタ管理・一覧表示画面の標準形。

**該当View**: Players, TeamList, GamesView, GameDetailView, StatsView, CostAssignment, GameRecordListView, ManagerList, CompetitionsView, UsersView, CardSetsView, StadiumsView

**共通骨格**:
```vue
<v-container>
  <!-- ページヘッダー -->
  <v-row>
    <v-col cols="12">
      <h1 class="text-h4 mb-4">{{ pageTitle }}</h1>
    </v-col>
  </v-row>

  <!-- メインカード -->
  <v-row>
    <v-col cols="12">
      <v-card>
        <v-card-title class="d-flex align-center">
          {{ sectionTitle }}
          <v-spacer />
          <!-- フィルタ or 作成ボタン -->
          <v-btn color="primary" prepend-icon="mdi-plus" @click="openCreate">
            {{ t('action.add') }}
          </v-btn>
        </v-card-title>
        <v-card-text>
          <v-data-table
            :headers="headers"
            :items="items"
            :loading="loading"
            density="compact"
            hover
          >
            <!-- カスタムカラムslot -->
            <template #[`item.actions`]="{ item }">
              <v-icon size="small" @click="edit(item)">mdi-pencil</v-icon>
              <v-icon size="small" class="ml-1" @click="confirmDelete(item)">mdi-delete</v-icon>
            </template>
          </v-data-table>
        </v-card-text>
      </v-card>
    </v-col>
  </v-row>

  <!-- CRUD Dialog -->
  <SomeDialog v-model="dialogVisible" :item="editItem" @save="onSave" />
  <ConfirmDialog ref="confirmRef" />
</v-container>
```

**バリエーション**:
| サブタイプ | 追加要素 | 例 |
|-----------|---------|-----|
| フィルタ付き | v-select / v-text-field をカードタイトル内に配置 | GamesView, Players |
| タブ切替付き | v-tabs でデータソース切替 | StatsView (打撃/投手/チーム) |
| 展開行付き | show-expand + expanded-row slot | ManagerList |
| 読み取り専用 | 作成/編集ボタンなし | CardSetsView |

---

### LP-2: マルチカードパターン（5件）

複数のセクションを縦に積む構成。情報集約型画面。

**該当View**: HomeView, GameImportView, GameRecordDetailView, GameResult, ScoreSheet

**共通骨格**:
```vue
<v-container>
  <!-- 上部フィルタ/コンテキスト -->
  <v-select v-model="filter" :items="options" class="mb-4" />

  <!-- セクション1 -->
  <v-card class="mb-4">
    <v-card-title>セクション1</v-card-title>
    <v-card-text>...</v-card-text>
  </v-card>

  <!-- セクション2 -->
  <v-card class="mb-4">
    <v-card-title>セクション2</v-card-title>
    <v-card-text>...</v-card-text>
  </v-card>

  <!-- セクション3（折りたたみ） -->
  <v-expansion-panels>
    <v-expansion-panel>
      <v-expansion-panel-title>詳細セクション</v-expansion-panel-title>
      <v-expansion-panel-text>...</v-expansion-panel-text>
    </v-expansion-panel>
  </v-expansion-panels>
</v-container>
```

---

### LP-3: タブポータルパターン（3件）

多機能なハブ画面。ツールバーヘッダー + タブナビゲーション。

**該当View**: SeasonPortal (6タブ), Settings (2タブ), CompetitionRosterView (2タブ)

**共通骨格**:
```vue
<v-container>
  <!-- ヘッダーツールバー -->
  <v-toolbar color="primary" class="mb-2">
    <v-toolbar-title>{{ portalTitle }}</v-toolbar-title>
    <v-spacer />
    <v-btn icon @click="goBack">
      <v-icon>mdi-close</v-icon>
    </v-btn>
  </v-toolbar>

  <!-- タブナビゲーション -->
  <v-tabs v-model="activeTab">
    <v-tab value="tab1">タブ1</v-tab>
    <v-tab value="tab2">タブ2</v-tab>
  </v-tabs>

  <!-- タブコンテンツ -->
  <v-tabs-window v-model="activeTab">
    <v-tabs-window-item value="tab1">
      <TabComponent1 />
    </v-tabs-window-item>
    <v-tabs-window-item value="tab2">
      <TabComponent2 />
    </v-tabs-window-item>
  </v-tabs-window>
</v-container>
```

---

### LP-4: カスタム詳細パターン（3件）

個別性の高い詳細画面。独自CSSでブランディング。

**該当View**: PlayerDetailView, PlayerCardDetailView, LoginForm

**共通骨格**:
```vue
<v-container>
  <!-- ヘッダー帯（カスタムCSS） -->
  <div class="detail-card-header">
    <v-btn icon="mdi-arrow-left" variant="text" @click="goBack" />
    <h1 class="text-h5">{{ title }}</h1>
    <v-spacer />
    <v-btn icon="mdi-pencil" @click="edit" />
  </div>

  <!-- コンテンツセクション群 -->
  <v-card class="mb-4">
    <v-card-title>基本情報</v-card-title>
    <v-card-text>
      <v-table density="compact">...</v-table>
    </v-card-text>
  </v-card>

  <v-card class="mb-4">
    <v-card-title>詳細データ</v-card-title>
    <v-card-text>...</v-card-text>
  </v-card>
</v-container>
```

---

### LP-5: デュアルカラムパターン（2件）

左右対比で2つのデータセットを表示。ロスター管理に特化。

**該当View**: ActiveRoster (1軍/2軍), TeamMembers (登録済み/未登録)

**共通骨格**:
```vue
<v-container>
  <v-row>
    <v-col cols="12" md="6">
      <v-card>
        <v-card-title>左カラム（例: 1軍）</v-card-title>
        <v-card-text>
          <v-data-table ... />
        </v-card-text>
      </v-card>
    </v-col>
    <v-col cols="12" md="6">
      <v-card>
        <v-card-title>右カラム（例: 2軍）</v-card-title>
        <v-card-text>
          <v-data-table ... />
        </v-card-text>
      </v-card>
    </v-col>
  </v-row>
</v-container>
```

---

### LP-6: セレクションポータルパターン（1件）

エントリポイント。最小限のUIで選択→遷移。

**該当View**: HomePortalView

**共通骨格**:
```vue
<v-container>
  <v-card max-width="480" class="mx-auto mt-8">
    <v-card-title>選択してください</v-card-title>
    <v-card-text>
      <v-select ... />
      <v-progress-circular v-if="loading" />
    </v-card-text>
  </v-card>
</v-container>
```

---

## 2. ページヘッダーパターン

現在4種のヘッダーパターンが混在している。統一方針を提案する。

### 現状分析

| パターン | 使用数 | 構造 | 使用例 |
|---------|-------|------|--------|
| A: h1 + Card Title | 12 | `<h1 class="text-h4">` → `<v-card-title>` | Players, TeamList |
| B: v-toolbar | 3 | `<v-toolbar color="primary">` | SeasonPortal |
| C: 戻るボタン | 2 | `<v-btn icon="mdi-arrow-left">` | GameDetailView |
| D: カスタムCSS | 3 | `.detail-card-header` | PlayerDetailView |

### 統一方針（提案）

**原則**: 既存画面のデザインを維持しつつ、新規画面では以下のルールを適用する。

| 画面タイプ | 推奨ヘッダー | 理由 |
|-----------|------------|------|
| CRUD一覧 (LP-1) | パターンA（h1 + Card Title） | シンプルで十分 |
| マルチカード (LP-2) | パターンA or B（規模による） | 小規模=A, 大規模=B |
| タブポータル (LP-3) | パターンB（v-toolbar） | タブとの視覚的連続性 |
| 詳細画面 (LP-4) | パターンD（カスタムヘッダー） | ブランディング要素 |
| デュアルカラム (LP-5) | パターンA | 一覧系の派生 |

---

## 3. 共通コンポーネント棚卸し

### 3-1. 既存共通コンポーネントの再利用状況

| コンポーネント | 用途 | 使用箇所数 | 評価 |
|--------------|------|-----------|------|
| `EmptyState.vue` | 空状態表示 | 5+ | ✅ 十分に活用されている |
| `ConfirmDialog.vue` | 削除確認 | 8+ | ✅ 広く活用 |
| `TeamNavigation.vue` | チームタブナビ | 2 | ✅ 適切なスコープ |
| `GenericMasterSettings.vue` | マスタCRUD | 6 | ✅ 優秀な汎用化 |
| shared/TeamSelect | チーム選択 | 2 | ✅ 適切 |
| shared/PlayerSelect | 選手選択 | 3 | ✅ 適切 |
| shared/PlayerDetailSelect | 選手詳細選択 | 1 | △ 使用箇所が少ない |
| shared/TeamMemberSelect | チームメンバー選択 | 1 | △ 使用箇所が少ない |
| shared/CostListSelect | コスト表選択 | 1 | △ 使用箇所が少ない |

### 3-2. View内に埋まっている共通化すべきパターン

以下のパターンが複数のViewに繰り返し出現しており、共通コンポーネント化の候補となる。

#### 提案1: `PageHeader.vue`（新規）

**問題**: 12件のLP-1画面で `<h1 class="text-h4 mb-4">` + 戻るボタン有無のパターンが個別実装されている。

**提案コンポーネント**:
```vue
<!-- src/components/shared/PageHeader.vue -->
<template>
  <v-row class="mb-2">
    <v-col cols="12" class="d-flex align-center">
      <v-btn
        v-if="backTo"
        icon="mdi-arrow-left"
        variant="text"
        :to="backTo"
        class="mr-2"
      />
      <h1 class="text-h4">{{ title }}</h1>
      <v-spacer />
      <slot name="actions" />
    </v-col>
  </v-row>
</template>
```

**props**: `title: string`, `backTo?: string | RouteLocationRaw`
**slot**: `actions` — 右端にボタン等を配置

**影響範囲**: LP-1全12件 + LP-2の一部 + LP-5の2件 = 約16件

---

#### 提案2: `DataCard.vue`（新規）

**問題**: v-card + v-card-title(d-flex) + v-spacer + action button + v-card-text のパターンが15件以上で繰り返されている。

**提案コンポーネント**:
```vue
<!-- src/components/shared/DataCard.vue -->
<template>
  <v-card>
    <v-card-title class="d-flex align-center">
      <span>{{ title }}</span>
      <v-spacer />
      <slot name="title-actions" />
    </v-card-title>
    <v-card-text>
      <slot />
    </v-card-text>
    <slot name="footer" />
  </v-card>
</template>
```

**props**: `title: string`
**slot**: default（メインコンテンツ）、`title-actions`（右端ボタン）、`footer`（カード下部）

---

#### 提案3: `FilterBar.vue`（新規）

**問題**: 検索テキストフィールド + ドロップダウンフィルタ + トグルボタンのパターンが6件で個別実装。

**提案コンポーネント**:
```vue
<!-- src/components/shared/FilterBar.vue -->
<template>
  <v-row class="mb-2" dense>
    <v-col v-if="$slots.search" cols="12" sm="4">
      <slot name="search" />
    </v-col>
    <v-col v-if="$slots.filters">
      <slot name="filters" />
    </v-col>
    <v-col v-if="$slots.toggles" class="d-flex justify-end">
      <slot name="toggles" />
    </v-col>
  </v-row>
</template>
```

**該当View**: Players (検索), PlayerCardsView (カードセット+種別+検索+表示切替), GamesView (大会+日付範囲), TeamMembers (ポジションフィルタ), GameRecordListView (ステータスフィルタ), StatsView (大会選択)

---

#### 提案4: `ActionIcons.vue`（新規）

**問題**: v-data-tableのactions列で `v-icon size="small"` + `mdi-pencil` / `mdi-delete` / `mdi-eye` のパターンが10件以上で重複。

**提案コンポーネント**:
```vue
<!-- src/components/shared/ActionIcons.vue -->
<template>
  <span class="d-inline-flex ga-1">
    <v-icon v-if="showView" size="small" @click="$emit('view')" title="詳細">mdi-eye</v-icon>
    <v-icon v-if="showEdit" size="small" @click="$emit('edit')" title="編集">mdi-pencil</v-icon>
    <v-icon v-if="showDelete" size="small" @click="$emit('delete')" title="削除">mdi-delete</v-icon>
    <slot />
  </span>
</template>
```

**props**: `showView`, `showEdit`, `showDelete`（boolean、default=false）

---

#### 提案5: `StatusChip.vue`（新規）

**問題**: v-chip + color + size="small" + variant="tonal" のステータス表示パターンが13件で重複。色の決定ロジックも分散している。

**提案コンポーネント**:
```vue
<!-- src/components/shared/StatusChip.vue -->
<template>
  <v-chip
    :color="resolvedColor"
    :size="size"
    variant="tonal"
  >
    <slot>{{ label }}</slot>
  </v-chip>
</template>
```

**props**: `status: string`（定義済みステータス名）, `label?: string`, `size?: string`
**ステータス→色マッピング**:
```ts
const statusColorMap: Record<string, string> = {
  active: 'success',
  inactive: 'default',
  commissioner: 'primary',
  hachinai: 'purple',
  warning: 'warning',
  injury: 'error',
  cooldown: 'info',
}
```

---

### 3-3. 共通化の優先度

| 優先度 | コンポーネント | 理由 |
|-------|--------------|------|
| **HIGH** | PageHeader | 16件に影響。統一性向上の効果が最大 |
| **HIGH** | DataCard | 15件以上に影響。コード削減量が最大 |
| **MEDIUM** | FilterBar | 6件に影響。slot設計で柔軟性を確保 |
| **MEDIUM** | StatusChip | 13件の色ロジック統一。保守性向上 |
| **LOW** | ActionIcons | 10件に影響だが、v-data-tableのslotから呼ぶため効果は限定的 |

---

## 4. cmd_468承認済みUIデザインルール統合

以下はP承認済み（2026-03-04）のルール。デザインセットに組み込む。

### 4-1. ボタンvariantルール

| アクション種別 | variant | color | 用例 |
|--------------|---------|-------|------|
| Primary（主操作） | `flat` | `accent` (#C0392B) | 保存、作成、インポート |
| Secondary（副操作） | `tonal` | デフォルト | キャンセル、リセット |
| Destructive（破壊的） | `flat` | `error` | 削除（ConfirmDialog経由） |
| Navigation（遷移） | `text` | `primary` | 戻る、詳細を見る |
| Icon（アイコン操作） | `text` | — | テーブル内の編集/削除アイコン |

**Vuetify defaults設定**:
```ts
defaults: {
  VBtn: { variant: 'tonal' },  // デフォルトはtonal（Secondary）
}
```

### 4-2. ツールバー色 = primary統一

```vue
<!-- 全てのv-toolbarはcolor="primary" -->
<v-toolbar color="primary">
```

**適用箇所**: AppBar、SeasonPortalヘッダー、チームナビゲーションヘッダー

### 4-3. CSS変数 --color-home / --color-visitor

```css
:root {
  --color-home: #1B3A6B;    /* 藍色 = primary */
  --color-visitor: #C0392B;  /* 朱色 = accent */
}
```

**適用箇所**: Scoreboard.vue、GameResult.vue、GameDetailView.vue のチーム色表示

### 4-4. EmptyState コンポーネント

既存の `EmptyState.vue` を全リスト系画面の空状態に統一使用する。

**ルール**:
- `v-data-table` の `:items` が空の場合、テーブル内またはテーブル代替として `<EmptyState>` を表示
- icon は画面コンテキストに合ったMDIアイコンを使用
- message は「〜がありません」形式で統一

---

## 5. ダイアログ設計パターン

### 5-1. 現状の標準パターン

全CRUDダイアログに共通する構造:

```vue
<v-dialog v-model="visible" max-width="500px" persistent>
  <v-card>
    <v-card-title>
      {{ isEdit ? '編集' : '新規作成' }}
    </v-card-title>
    <v-card-text>
      <v-container>
        <v-row>
          <v-col cols="12">
            <v-text-field v-model="form.name" label="名前" />
          </v-col>
        </v-row>
      </v-container>
    </v-card-text>
    <v-card-actions>
      <v-spacer />
      <v-btn variant="text" @click="close">キャンセル</v-btn>
      <v-btn color="accent" variant="flat" @click="save" :loading="saving">保存</v-btn>
    </v-card-actions>
  </v-card>
</v-dialog>
```

### 5-2. ダイアログサイズガイドライン

| 用途 | max-width | 例 |
|------|-----------|-----|
| シンプルフォーム（1-3フィールド） | 500px | BattingStyleDialog |
| 中規模フォーム（4-8フィールド） | 600px | TeamDialog, ManagerDialog |
| 複雑なフォーム | 800px | StartingMemberDialog |
| 確認ダイアログ | 400px | ConfirmDialog |

---

## 6. データテーブル標準設定

### 共通props

```vue
<v-data-table
  :headers="headers"
  :items="items"
  :loading="loading"
  density="compact"
  hover
  items-per-page="50"
>
```

### ヘッダー定義規約

```ts
const headers = [
  { title: t('column.name'), key: 'name', sortable: true },
  { title: t('column.actions'), key: 'actions', sortable: false, width: '100px' },
]
```

- `title` は必ず `t()` (i18n) を使用
- `actions` 列は `sortable: false` + 固定幅
- 数値列は `align: 'end'`

---

## 7. 段階的適用フェーズ

既存画面の大幅な作り直しは行わず、段階的にパターンを適用する。

### Phase 1: 共通コンポーネント作成（新規のみ）

**スコープ**: PageHeader, DataCard, StatusChip の3コンポーネントを作成
**工数目安**: 足軽1名 × 1タスク
**影響**: 既存画面は変更しない。新規画面から使い始める

**成果物**:
- `src/components/shared/PageHeader.vue`
- `src/components/shared/DataCard.vue`
- `src/components/shared/StatusChip.vue`
- 各コンポーネントの型定義

### Phase 2: cmd_468ルール適用（ボタン・ツールバー統一）

**スコープ**: 既存画面のボタンvariantとツールバー色を統一
**工数目安**: 足軽1名 × 2-3タスク（画面数が多いためバッチ処理）
**影響**: 視覚的な変更あり。機能変更なし

**対象**:
1. v-btn の variant/color を標準ルールに合わせる（約20箇所）
2. v-toolbar の color を primary に統一（3箇所）
3. CSS変数 --color-home / --color-visitor の適用（3箇所）

### Phase 3: 既存画面のパターン適用（段階的リファクタ）

**スコープ**: LP-1画面から順にPageHeader/DataCardを適用
**工数目安**: 足軽1名 × 4-6タスク（3-4画面/タスク）
**影響**: コード構造変更あり。見た目の変化は最小限

**適用順序**（依存度が低い画面から）:
1. コミッショナー系4画面（CompetitionsView, StadiumsView, CardSetsView, UsersView）
2. マスタ系（ManagerList, Settings内の各タブ）
3. 一般一覧系（Players, TeamList, GamesView, GameRecordListView）
4. 複合系（CostAssignment, StatsView）

### Phase 4: FilterBar + 高度な共通化

**スコープ**: FilterBar作成 + PlayerCardsView/GamesView等のフィルタUI統一
**工数目安**: 足軽1名 × 2タスク
**前提**: Phase 3完了後

---

## 8. 適用しないもの（スコープ外）

以下は意図的にスコープ外とする:

| 項目 | 理由 |
|------|------|
| SeasonPortal全体の再設計 | 最も複雑なView。安定稼働を優先 |
| PlayerCardDetailView/PlayerDetailViewのCSS統一 | ブランディング要素が強く、個別性が必要 |
| LoginFormのリデザイン | 使用頻度が低く、現状で機能的に十分 |
| GameResult/ScoreSheetの構造変更 | 試合入力は将来的に拡張予定（cmd_535設計書参照）。先に拡張してからリファクタすべき |

---

## 付録A: 全View分類マッピング

| View | パターン | ヘッダー | テーブル | ダイアログ | フィルタ |
|------|---------|---------|---------|-----------|--------|
| LoginForm | LP-6変形 | なし | なし | なし | なし |
| HomePortalView | LP-6 | なし | なし | なし | v-select |
| HomeView | LP-2 | A | なし | なし | v-select |
| ManagerList | LP-1 | A | v-data-table (expand) | ManagerDialog | なし |
| Players | LP-1 | A | v-data-table | PlayerDialog | 検索 |
| PlayerDetailView | LP-4 | D | v-table | PlayerDialog | なし |
| TeamList | LP-1 | A | v-data-table | TeamDialog | なし |
| TeamMembers | LP-5 | A | v-data-table ×2 | なし | v-chip-group |
| SeasonPortal | LP-3 | B | 各タブ内 | 複数 | タブ |
| GameResult | LP-2 | B | v-table | StartingMemberDialog | なし |
| ScoreSheet | LP-2 | B | v-table | なし | なし |
| GamesView | LP-1 | A | v-data-table | なし | v-select + 日付 |
| GameImportView | LP-2 | A | なし | なし | v-select |
| GameDetailView | LP-1変形 | C | v-table | なし | なし |
| GameLineupView | LP-1変形 | C | v-table | なし | なし |
| StatsView | LP-1 | A | v-data-table (tabs) | なし | v-select |
| CostAssignment | LP-1 | A | v-data-table | なし | CostListSelect |
| Settings | LP-3 | A | GenericMaster内 | 各種Dialog | タブ |
| CompetitionRosterView | LP-3 | A | v-data-table (tabs) | なし | なし |
| PlayerCardsView | LP-1 | A | v-data-table / grid | なし | 複合フィルタ |
| PlayerCardDetailView | LP-4 | D | v-table + BattingTable | なし | なし |
| GameRecordListView | LP-1 | A | v-data-table | なし | v-chip-group |
| GameRecordDetailView | LP-2 | A | なし | なし | v-chip-group |
| ActiveRoster | LP-5 | A | v-data-table ×2 | なし | なし |
| PlayerAbsenceHistory | LP-1 | なし | v-data-table | PlayerAbsenceFormDialog | なし |
| CompetitionsView | LP-1 | A | v-data-table | CompetitionDialog | なし |
| StadiumsView | LP-1 | A | v-data-table | StadiumDialog | なし |
| CardSetsView | LP-1 | A | v-data-table | なし | なし |
| UsersView | LP-1 | A | v-data-table | UserDialog | なし |

---

*この設計書はsrc/views/全29ファイル、src/components/全54ファイル、docs/配下の既存仕様書、cmd_468承認済みルールを直接参照して作成した。推測による記述はない。*
