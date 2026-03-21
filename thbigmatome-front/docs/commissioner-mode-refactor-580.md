# コミッショナーモード廃止・ホーム画面内切替 設計書 (cmd_580)

## 1. P決定事項

- AppBarのコミッショナーモードトグル（盾アイコン）を**撤去**
- `commissionerModeStore`を**完全廃止**
- HomePortalViewに「自チーム」「全チーム管理」「ダッシュボード」のタブ切替UIを追加
- 非コミッショナーにはタブUIを表示しない

## 2. commissionerModeStore参照箇所の全件リスト

### ソースファイル（6件）

| # | ファイル | 参照内容 | 廃止後の代替 |
|---|---------|---------|------------|
| 1 | `stores/commissionerMode.ts` | Store定義本体 | **ファイル削除** |
| 2 | `components/AppBar.vue` | toggle(), isCommissionerMode（トグルボタン） | **トグルボタン撤去**、import削除 |
| 3 | `components/NavigationDrawer.vue` | showCommissionerMenu, showTeamMenu | `isCommissioner`のみで判定（後述） |
| 4 | `views/HomePortalView.vue` | v-if分岐, watch, onMounted | **タブUIに全面書き換え**（後述） |
| 5 | `stores/teamSelection.ts` | availableTeams computed | **availableTeams computed削除**（後述） |
| 6 | `composables/useAuth.ts` | initializeUserState（auto setMode）, logout（setMode(false) + localStorage.removeItem） | auto setMode削除、logout cleanup削除 |

### テストファイル（4件）

| # | ファイル | 変更内容 |
|---|---------|---------|
| 7 | `composables/__tests__/useAuth.spec.ts` | commissionerMode mock削除、auto setMode関連テスト削除 |
| 8 | `views/__tests__/HomePortalView.spec.ts` | タブUI用テストに全面書き換え |
| 9 | `components/__tests__/AppBar.spec.ts` | toggleCommissionerMode テスト削除 |
| 10 | `layouts/__tests__/DefaultLayout.spec.ts` | localStorage commissionerMode操作を削除 |

### その他（1件）

| # | ファイル | 変更内容 |
|---|---------|---------|
| 11 | `locales/ja.json` | `commissionerMode`セクション削除 |

**合計: 11ファイル変更（うち1ファイル削除）**

## 3. 設計方針: 完全廃止

### 3.1 なぜ「ローカル状態縮小」ではなく「完全廃止」か

| 案 | 概要 | 評価 |
|----|------|------|
| A. 完全廃止 | commissionerModeStoreを削除。コミッショナー判定はすべて`isCommissioner`（ロール判定）のみ。表示切替はHomePortalViewのローカルタブ状態 | **推奨** |
| B. ローカル状態縮小 | Piniaストア→HomePortalView内のrefに縮小 | 不要な複雑さが残る。他コンポーネントがimportする理由がない |

**推奨: 案A（完全廃止）**

理由:
- 「モード」という概念自体が混乱の原因だった（Pの判断）
- コミッショナーは常にコミッショナー。モードのON/OFFは不要
- 管理メニューは常時表示、ホーム画面のタブでコンテキスト切替

### 3.2 各コンポーネントの代替ロジック

#### (a) NavigationDrawer — メニュー表示条件

**現在:**
```typescript
const showCommissionerMenu = computed(
  () => isCommissioner.value && commissionerModeStore.isCommissionerMode,
)
const showTeamMenu = computed(() => {
  if (commissionerModeStore.isCommissionerMode) return true
  return !teamSelectionStore.teamsLoaded || teamSelectionStore.hasTeam
})
```

**変更後:**
```typescript
// コミッショナーなら管理メニュー常時表示（モード不要）
const showCommissionerMenu = computed(() => isCommissioner.value)

// コミッショナーならチームメニュー常時表示（全チーム代理管理）
const showTeamMenu = computed(() => {
  if (isCommissioner.value) return true
  return !teamSelectionStore.teamsLoaded || teamSelectionStore.hasTeam
})
```

`commissionerModeStore`のimportを削除。

#### (b) AppBar — トグルボタン撤去

**現在:**
```html
<v-btn v-if="showModeToggle" icon variant="text" @click="toggleCommissionerMode" ...>
```

**変更後:** このv-btn全体を削除。関連するcomputed/function/importもすべて削除。

#### (c) teamSelection.ts — availableTeams computed

**現在:**
```typescript
const availableTeams = computed(() => {
  const cmStore = useCommissionerModeStore()
  return cmStore.isCommissionerMode ? allTeams.value : myTeams.value
})
```

**変更後:** `availableTeams` computedを**削除**。

理由: 「どのチーム一覧を使うか」はもはやグローバル状態ではなく、HomePortalViewのタブ選択に依存する。
- 「自チーム」タブ → `teamSelectionStore.myTeams`を直接参照
- 「全チーム管理」タブ → `teamSelectionStore.allTeams`を直接参照

`allTeams`, `allTeamsLoaded`, `setAllTeams`, `resetTeams`はそのまま維持（initializeUserStateで使用）。
`commissionerMode`のimportを削除。

#### (d) useAuth.ts — initializeUserState / logout

**現在のinitializeUserState:**
```typescript
// コミッショナー: 全チーム取得
if (isCommissioner.value && !teamStore.allTeamsLoaded) { ... }
// チーム未所持コミッショナー → 自動でcommissionerMode ON
if (isCommissioner.value && teamStore.teamsLoaded && !teamStore.hasTeam) {
  useCommissionerModeStore().setMode(true)
}
```

**変更後:**
```typescript
// コミッショナー: 全チーム取得（維持 — タブ用データ）
if (isCommissioner.value && !teamStore.allTeamsLoaded) { ... }
// ↓ 削除: auto setMode はもう不要
// if (isCommissioner.value && ...) { useCommissionerModeStore().setMode(true) }
```

**現在のlogout:**
```typescript
useCommissionerModeStore().setMode(false)
localStorage.removeItem('commissionerMode')
```

**変更後:** 上記2行を削除。commissionerModeのimport削除。

### 3.3 HomePortalView — 新タブUI設計

#### UIパターン

```
[コミッショナーの場合]
┌─ タブ ──────────────────────────────────────────┐
│ [自チーム]  [全チーム管理]  [ダッシュボード]      │
└─────────────────────────────────────────────────┘

「自チーム」タブ:
  ├─ チーム0件 → EmptyState（既存）
  ├─ チーム1件 → SeasonPortal直接表示（既存）
  └─ チーム2件 → v-tabs切り替え（既存）

「全チーム管理」タブ:
  ├─ v-select: 全チームから選択
  └─ SeasonPortal: 選択チームの情報

「ダッシュボード」タブ:
  └─ CommissionerDashboardView の内容を埋め込み
     （離脱者一覧・コスト状況・クールダウン）

[非コミッショナーの場合]
  タブなし → 既存のmyTeams表示ロジックがそのまま動作
```

#### コミッショナーがチーム未所持の場合

- 「自チーム」タブ: EmptyState表示（「チームが割り当てられていません」）
- **初期タブ**: `全チーム管理`（チーム未所持ならこちらが自然）

#### 実装イメージ

```vue
<template>
  <v-container>
    <!-- コミッショナー用タブ -->
    <v-tabs v-if="isCommissioner" v-model="activeTab" color="primary" class="mb-4">
      <v-tab value="myTeams">自チーム</v-tab>
      <v-tab value="allTeams">全チーム管理</v-tab>
      <v-tab value="dashboard">ダッシュボード</v-tab>
    </v-tabs>

    <v-window v-if="isCommissioner" v-model="activeTab">
      <!-- 自チーム -->
      <v-window-item value="myTeams">
        <!-- 既存のmyTeamsロジック（0件/1件/2件以上） -->
      </v-window-item>

      <!-- 全チーム管理 -->
      <v-window-item value="allTeams">
        <v-select v-model="selectedAllTeamId" :items="allTeams" item-title="name" item-value="id" label="チームを選択" class="mb-2" />
        <SeasonPortal v-if="selectedAllTeamId" :key="selectedAllTeamId" :team-id="selectedAllTeamId" />
      </v-window-item>

      <!-- ダッシュボード -->
      <v-window-item value="dashboard">
        <CommissionerDashboard />
      </v-window-item>
    </v-window>

    <!-- 非コミッショナー: 既存表示 -->
    <template v-else>
      <!-- 既存のmyTeamsロジック（変更なし） -->
    </template>
  </v-container>
</template>
```

#### CommissionerDashboardの埋め込み方針

2つの選択肢:

| 案 | 概要 | 評価 |
|----|------|------|
| A. コンポーネント抽出 | CommissionerDashboardView.vueからロジック部分を`CommissionerDashboard.vue`コンポーネントとして抽出し、HomePortalViewにimport | **推奨** |
| B. そのまま埋め込み | HomePortalViewにダッシュボードのコード全体をコピー | ファイルが肥大化、DRY違反 |

**推奨: 案A** — CommissionerDashboardView.vueを以下に分離:
- `components/commissioner/CommissionerDashboard.vue` — 表示ロジック（再利用可能コンポーネント）
- `views/commissioner/CommissionerDashboardView.vue` — ルーティング用wrapper（`<CommissionerDashboard />`を表示するだけ）

これにより:
- HomePortalViewのタブからも`<CommissionerDashboard />`を使える
- `/commissioner/dashboard`ルートも引き続き動作
- コード重複なし

### 3.4 ルーティングへの影響

- `/commissioner/dashboard` ルート: **維持**（CommissionerDashboardView.vueは残す）
- NavigationDrawerの管理メニューから直接遷移可能なまま
- HomePortalViewのタブからも同じ内容が見える（コンポーネント共有）

## 4. 実装フェーズ分割

### Phase 1: commissionerModeStore廃止 + 参照箇所修正（FE 5ファイル）

1. `stores/commissionerMode.ts` → **削除**
2. `components/AppBar.vue` → トグルボタン撤去、import削除
3. `components/NavigationDrawer.vue` → showCommissionerMenu/showTeamMenu を isCommissioner のみに変更、import削除
4. `stores/teamSelection.ts` → availableTeams computed削除、commissionerMode import削除
5. `composables/useAuth.ts` → auto setMode削除、logout cleanup削除、import削除

テスト更新:
- `AppBar.spec.ts` → toggleテスト削除
- `useAuth.spec.ts` → commissionerMode mock/テスト削除
- `DefaultLayout.spec.ts` → localStorage commissionerMode操作削除

**サブタスク数**: 1（ストア削除+参照修正は密結合のため分離不可）

### Phase 2: HomePortalViewタブUI + CommissionerDashboard抽出（FE 3ファイル）

1. `components/commissioner/CommissionerDashboard.vue` → 新規作成（既存CommissionerDashboardViewから抽出）
2. `views/commissioner/CommissionerDashboardView.vue` → wrapper化（`<CommissionerDashboard />`を表示）
3. `views/HomePortalView.vue` → タブUI実装（自チーム/全チーム管理/ダッシュボード）

テスト更新:
- `HomePortalView.spec.ts` → タブUIテストに書き換え
- `CommissionerDashboardView.spec.ts` → 必要に応じて調整

**サブタスク数**: 1-2

### Phase 3: クリーンアップ（FE 1ファイル + 確認）

1. `locales/ja.json` → commissionerModeセクション削除
2. localStorage `commissionerMode` キーの残留確認（既存ユーザーのブラウザに残るが無害）
3. 全テスト実行確認

**サブタスク数**: 1（Phase 2と統合可能）

### 合計見積り: 2-3サブタスク

## 5. 変更対象ファイル一覧

| ファイル | Phase | 変更内容 |
|---------|-------|---------|
| `src/stores/commissionerMode.ts` | 1 | **削除** |
| `src/components/AppBar.vue` | 1 | トグルボタン撤去 |
| `src/components/NavigationDrawer.vue` | 1 | isCommissionerのみで判定 |
| `src/stores/teamSelection.ts` | 1 | availableTeams削除 |
| `src/composables/useAuth.ts` | 1 | auto setMode・logout cleanup削除 |
| `src/components/commissioner/CommissionerDashboard.vue` | 2 | **新規**（抽出） |
| `src/views/commissioner/CommissionerDashboardView.vue` | 2 | wrapper化 |
| `src/views/HomePortalView.vue` | 2 | タブUI実装 |
| `src/locales/ja.json` | 3 | commissionerModeセクション削除 |
| テスト4件 | 1-2 | 上述 |

**BE変更: なし**

## 6. リスクと注意点

1. **Phase 1の原子性**: commissionerModeStore削除は参照箇所すべてを同時修正しないとビルドエラーになる。1サブタスクで一括変更が必須
2. **CommissionerDashboard抽出**: 現在のCommissionerDashboardView.vue（390行）からの抽出は機械的だが、v-containerの入れ子に注意
3. **既存localStorage**: ユーザーのブラウザに`commissionerMode`キーが残るが、参照するコードがなくなるため無害。能動的な削除は不要
4. **selectedTeamIdの扱い**: 「自チーム」タブと「全チーム管理」タブで別々のselectedTeamIdを持つべき。グローバルのselectedTeamIdは自チーム用、全チーム管理用は別のローカルrefで管理
5. **cmd_578との関係**: cmd_578で追加したavailableTeams/isCommissionerMode関連コードの大部分がこのリファクタで置き換わる。cmd_578はcmd_580の「足場」として機能した形
