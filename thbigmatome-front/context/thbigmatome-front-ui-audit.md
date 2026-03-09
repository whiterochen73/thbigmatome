# thbigmatome-front UI課題洗い出し

**作成**: 軍師マキノ (subtask_468a / cmd_468)
**日付**: 2026-03-04
**対象**: SeasonPortal関連7画面

---

## 1. デザイントークン現状整理

### 1.1 Vuetifyテーマ定義（plugins/vuetify.ts）

| トークン | 値 | 和名 |
|---------|-----|------|
| `primary` | `#1B3A6B` | 藍色 |
| `secondary` | `#4A7A8A` | 千草色 |
| `accent` | `#C0392B` | 朱色 |
| `success` | `#5D8A2F` | 萌黄 |
| `warning` | `#D4940A` | 山吹 |
| `error` | `#B01C2A` | 紅 |
| `info` | `#2E86AB` | 浅葱 |
| `background` | `#F8F6F1` | 和紙色 |

### 1.2 グローバルデフォルト

```ts
VDataTable: { density: 'compact', hover: true }
VBtn:       { variant: 'tonal' }
VCard:      { elevation: 1 }
VTextField: { density: 'compact', variant: 'outlined' }
VSelect:    { density: 'compact', variant: 'outlined' }
```

### 1.3 CSS変数

- `base.css` に Vue テンプレートボイラープレート変数のみ（`--vt-c-*`）
- **プロジェクト固有のCSS変数は未定義**（`--ai`, `--moegi` 等なし）
- `#1b3a6b`（=primary）、`#2c5f2e`（≒success）がscoped CSS内にハードコードで散在

---

## 2. 画面ごとの課題リスト

### 2.1 SeasonPortal.vue

| # | 課題 | 優先度 | 詳細 |
|---|------|-------|------|
| SP-1 | `color="teal"` 離脱登録ボタン | 高 | テーマ未定義色。`secondary` か `info` に変更すべき |
| SP-2 | カレンダーscoped CSS全ハードコード | 中 | `#ccc`, `#555`, `#aaa`, `#f9f9f9`, `#e0f2f7`, `#ffebee`, `#fffde7`, `#ffeb3b` — テーマトークンやCSS変数を使っていない |
| SP-3 | スケジュール種別に `blue`, `deep-purple`, `pink` 等のraw Vuetify色 | 中 | テーマトークンに統一すべきか、明示的な色マッピングとして許容するか判断が必要 |
| SP-4 | 空カレンダー表示なし | 低 | season未取得時にカレンダーが空描画される。ローディング表示推奨 |
| SP-5 | レスポンシブ対応なし | 低 | CSS grid `repeat(7, 1fr)` でモバイル時の考慮なし |

### 2.2 SeasonRosterTab.vue

| # | 課題 | 優先度 | 詳細 |
|---|------|-------|------|
| SR-1 | `cols="6"` ハードコード（レスポンシブなし）| 高 | 1軍/2軍の2カラムが `cols="6"` 固定。モバイルで2つの狭いテーブルが並ぶ。`cols="12" md="6"` にすべき |
| SR-2 | ボタン `variant="elevated"` がグローバル `tonal` と不一致 | 中 | テーブル行内アクションボタンが独自variant。意図的ならOKだがパターン統一の検討を |
| SR-3 | `bg-deep-purple-lighten-5` 等のハイライト色 | 低 | キープレイヤー・離脱者等の行ハイライトにVuetifyユーティリティクラスを使用。テーマとの整合性は低いが機能的には問題なし |

### 2.3 SeasonAbsenceTab.vue

| # | 課題 | 優先度 | 詳細 |
|---|------|-------|------|
| SA-1 | `v-icon small` — 非推奨prop | 高 | Vuetify 3では `small` はdeprecated。`size="small"` に変更必須 |
| SA-2 | 編集/削除が bare `v-icon`（他は `v-btn` ラップ） | 中 | 他ファイルは `v-btn size="small"` でアイコンをラップ。操作性・スタイル統一のため `v-btn` に変更推奨 |
| SA-3 | `v-data-table class="elevation-1"` | 低 | classでelevation指定は非推奨パターン。v-cardでラップするかpropsで指定すべき |
| SA-4 | 追加ボタンにアイコンなし | 低 | 他画面のアクションボタンは `prepend-icon` 付き。統一推奨 |

### 2.4 GameResult.vue

| # | 課題 | 優先度 | 詳細 |
|---|------|-------|------|
| GR-1 | `v-toolbar color="orange-lighten-3"` | 高 | テーマ未定義色。SeasonPortalは `primary`。統一すべき |
| GR-2 | `color="light"` — 未定義色 | 高 | Vuetifyテーマに `light` は未定義。フォールバック動作になる。`default` か明示的な色に変更必須 |
| GR-3 | ボタン `variant="flat"` — グローバル `tonal` と不一致 | 中 | 意図的な選択か不明 |

### 2.5 ScoreSheet.vue

| # | 課題 | 優先度 | 詳細 |
|---|------|-------|------|
| SS-1 | `v-toolbar color="green"` | 高 | テーマ `success`（`#5D8A2F`）と異なる生のVuetify色。テーマトークンを使うべき |
| SS-2 | `color="light"` — 未定義色 | 高 | GameResult.vueと同じ問題 |
| SS-3 | scoped CSS大量ハードコード | 中 | `#e0e0e0`, `#fafafa`, `#424242` 等。スコアボード特有のため許容範囲だが、テーマ切替時に追従しない |
| SS-4 | `v-select variant="underlined"` | 低 | グローバル `outlined` と不一致。打撃結果入力用の小型セレクトとして意図的かもしれないが記録 |
| SS-5 | 空状態（starting members未登録時）表示なし | 中 | `v-if="startingMembers.length > 0"` でテーブル自体が消える。「先発メンバーを登録してください」メッセージがない |

### 2.6 GameImportView.vue

| # | 課題 | 優先度 | 詳細 |
|---|------|-------|------|
| GI-1 | `#1b3a6b`, `#2c5f2e` ハードコード | 中 | primary/success相当の値がscoped CSSに直書き。テーマ変更時に追従しない |
| GI-2 | `text-h4` ページタイトル | 低 | 他画面は `text-h5`。GameImportViewだけh4で不統一 |
| GI-3 | ツールバーなし | 低 | 他のシーズン系画面はv-toolbar使用。IRCログ系として差別化は妥当かもしれない |

**良い点**: レスポンシブ対応が7画面中最も充実（`cols="12" md="6"`, `sm="4"` 等使用）。他画面の参考になる。

### 2.7 GameRecordDetailView.vue

| # | 課題 | 優先度 | 詳細 |
|---|------|-------|------|
| GD-1 | `#1b3a6b`, `#2c5f2e` ハードコード | 中 | GameImportView.vueと同じパターン。home/visitor色がハードコード |
| GD-2 | `color="amber-darken-2"` — テーマ未定義 | 中 | bulk-confirmボタン/ダイアログ。テーマの `warning`（`#D4940A`）と似た意図だが別色 |
| GD-3 | Snackbar `timeout="2000"` `location="top"` | 低 | 他画面は `timeout="3000"`, location=bottom。統一推奨 |

**良い点**: 明示的なempty/not-found状態表示（`text-center py-8 text-grey`）。他画面の参考になる。

---

## 3. 横断的課題（優先度順）

### 高優先度

| # | 課題 | 影響範囲 | 対応案 |
|---|------|---------|--------|
| X-1 | ツールバー色の不統一 | 3画面 | SeasonPortal=primary、GameResult=orange-lighten-3、ScoreSheet=green。**全画面 `primary` に統一**推奨 |
| X-2 | `color="light"` 未定義色使用 | 2画面 | GameResult/ScoreSheet。テーマに存在しない色→ `variant="text"` か明示的な色に変更 |
| X-3 | テーマ外色のボタン使用 | 3画面 | `teal`, `light`, `green`, `orange-lighten-3` — テーマ8色に収束すべき |
| X-4 | SeasonRosterTab cols="6" モバイル崩れ | 1画面 | `cols="12" md="6"` に変更 |
| X-5 | SeasonAbsenceTab deprecated `v-icon small` | 1画面 | `size="small"` に移行 |

### 中優先度

| # | 課題 | 影響範囲 | 対応案 |
|---|------|---------|--------|
| X-6 | `#1b3a6b`/`#2c5f2e` ハードコード | 2画面 | home/visitor色をCSS変数化（`--color-home: rgb(var(--v-theme-success))` 等）またはVuetifyのテーマRGBユーティリティ使用 |
| X-7 | ボタンvariant不統一 | 全画面 | グローバル `tonal` に対してflat/elevated/outlined混在。方針決定が必要：アクション種別（primary/secondary/tertiary）ごとのvariantルールを策定 |
| X-8 | scoped CSS色ハードコード | 3画面 | SeasonPortal/ScoreSheet/GameRecordDetailViewのscoped CSSに生hex散在。テーマ切替対応するならCSS変数化必要 |
| X-9 | 空状態表示パターン未統一 | 4画面 | GameRecordDetailViewのパターン（`text-center py-8 text-grey`）を標準化して他に適用 |
| X-10 | Snackbar設定不統一 | 3画面 | timeout/location統一（推奨: timeout=3000, location=bottom） |

### 低優先度

| # | 課題 | 影響範囲 | 対応案 |
|---|------|---------|--------|
| X-11 | ページタイトルtypography | 1画面 | GameImportViewの `text-h4` → `text-h5` に統一 |
| X-12 | v-card elevation vs variant混在 | 全画面 | データ表示系=`variant="outlined"`、アクション系=デフォルト(elevation:1) で統一できているが明文化推奨 |
| X-13 | レスポンシブ対応不足 | 5画面 | GameImportView以外はブレークポイント未使用。段階的に対応 |

---

## 4. 統一テーマ提案

### 4.1 ボタンvariantルール案

| アクション種別 | variant | 例 |
|-------------|---------|---|
| Primary CTA | `variant="tonal"` (グローバルデフォルト) | 保存、実行、取り込み |
| Secondary | `variant="outlined"` | 戻る、リセット、キャンセル |
| Tertiary/ナビゲーション | `variant="text"` | 前/次、詳細リンク |
| Destructive | `variant="tonal" color="error"` | 削除 |
| Table row action | `variant="tonal" size="small"` | 昇格/降格、編集 |

### 4.2 ツールバー色ルール案

| 画面カテゴリ | ツールバー色 |
|------------|------------|
| シーズン運営系（SeasonPortal, GameResult, ScoreSheet） | `color="primary"` |
| IRCログ検証系（GameImportView, GameRecordDetailView） | ツールバーなし（現状維持） |

### 4.3 Home/Visitor色のCSS変数化案

```css
/* plugins/vuetify.ts のカスタムカラーに追加、またはbase.cssに定義 */
:root {
  --color-home: #2c5f2e;    /* ホーム緑（≒success） */
  --color-visitor: #1b3a6b; /* ビジター藍（=primary） */
}
```

これにより `GameImportView.vue` と `GameRecordDetailView.vue` のscoped CSSを変数参照に統一可能。

### 4.4 空状態コンポーネント案

```vue
<!-- components/EmptyState.vue -->
<template>
  <div class="text-center py-8 text-grey">
    <v-icon size="48" class="mb-2">{{ icon }}</v-icon>
    <p class="text-body-1">{{ message }}</p>
  </div>
</template>
```

GameRecordDetailViewのパターンをコンポーネント化し、全画面で統一使用。

---

## 5. 推奨実施順序

1. **X-1〜X-5（高優先度）**: ツールバー色統一、未定義色修正、レスポンシブ修正、deprecated prop修正 — 即時対応可能な小規模変更
2. **X-6〜X-10（中優先度）**: CSS変数化、variant統一ルール策定、空状態標準化 — 方針決定後に一括対応
3. **X-11〜X-13（低優先度）**: typography統一、elevation方針明文化、レスポンシブ拡充 — 段階的に対応
