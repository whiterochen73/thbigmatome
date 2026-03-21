# FE認証・認可・権限フロー設計書 (cmd_576)

## 1. 現状の認証フロー（時系列）

### 1.1 初回ページロード（未認証状態）

```
Browser → App.vue onMounted
  → checkAuth() (GET /auth/current_user)
  → 失敗 → user.value = null → isAuthenticated = false

Router beforeEach (authGuard)
  → !isAuthenticated && requiresAuth → redirect /login

LoginForm.vue
  → handleLogin() → login(name, password) → POST /auth/login
  → 成功 → user.value = { id, name, role } → isAuthenticated = true
  → router.push('/')
```

### 1.2 ログイン後のページ遷移（`/` へ）

```
authGuard → isAuthenticated = true → 通過
Router → / → DefaultLayout → router-view → HomePortalView.vue

DefaultLayout mount:
  ├── AppBar mount
  │   ├── useAuth() → isCommissioner (user.role === 'commissioner')
  │   ├── useCommissionerModeStore() → localStorage から復元
  │   ├── useTeamSelectionStore() → teamsLoaded = false, hasTeam = false
  │   └── watchEffect: isCommissioner && teamsLoaded && !hasTeam → setMode(true)
  │       ※ この時点では teamsLoaded=false なので発火しない
  │
  ├── NavigationDrawer mount
  │   └── v-if="!teamsLoaded || hasTeam" → true（未ロードなので表示）
  │
  └── HomePortalView mount (onMounted)
      ├── commissionerMode check → false（初回ログイン時はlocalStorageにない）
      ├── teamsLoaded check → false → API呼び出し
      ├── GET /users/me/teams
      ├── setMyTeams(response.data) → teamsLoaded = true
      │
      └── ★ ここでAppBar watchEffectが反応:
          isCommissioner && teamsLoaded(=true) && !hasTeam
          → setMode(true) → commissionerMode = true
          → HomePortalView の watch が検知 → redirect /commissioner/dashboard
```

### 1.3 リロード時（認証済み状態）

```
Browser → App.vue onMounted → checkAuth() → 成功 → user.value 復元
※ 注意: App.vue の checkAuth() と authGuard の checkAuth() が競合する可能性あり
  (authGuardが先に実行される場合、checkAuth()の結果を待ってから通過)

Router → / → DefaultLayout → HomePortalView
  ├── commissionerMode → localStorage から 'true' で復元
  ├── onMounted → commissionerMode = true → redirect /commissioner/dashboard
  └── API呼び出しなし
```

## 2. 権限関連の状態管理（棚卸し）

| 状態 | 保持場所 | セットされるタイミング | 依存先 | 永続化 |
|------|---------|---------------------|--------|--------|
| `user` | useAuth (module-level ref) | App.vue onMounted / authGuard / login() | APIレスポンス | なし（メモリのみ） |
| `isAuthenticated` | useAuth (computed) | user が null でないとき | user | なし |
| `isCommissioner` | useAuth (computed) | user.role === 'commissioner' | user | なし |
| `commissionerMode` | commissionerModeStore (Pinia) | localStorage復元 / setMode() / toggle() | isCommissioner + hasTeam | localStorage |
| `teamsLoaded` | teamSelectionStore (Pinia) | setMyTeams()呼び出し時 | API応答 | なし（メモリのみ） |
| `hasTeam` | teamSelectionStore (computed) | myTeams.length > 0 | teamsLoaded | なし |
| `myTeams` | teamSelectionStore (Pinia) | setMyTeams()呼び出し時 | API応答 | なし |
| `selectedTeamId` | teamSelectionStore (Pinia) | selectTeam() / localStorage復元 | ユーザー操作 | localStorage |

### 2.1 根本的な問題: 初期化の分散

**現在の状態初期化ポイント（6箇所）:**

1. **App.vue onMounted** → `checkAuth()` (user/isAuthenticated)
2. **authGuard beforeEach** → `checkAuth()` (重複呼び出し)
3. **HomePortalView onMounted** → `GET /users/me/teams` → `setMyTeams()` (teamsLoaded/hasTeam)
4. **HomeView onMounted** → `GET /users/me/teams` → `setMyTeams()` (重複)
5. **AppBar watchEffect** → `setMode(true)` (commissionerMode自動設定)
6. **commissionerModeStore 初期化** → localStorage復元

**問題点:**
- 認証状態(user)の初期化とチームデータの初期化が別の場所・別のタイミングで実行される
- AppBarのwatchEffect(5)はteamsLoaded(3)に依存するが、(3)はHomePortalView固有の処理
- HomePortalViewとHomeViewの両方でsetMyTeams()を呼ぶ（どちらが先にmountされるかはルーティング次第）
- リロード vs 初回ログインでcommissionerModeの初期値が異なる（localStorage有無）

## 3. cmd_572〜575の修正内容と残存問題

| cmd | 修正内容 | 解決した問題 | 残存問題 |
|-----|---------|------------|---------|
| **572** | HomePortalView: loading初期値修正、commissionerリダイレクト時loading=false、キャッシュ活用 | ローディングスピナー固まり | − |
| **574** | HomePortalView: watchでcommissionerMode変化を監視→リダイレクト | AppBar watchEffectの遅延によるEmptyState表示 | − |
| **575** | AppBar: showModeToggle条件を`isCommissioner`のみに簡素化 | チーム未所持時ボタン非表示 | − |
| **571** | AppBar: watchEffect(自動commissioner固定)、NavigationDrawer: チームメニュー条件制御 | チーム未所持ユーザーのUI整理 | NavigationDrawerの条件は妥当 |

### 3.1 残存する構造的問題

1. **checkAuth()の二重呼び出し**
   - App.vue onMounted と authGuard の両方で`checkAuth()`を呼ぶ
   - authGuardはキャッシュチェック(`if (!isAuthenticated.value)`)で回避しているが、初回ロード時は両方実行される
   - 厳密にはレースコンディション: App.vue の checkAuth() が完了する前に authGuard が走る可能性

2. **チームデータ取得がビュー依存**
   - `/users/me/teams` をHomePortalView.vueとHomeView.vueの両方で呼んでいる
   - 初回アクセスが`/players`等の別ページだとteamsLoadedが永久にfalseのまま
   - → AppBarのwatchEffectが発火しない → NavigationDrawerのチームメニューが表示され続ける

3. **commissionerMode永続化の副作用**
   - localStorage('commissionerMode')は非commissionerユーザーでも残り得る（ロール変更時）
   - ログアウト時にクリアされない

4. **ユーザー状態がメモリのみ（Module-level ref）**
   - useAuth()のuserはPiniaストアではなくmodule-level ref
   - Piniaのdevtools対応、SSR対応、テスタビリティが限定的
   - ただし現時点では実害なし

## 4. 根本修正の設計方針

### 方針A: 認証後初期化の集約（推奨）

**コンセプト**: ログイン成功後 / checkAuth成功後に、全状態の初期化を1箇所で保証する。

#### 4.1 `useAuth.ts` に `initializeUserState()` を追加

```typescript
// useAuth.ts
const initializeUserState = async () => {
  // 1. チームデータ取得
  const teamStore = useTeamSelectionStore()
  if (!teamStore.teamsLoaded) {
    try {
      const response = await axios.get<MyTeam[]>('/users/me/teams')
      teamStore.setMyTeams(response.data)
    } catch {
      teamStore.setMyTeams([])
    }
  }

  // 2. コミッショナーモード自動設定（チーム未所持 + commissioner権限）
  if (isCommissioner.value && teamStore.teamsLoaded && !teamStore.hasTeam) {
    const cmStore = useCommissionerModeStore()
    cmStore.setMode(true)
  }
}
```

#### 4.2 呼び出しポイント

```typescript
// login() 成功後
const login = async (name: string, password: string) => {
  // ... 既存ロジック ...
  user.value = response.data.user
  await initializeUserState()  // ★ 追加
  return response.data
}

// checkAuth() 成功後
const checkAuth = async () => {
  try {
    const response = await axios.get<{ user: User }>('auth/current_user')
    user.value = response.data.user
    await initializeUserState()  // ★ 追加
  } catch {
    user.value = null
  }
}
```

#### 4.3 変更対象ファイル

| ファイル | 変更内容 |
|---------|---------|
| `src/composables/useAuth.ts` | `initializeUserState()` 追加。login/checkAuth後に呼び出し |
| `src/components/AppBar.vue` | watchEffect(自動commissioner設定)を**削除** — useAuthに集約 |
| `src/views/HomePortalView.vue` | setMyTeams()呼び出しを**削除** — useAuthで初期化済み。watchも不要に |
| `src/views/HomeView.vue` | setMyTeams()呼び出しを**削除** — useAuthで初期化済み |
| `src/router/authGuard.ts` | checkAuth()にinitializeUserStateが含まれるため変更不要 |

#### 4.4 影響範囲とリスク

- **HomePortalView**: onMounted内のAPI呼び出し削除、teamSelectionStoreからキャッシュ読み出しのみ
  - teamsLoadedは認証時点でtrue保証 → loading初期値はfalse固定
  - commissionerModeも認証時点で確定 → onMountedの冒頭チェックで即リダイレクト
- **AppBar**: watchEffectのレースコンディション問題が根本解消
- **HomeView**: fetchMyTeams内のsetMyTeams()が冗長になるが、残しても害はない（idempotent）

#### 4.5 副次的改善

1. **ログアウト時のクリーンアップ追加**
```typescript
const logout = async () => {
  // ... 既存ロジック ...
  user.value = null
  // ★ 状態クリア追加
  useTeamSelectionStore().clearTeam()
  useTeamSelectionStore().$reset?.() // myTeams/teamsLoadedリセット
  useCommissionerModeStore().setMode(false)
  localStorage.removeItem('commissionerMode')
}
```

2. **App.vue の checkAuth() と authGuard の整理**
   - authGuard が先に checkAuth() を呼ぶため、App.vue 側は削除可能
   - ただしApp.vueの checkAuth() はテーマ初期化等と並列実行するため、残しても害は少ない
   - **推奨**: App.vue の checkAuth() を削除し、authGuard に一本化

### 方針B: authGuardでのゲート方式（代替案）

authGuardで認証完了後にteamsLoadedをawaitする方式。

```typescript
// authGuard.ts
export async function authGuard(to) {
  if (!isAuthenticated.value) {
    await checkAuth()  // これでinitializeUserStateも完了
  }
  // この時点でteamsLoaded=true, commissionerMode確定済み
  if (to.meta.requiresAuth && !isAuthenticated.value) return '/login'
  if (to.meta.requiresCommissioner && !isCommissioner.value) return '/'
  return true
}
```

**方針Aとの違い**: authGuardに依存するため、初回のルーティングが遅延する可能性。
方針Aの方がlogin/checkAuthの呼び出し元で柔軟に制御できるため推奨。

### 方針比較

| 観点 | 方針A (useAuth集約) | 方針B (authGuardゲート) |
|------|-------------------|---------------------|
| 初期化の確実性 | ◎ login/checkAuth成功後に必ず実行 | ○ ルーティング通過時に保証 |
| 実装の単純さ | ◎ 1関数追加 + 不要コード削除 | ○ authGuard修正のみ |
| 遅延影響 | ◎ login/checkAuthに含まれるため体感影響小 | △ 全ルート遷移に影響 |
| テスタビリティ | ◎ useAuth単体テストで検証可能 | ○ authGuard + store統合テスト必要 |
| 直接遷移（/players等）対応 | ◎ checkAuth→initializeで対応 | ◎ authGuard通過時に対応 |

## 5. 実装計画

### Phase 1: useAuth集約（方針A）
1. `useAuth.ts` に `initializeUserState()` を追加
2. login() / checkAuth() 成功後に呼び出し
3. AppBar.vue の watchEffect を削除
4. HomePortalView.vue / HomeView.vue の setMyTeams() 重複を整理
5. ログアウト時クリーンアップ追加

### Phase 2: App.vue整理
1. App.vue の checkAuth() を削除（authGuardに一本化）
2. DefaultLayout / AppBar 初期化時にteamsLoaded=true前提で安全に動作することを確認

### Phase 3: テスト
1. useAuth の統合テスト追加（login → initializeUserState → store状態検証）
2. 既存テスト修正（AppBar watchEffect前提のテストがあれば更新）
3. E2Eシナリオ: ログイン→ホーム遷移→コミッショナーモード確認

### 変更ファイル数見積り
- 修正: 4ファイル（useAuth.ts, AppBar.vue, HomePortalView.vue, HomeView.vue）
- 削除行 > 追加行（不要な分散ロジック削除）
- テスト: 2-3ファイル更新
