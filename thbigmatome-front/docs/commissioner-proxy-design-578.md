# コミッショナー全チーム代理管理 設計書 (cmd_578)

## 1. 方針

**方式B+C**: コミッショナーモード時に全チームを代理選択し、既存チーム画面をそのまま使う。
コミッショナー＝全操作可能（権限細分化は将来課題）。

## 2. BE側: 認可の現状分析

### 2.1 TeamAccessible concern (cmd_566)

```ruby
# app/controllers/concerns/team_accessible.rb
unless current_user.commissioner? || team.user_id == current_user.id
  render json: { errors: ["Forbidden"] }, status: :forbidden
end
```

**対応済みコントローラー（10件）:**

| コントローラー | アクション | commissioner対応 |
|---------------|-----------|----------------|
| TeamsController | show, update | ✅ TeamAccessible |
| TeamsController | index | ✅ 認可なし（全チーム返却） |
| TeamsController | create, destroy | ✅ authorize_commissioner! |
| TeamMembershipsController | index | ✅ TeamAccessible |
| TeamPlayersController | index, create | ✅ TeamAccessible |
| TeamRostersController | show, update | ✅ TeamAccessible |
| TeamSeasonsController | show | ✅ TeamAccessible |
| LineupTemplatesController | CRUD | ✅ TeamAccessible |
| SquadTextSettingsController | show, update | ✅ TeamAccessible |
| GameLineupsController | show, update | ✅ TeamAccessible |
| RosterChangesController | index, create | ✅ TeamAccessible |
| TeamKeyPlayersController | create, destroy | ✅ TeamAccessible |

### 2.2 BE側の結論

**BE側は追加変更不要。** TeamAccessible concernがすべてのteam配下APIでcommissioner?チェックを行っている。
GET /api/v1/teams（index）は認可なしで全チーム返却するため、コミッショナーが全チームリストを取得する手段もある。

### 2.3 唯一の懸念: GET /users/me/teams

```ruby
# UsersController#my_teams
teams = current_user.teams.order(is_active: :desc, created_at: :asc)
```

これは`current_user.teams`（User has_many :teams through）のため、コミッショナーが所有していないチームは返らない。
**コミッショナーモード時は GET /teams を使う必要がある**（後述のFE設計で対応）。

## 3. FE側: 設計

### 3.1 initializeUserState 拡張

**現状** (cmd_576):
```typescript
const initializeUserState = async () => {
  // /users/me/teams → myTeams（自チームのみ）
  // commissioner + !hasTeam → commissionerMode自動ON
}
```

**変更後**:
```typescript
const initializeUserState = async () => {
  const teamStore = useTeamSelectionStore()

  // 1. 自チーム取得（全ユーザー共通）
  if (!teamStore.teamsLoaded) {
    try {
      const response = await axios.get<MyTeam[]>('/users/me/teams')
      teamStore.setMyTeams(response.data)
    } catch {
      teamStore.setMyTeams([])
    }
  }

  // 2. コミッショナー: 全チーム取得（代理管理用）
  if (isCommissioner.value && !teamStore.allTeamsLoaded) {
    try {
      const response = await axios.get<MyTeam[]>('/teams')
      teamStore.setAllTeams(response.data)
    } catch {
      teamStore.setAllTeams([])
    }
  }

  // 3. チーム未所持コミッショナー → 自動で管理モード
  if (isCommissioner.value && teamStore.teamsLoaded && !teamStore.hasTeam) {
    useCommissionerModeStore().setMode(true)
  }
}
```

### 3.2 teamSelectionStore 拡張

```typescript
// 追加するstate/computed/action
const allTeams = ref<MyTeam[]>([])
const allTeamsLoaded = ref(false)

// コミッショナーモード時に使うチーム一覧
const availableTeams = computed(() => {
  const cmStore = useCommissionerModeStore()
  return cmStore.isCommissionerMode ? allTeams.value : myTeams.value
})

function setAllTeams(teams: MyTeam[]) {
  allTeams.value = teams
  allTeamsLoaded.value = true
}

// resetTeams() にallTeamsリセットも追加
function resetTeams() {
  myTeams.value = []
  teamsLoaded.value = false
  allTeams.value = []
  allTeamsLoaded.value = false
}
```

**ポイント:**
- `availableTeams`: コミッショナーモードON→全チーム、OFF→自チーム
- 既存の `myTeams` / `hasTeam` はそのまま（通常ユーザーへの影響ゼロ）
- `selectedTeamId` はコミッショナーモード時にも機能する（任意のチームIDを設定可能、既にnumber|null型）

### 3.3 NavigationDrawer チームメニュー条件の修正

**現状:**
```html
<template v-if="!teamSelectionStore.teamsLoaded || teamSelectionStore.hasTeam">
```
チーム未所持の通常ユーザー → チームメニュー非表示。これは正しい。
コミッショナーモード時 → 全チーム代理管理なのでチームメニューは**常に表示すべき**。

**変更後:**
```html
<template v-if="showTeamMenu">
```

```typescript
const showTeamMenu = computed(() => {
  // コミッショナーモード時は常に表示（全チーム代理管理）
  if (commissionerModeStore.isCommissionerMode) return true
  // 通常時はチーム所持時のみ
  return !teamSelectionStore.teamsLoaded || teamSelectionStore.hasTeam
})
```

### 3.4 チーム切り替えUI（HomePortalView拡張）

**コミッショナーモードON時:**
- HomePortalViewへの遷移を許可（リダイレクトしない）
- `availableTeams`（全チーム）をタブまたはセレクトで切り替え表示
- 既存のSeasonPortalコンポーネントをそのまま使用

**UIパターン:**
```
[コミッショナーモードON時]
┌─ チーム選択セレクト ─────────────────┐
│ ▼ 若尊バレーナ                       │
│   第108代スレ主                       │
│   灰塵帝国                           │
│   ...全チーム                        │
└──────────────────────────────────────┘
┌─ SeasonPortal（選択チーム）──────────┐
│  シーズン情報...                      │
└──────────────────────────────────────┘
```

**実装方針:**
- HomePortalView.vue: コミッショナーモード時のリダイレクトを撤回
- 代わりに `availableTeams` からチーム選択UIを表示
- チーム数が多い（10+）ため、タブではなくv-selectを使用
- 選択変更 → `teamSelectionStore.selectTeam()` → SeasonPortalが再描画

### 3.5 HomePortalView 修正詳細

```typescript
onMounted(() => {
  // コミッショナーモード時: 全チームから選択可能にする（リダイレクトしない）
  if (commissionerModeStore.isCommissionerMode) {
    myTeams.value = teamSelectionStore.availableTeams as Team[]
    // selectedTeamIdが未設定または無効なら先頭チームを選択
    if (myTeams.value.length > 0) {
      const storedId = teamSelectionStore.selectedTeamId
      const found = myTeams.value.find(t => t.id === storedId)
      selectedTeamId.value = found ? found.id : myTeams.value[0].id
    }
    return
  }

  // 通常ユーザー: 自チームのみ
  myTeams.value = teamSelectionStore.myTeams as Team[]
  if (myTeams.value.length > 0) {
    const storedId = teamSelectionStore.selectedTeamId
    const found = myTeams.value.find(t => t.id === storedId)
    selectedTeamId.value = found ? found.id : myTeams.value[0].id
  }
})
```

**テンプレート修正:**
- チーム1件: SeasonPortal直接表示（変更なし）
- チーム2件: v-tabs（変更なし）
- コミッショナーモード + 多数チーム: v-selectに切り替え

### 3.6 initializeUserState のcommissionerMode自動設定ロジック変更

**現状**: チーム未所持コミッショナー → 自動でcommissionerMode=true
**変更後**: この自動設定はそのまま維持。ただし、**commissionerモード時にHomePortalViewからリダイレクトしない**ように変更するため、commissionerDashboardへの自動遷移パスを見直す必要がある。

**具体的には:**
- HomePortalViewの `watch(commissionerModeStore.isCommissionerMode)` → リダイレクトではなくチーム一覧再読み込み
- HomePortalViewの onMounted commissionerMode チェック → リダイレクトではなく全チーム表示

## 4. 実装フェーズ分割

### Phase 1: Store拡張 + initializeUserState修正（BEなし・FE 2ファイル）
1. `teamSelection.ts`: allTeams/allTeamsLoaded/availableTeams/setAllTeams追加、resetTeams更新
2. `useAuth.ts`: initializeUserState()にcommissioner用全チーム取得追加
3. テスト更新

**サブタスク数**: 1（小規模、1足軽で完了）

### Phase 2: NavigationDrawer + HomePortalView修正（FE 2ファイル）
1. `NavigationDrawer.vue`: showTeamMenu computed追加（コミッショナーモード時は常に表示）
2. `HomePortalView.vue`: コミッショナーモード時のリダイレクト撤回、全チーム表示、v-select UI
3. テスト更新

**サブタスク数**: 1-2（UIの複雑さ次第）

### Phase 3: 統合テスト + エッジケース対応（FE）
1. コミッショナーモードON/OFF切り替え時のチーム一覧更新
2. コミッショナーモードOFF→ONでselectedTeamIdが自チーム外のチームだった場合の処理
3. チーム0件コミッショナー（現状: EmptyState表示 → 全チーム表示に変更）

**サブタスク数**: 1

### 合計見積り: 3-4サブタスク

## 5. 変更対象ファイル一覧

| ファイル | Phase | 変更内容 |
|---------|-------|---------|
| `src/stores/teamSelection.ts` | 1 | allTeams/availableTeams追加 |
| `src/composables/useAuth.ts` | 1 | initializeUserState: GET /teams追加 |
| `src/components/NavigationDrawer.vue` | 2 | showTeamMenu computed |
| `src/views/HomePortalView.vue` | 2 | リダイレクト撤回、v-select UI |
| `src/composables/__tests__/useAuth.spec.ts` | 1 | テスト更新 |
| `src/views/__tests__/HomePortalView.spec.ts` | 2 | テスト更新 |

**BE変更: なし**（TeamAccessibleが全対応済み）

## 6. リスクと注意点

1. **GET /teams のレスポンスサイズ**: 全チーム数が多い場合のパフォーマンス。現時点では問題ないが、将来的にページネーション検討
2. **selectedTeamIdの永続化**: localStorage保存のため、コミッショナーが代理選択したチームIDがプレイヤーモードに戻っても残る。モード切替時にselectedTeamIdをリセットまたは自チームに戻す処理が必要
3. **commissionerDashboardの位置づけ**: 全チーム代理管理が実現すると、CommissionerDashboardViewの役割が薄くなる。将来的に統合検討
