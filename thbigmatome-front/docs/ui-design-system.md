# 汎用UIデザインセット設計書

**バージョン**: 1.0
**作成日**: 2026-03-14
**作成者**: 軍師マキノ (subtask_design_552a)
**関連**: design-guide.md（カラー・タイポグラフィ・ワイヤーフレーム）、cmd_468承認済みUIルール

> **改訂（2026-11-01, cmd_1791 段 0）**: §2（ページヘッダー）と §4-1〜4-4 は、画面の骨格を統一する設計（`context/thbig-dugout-ui-unification-design.md`）に合わせて書き換えた。本書の他の節（§1 のパターン分類・§3 の棚卸し・§5 以降）は作成当時（2026-03）の記述のままで、`PageHeader`・`v-toolbar` を使う前提が残っている。新しい画面は §2 の骨格に従う。

---

## 1. レイアウトパターン分類

全29 View（+ レガシー2件）を構造分析し、6つのレイアウトパターンに分類した。

### パターン一覧

| ID | パターン名 | 該当View数 | 特徴 |
|----|-----------|-----------|------|
| LP-1 | CRUD一覧 | 12 | v-container > v-card > v-data-table + Dialog |
| LP-2 | マルチカード | 4 | v-container > 複数v-card（セクション分割） |
| LP-3 | タブポータル | 3 | v-toolbar + v-tabs + v-tabs-window |
| LP-4 | 詳細（C 詳細） | 6 | `PageLayout` + `AsyncState` + バーへ宣言（独自の帯・戻るボタンなし）。LoginForm は含めない |
| LP-5 | デュアルカラム | 2 | v-row > v-col×2（1軍/2軍等の対比表示） |
| LP-6 | セレクションポータル | 1 | 中央寄せ単一カード + 選択UI |

---

### LP-1: CRUD一覧パターン（12件）

最も多いパターン。マスタ管理・一覧表示画面の標準形。

**該当View**: Players, TeamList, CostAssignment, ManagerList, CompetitionsView, UsersView, CardSetsView, StadiumsView

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
| フィルタ付き | v-select / v-text-field をカードタイトル内に配置 | Players |
| 展開行付き | show-expand + expanded-row slot | ManagerList |
| 読み取り専用 | 作成/編集ボタンなし | CardSetsView |

---

### LP-2: マルチカードパターン（4件）

複数のセクションを縦に積む構成。情報集約型画面。

**該当View**: GameResult, ScoreSheet

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

### LP-4: 詳細パターン（C 詳細。選手詳細・選手カード詳細・試合詳細・オーダー確認・パーサーレビュー詳細・大会ロスター）

個別性の高い詳細画面。画面独自の帯・戻るボタン・h1 は持たず、タイトルと戻り先はヘッダーバーへ宣言する（§2）。

**共通骨格**:
```vue
<PageLayout>
  <!-- 読み込み=スケルトン、失敗=アラート＋再読み込み、対象が無い=空状態 -->
  <AsyncState :loading="loading" :error="fetchFailed" :empty="!item" @retry="fetch">
    <v-card>
      <!-- 見出し行（任意）・セクション群 -->
    </v-card>
  </AsyncState>
</PageLayout>

<script setup lang="ts">
// 取得前・取得失敗でも戻れるよう、戻り先は常に宣言する（タイトルは取得後に対象の名前へ変わる）
useAppBarTitle(() => ({
  title: item.value?.name ?? '選手詳細',
  subtitle: item.value?.number ? `#${item.value.number}` : null,
  back: { to: '/players', label: '選手一覧' },
}))
</script>
```

戻り先は行き先固定の `router-link`（`router.back()` は使わない）。LoginForm はこのパターンに含めない（バーの外の画面）。

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

## 2. ページの骨格とタイトル

画面タイトルは**ヘッダーバー（AppBar）が持つ**。ページ本文に画面タイトルの見出し（`PageHeader`・素の h1・カード見出しの兼用）を置かない。設計の根拠と全体像は `context/thbig-dugout-ui-unification-design.md`。

### 2-1. 骨格（A〜E）

```
A ヘッダーバー（64px。スマホ 56px）  ☰ ・ ロゴ（PC のみ）・ [← 戻り先] ・ タイトル(h1) ・ サブタイトル ・ テーマ ・ アカウント
B タブ（任意）                     アイコン＋文字、高さ 44px、?tab= で保持
C ツールバー行（任意）              左=検索・絞り込み / 右=主ボタン 1 つ＋副ボタン
D コンテンツ                       カードを縦に積む（間隔 16px）。表はカードの中
E 状態                            読み込み=スケルトン / 空=EmptyState / 失敗=アラート＋再読み込み
```

- バーのタイトルは `<h1>` として `AppBar` が描く。本文の見出しは h2（カード見出し 16px・700）から始める
- ページ内の操作はバーに置かない。バーは「どこにいるか」とグローバル操作（ナビ・テーマ・アカウント）に限る
- ロゴは PC では残し、スマホ幅（<600px）では隠してタイトルを優先する（タイトルが無い画面ではロゴを出す）

### 2-2. 部品

| 部品 | 役割 |
|------|------|
| `useAppBarTitle`（`src/composables/useAppBarTitle.ts`） | 画面がタイトル・サブタイトル・戻り先（`{ title, subtitle?, back?: { to, label } }`）を宣言し、`AppBar` が描く。画面を離れる時に自動で解除する。宣言が無い画面は `route.meta.title` を出す（全ルートに付ける） |
| `PageLayout`（`src/components/shared/PageLayout.vue`） | ページの骨格。`width`: `narrow`（720）/ `default`（1080）/ `wide`（外枠 1440 まで）。スロット `lead`（タブより前の帯）/ `tabs` / `filters`・`actions`（ツールバー行の左右）/ 既定（コンテンツ）。左右余白 24px（スマホ 12px）、ブロック間 16px。中の `v-card` は縁 1px・影なしにする |
| `AsyncState`（`src/components/shared/AsyncState.vue`） | 読み込み中（内容が無ければスケルトン、あれば細い進捗線）・空（`EmptyState`）・失敗（アラート＋「再読み込み」）。読み込み中・失敗の間は空状態を出さない |
| `EmptyState` | 空状態（アイコン 40px＋文言＋あれば操作） |
| `RowIconButton`（`src/components/shared/RowIconButton.vue`） | 表の行の操作。名前（`aria-label`・`title`）を持つアイコンボタン。編集=`link`、削除=`danger-ink`、塗らない |
| `MasterPanel` / `MasterAddButton`（`src/components/settings/`） | 設定画面のマスタの行（アイコン・名前・件数・追加（枠）・開閉）をそろえる |

**埋め込める画面（`TeamMembers`）**: 単独の画面（`/teams/:teamId/members`）と、シーズンのタブ・試合日ページへの埋め込みの両方で使う画面は、`teamId` を props で受けたか（埋め込み）で分ける。単独の時だけ `PageLayout` とバーの宣言（チーム名・サブタイトル・戻り先「← シーズン」）を持ち、埋め込みの時はバーを変えず中身だけを出す（h1 は常に 1 つ）。

**集計画面**（数表が主役の画面。成績集計の画面は cmd_1795 で廃止したので、今は該当する画面が無い）は、アプリのテーマがダークでも明るい淡色背景に固定する。カードを `v-theme-provider theme="light"` で包む（文字色だけをテーマ追従にしない）。

`PageHeader` は**非推奨**。まだ移していない画面のために残してあり、ヘッダーバーが同じ題を出している間は本文の h1 を省く（バーと二重にならない）。全画面を移したら削除する。

### 2-3. タイトルの決め方（3 種類）

| 型 | タイトル | サブタイトル | 戻り先 | 例 |
|----|----------|--------------|--------|----|
| A 全体系 | 画面名 | 原則なし | なし | ホーム / 設定 / 選手一覧 / 監督一覧 / チーム一覧 / ユーザー管理 |
| B チーム配下 | チーム名 | 画面名（試合日は「Game 35 ・ 5月8日(日)」） | 親があれば「← シーズン」 | シーズン / 試合日 |
| C 詳細 | 対象の名前 | 補足（背番号・所属・日付） | 「← 一覧名」 | 選手詳細 / 試合詳細 |

手順: ① 1 つのチームに属する画面（`/teams/:teamId/…`）か → B ② 一覧の 1 件を開いた画面か → C ③ それ以外 → A（タイトルはナビに載っている名前に合わせる。ナビに無い画面は `route.meta.title`）。同じ画面の名前を 1 つに決める（ナビ名 = バータイトル = `route.meta.title`）。

### 2-4. 幅・余白・操作の置き場

| 項目 | 値 |
|------|----|
| 幅 | `narrow` 720 / `default` 1080 / `wide` 〜1440。画面側で `max-width` を書かず `PageLayout` の `width` で指定する |
| ページ余白 | 左右 24px（スマホ 12px）、上 20px。カード内 16px（スマホ 12px） |
| 主操作（追加・登録・保存・「今日の試合へ」） | ツールバー行の右端、`color="action" variant="flat"`＋動詞＋アイコン。**塗りの緑は 1 画面に 1 つまで** |
| 同格の「追加」が複数並ぶ画面（設定の各マスタ） | 枠ボタン（`variant="outlined"`、枠は `border-strong`、文字は `link`）＋プラス |
| 行の操作 | 表の右端の「操作」列に `RowIconButton`。3 つ以上ならメニュー |
| 戻る | バー左（`back`）。本文に戻るボタンを置かない |

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

**該当View**: Players (検索), PlayerCardsView (カードセット+種別+検索+表示切替), TeamMembers (ポジションフィルタ)

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

> 2026-11 の視覚リフレッシュ（役割色トークン B'・規則 R1〜R8、`context/thbig-dugout-visual-refresh-design.md`）と骨格の統一（§2）で、旧ルール（主操作=朱 `accent`、副操作=`tonal`、破壊的=`error` flat）は置き換わった。

| アクション種別 | variant | color | 用例 |
|--------------|---------|-------|------|
| Primary（主操作） | `flat` | `action`（緑） | 保存、追加、登録、「今日の試合へ」。1 画面に 1 つまで |
| Secondary（副操作） | `outlined`（枠は `border-strong`） | `link` | 取消、リセット、同格の「追加」が並ぶ時の各「追加」 |
| Destructive（破壊的） | 塗らない。`outlined`（枠・文字は `danger-ink`）またはアイコンボタン | `danger-ink` | 削除（ConfirmDialog 経由） |
| Navigation（遷移） | `text` | `link` | 詳細を見る |
| Icon（行の操作） | `text`（`RowIconButton`） | 編集=`link`、削除=`danger-ink` | テーブル内の編集/削除 |

**Vuetify defaults設定**: `VBtn: { variant: 'tonal' }`（variant を書かないボタンは塗りつぶしではない）。トークンを `color=` に渡す `v-btn`・`v-chip` は `variant="flat"` を明示する（tonal だと文字が淡色になる）。

### 4-2. ツールバー色

`AppBar`（ヘッダーバー）だけが `color="primary"`。ページ本文に `v-toolbar` を置かない（画面タイトルはバーが持つ。§2）。

### 4-3. 色の意味

`--color-home` / `--color-visitor` の CSS 変数は廃止した。ホーム側=`game-home`（藍）、ビジター側=`game-visitor`（鼠）をテーマトークンで使う。朱（`accent`）は主操作に使わない。赤は「負・要確認・削除」だけの意味に取っておき、カレンダーの日曜・土曜の文字や地に使わない（地色は `surface-variant`）。

### 4-4. 状態の出し方（EmptyState / AsyncState）

リスト系画面の読み込み・空・失敗は `AsyncState`（§2-2）で出す。

- 読み込みが終わってから空状態を出す（読み込み中に「〜がありません」を出さない）
- 空は `EmptyState`（アイコン＋「〜がありません」形式の文言＋あれば操作）
- 失敗は画面内のアラート＋「再読み込み」。保存の成否はスナックバー
- 2026-11-01 時点で `AsyncState` を使うのは選手一覧のみ。他の画面は段 2 以降で移す（以前の記述「全リスト系画面で EmptyState を使用」は実測では 1 画面だった）

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
3. 一般一覧系（Players, TeamList）
4. 複合系（CostAssignment）

### Phase 4: FilterBar + 高度な共通化

**スコープ**: FilterBar作成 + PlayerCardsView等のフィルタUI統一
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
| ManagerList | LP-1 | A | v-data-table (expand) | ManagerDialog | なし |
| Players | LP-1 | A | v-data-table | PlayerDialog | 検索 |
| PlayerDetailView | LP-4 | D | v-table | PlayerDialog | なし |
| TeamList | LP-1 | A | v-data-table | TeamDialog | なし |
| TeamMembers | LP-5 | A | v-data-table ×2 | なし | v-chip-group |
| SeasonPortal | LP-3 | B | 各タブ内 | 複数 | タブ |
| GameResult | LP-2 | B | v-table | StartingMemberDialog | なし |
| ScoreSheet | LP-2 | B | v-table | なし | なし |
| CostAssignment | LP-1 | A | v-data-table | なし | CostListSelect |
| Settings | LP-3 | A | GenericMaster内 | 各種Dialog | タブ |
| CompetitionRosterView | LP-3 | A | v-data-table (tabs) | なし | なし |
| PlayerCardsView | LP-1 | A | v-data-table / grid | なし | 複合フィルタ |
| PlayerCardDetailView | LP-4 | D | v-table + BattingTable | なし | なし |
| ActiveRoster | LP-5 | A | v-data-table ×2 | なし | なし |
| PlayerAbsenceHistory | LP-1 | なし | v-data-table | PlayerAbsenceFormDialog | なし |
| CompetitionsView | LP-1 | A | v-data-table | CompetitionDialog | なし |
| StadiumsView | LP-1 | A | v-data-table | StadiumDialog | なし |
| CardSetsView | LP-1 | A | v-data-table | なし | なし |
| UsersView | LP-1 | A | v-data-table | UserDialog | なし |

---

*この設計書はsrc/views/全29ファイル、src/components/全54ファイル、docs/配下の既存仕様書、cmd_468承認済みルールを直接参照して作成した。推測による記述はない。*
