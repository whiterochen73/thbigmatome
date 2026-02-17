# 13. フロントエンドアーキテクチャ仕様書

## 概要

東方BIG野球まとめツールのフロントエンドは、Vue.js 3ベースのSPA（Single Page Application）として構築されている。Composition APIを採用し、Vuetify 3によるMaterial DesignベースのUI、vue-i18nによる国際化、vue-routerによるクライアントサイドルーティングを統合している。

**SPA構成:**
- エントリポイント: `src/main.ts`
- ルートコンポーネント: `src/App.vue`
- レイアウトコンポーネント: `src/layouts/DefaultLayout.vue`（認証後のページ共通レイアウト）
- バックエンドAPI（Rails）との通信はAxios経由で行い、セッションベース認証 + CSRF保護に対応

**技術スタック:**

| 技術 | バージョン | 用途 |
|------|-----------|------|
| Vue.js | ^3.5.17 | UIフレームワーク |
| TypeScript | ~5.8.0 | 型安全な開発 |
| Vuetify | ^3.9.0 | UIコンポーネントライブラリ（Material Design） |
| Vue Router | ^4.5.1 | クライアントサイドルーティング |
| vue-i18n | ^11.1.11 | 国際化（i18n） |
| Axios | ^1.10.0 | HTTP通信 |
| Vite | ^7.0.0 | ビルドツール・開発サーバー |
| @mdi/font | ^7.4.47 | Material Design Iconsフォント |

**開発ツール:**

| ツール | バージョン | 用途 |
|--------|-----------|------|
| vue-tsc | ^2.2.10 | Vue + TypeScript型チェック |
| eslint | ^9.29.0 | リンター |
| prettier | 3.5.3 | コードフォーマッター |
| vite-plugin-vue-devtools | ^7.7.7 | 開発時のVueデバッグツール |
| npm-run-all2 | ^8.0.4 | NPMスクリプト並列実行 |

---

## ディレクトリ構成

```
thbigmatome-front/
├── src/
│   ├── main.ts                   # アプリケーションエントリポイント
│   ├── App.vue                   # ルートコンポーネント
│   ├── assets/                   # 静的アセット
│   │   ├── main.css              # メインCSS
│   │   ├── base.css              # ベースCSS
│   │   └── logo.svg              # ロゴSVG
│   ├── components/               # 再利用コンポーネント
│   │   ├── shared/               # 汎用セレクタコンポーネント
│   │   │   ├── TeamSelect.vue        # チーム選択ドロップダウン
│   │   │   ├── TeamMemberSelect.vue  # チームメンバー選択オートコンプリート
│   │   │   ├── PlayerSelect.vue      # 選手選択オートコンプリート
│   │   │   ├── PlayerDetailSelect.vue # 選手詳細選択（複数選択対応）
│   │   │   └── CostListSelect.vue    # コスト一覧選択ドロップダウン
│   │   ├── settings/             # 設定画面用コンポーネント群（18ファイル）
│   │   ├── players/              # 選手編集用コンポーネント群（4ファイル）
│   │   ├── ConfirmDialog.vue     # 汎用確認ダイアログ
│   │   ├── ManagerDialog.vue     # 監督追加/編集ダイアログ
│   │   ├── TeamDialog.vue        # チーム追加/編集ダイアログ
│   │   ├── SeasonInitializationDialog.vue  # シーズン初期化ダイアログ
│   │   ├── StartingMemberDialog.vue  # スタメン登録ダイアログ
│   │   ├── Scoreboard.vue        # スコアボード表示
│   │   ├── PromotionCooldownInfo.vue # 昇格クールダウン情報
│   │   ├── AbsenceInfo.vue       # 離脱者情報表示
│   │   └── PlayerAbsenceFormDialog.vue # 離脱者登録ダイアログ
│   ├── composables/              # Composition API共通ロジック
│   │   ├── useAuth.ts            # 認証状態管理
│   │   └── useSnackbar.ts        # グローバルSnackbar管理
│   ├── layouts/                  # レイアウトコンポーネント
│   │   └── DefaultLayout.vue     # 認証後の共通レイアウト
│   ├── locales/                  # 国際化リソース
│   │   └── ja.json               # 日本語翻訳定義
│   ├── plugins/                  # プラグイン設定
│   │   ├── axios.ts              # Axios設定（baseURL, CSRF, インターセプター）
│   │   ├── vuetify.ts            # Vuetify設定（テーマ、アイコン）
│   │   └── i18n.ts               # vue-i18n設定
│   ├── router/                   # ルーティング
│   │   ├── index.ts              # ルート定義
│   │   └── authGuard.ts          # 認証ガード
│   ├── types/                    # TypeScript型定義（24ファイル）
│   └── views/                    # ページコンポーネント
│       ├── TopMenu.vue           # ダッシュボード
│       ├── LoginForm.vue         # ログインフォーム
│       ├── ManagerList.vue       # 監督一覧
│       ├── TeamList.vue          # チーム一覧
│       ├── TeamMembers.vue       # チームメンバー登録
│       ├── Players.vue           # 選手一覧
│       ├── CostAssignment.vue    # コスト登録
│       ├── Settings.vue          # 各種設定
│       ├── SeasonPortal.vue      # シーズンポータル
│       ├── ActiveRoster.vue      # 出場選手登録
│       ├── GameResult.vue        # 試合結果入力
│       ├── ScoreSheet.vue        # スコアシート
│       ├── PlayerAbsenceHistory.vue # 離脱者履歴
│       └── commissioner/
│           └── LeaguesView.vue   # リーグ管理（コミッショナー専用）
├── vite.config.ts                # Viteビルド設定
├── tsconfig.json                 # TypeScript設定（ルート）
├── tsconfig.app.json             # TypeScript設定（アプリケーション）
├── tsconfig.node.json            # TypeScript設定（Node.js/ビルドツール）
└── package.json                  # パッケージ定義
```

---

## アプリケーション初期化

### エントリポイント (`src/main.ts`)

```typescript
import { createApp } from 'vue'
import App from './App.vue'
import router from '@/router/index'
import i18n from '@/plugins/i18n'
import '@/plugins/axios'  // サイドエフェクトとしてインポート（インターセプター登録）

import 'vuetify/styles'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import '@mdi/font/css/materialdesignicons.css'

const vuetify = createVuetify({
  components,
  directives,
  locale: { locale: 'ja', fallback: 'en' },
  theme: { defaultTheme: 'light' }
})

const app = createApp(App)
app.use(router)
app.use(vuetify)
app.use(i18n)
app.mount('#app')
```

**プラグイン登録順序:**
1. `router` — Vue Routerインスタンス
2. `vuetify` — Vuetifyインスタンス（main.ts内でインラインに生成）
3. `i18n` — vue-i18nインスタンス

**注意点:**
- Vuetifyは `src/plugins/vuetify.ts` でも設定ファイルが存在するが、`main.ts` で別途 `createVuetify()` を呼び出しているため、実際に使用されるのは `main.ts` 内のインライン設定。`plugins/vuetify.ts` のテーマ設定（カラーパレット等）はロードされていない。
- `@/plugins/axios` はサイドエフェクトとしてインポートされ、Axiosのグローバル設定（baseURL, withCredentials, インターセプター）が適用される。
- Vuetifyの翻訳キー警告を抑制する `warnHandler` が設定されている。

### ルートコンポーネント (`src/App.vue`)

```vue
<template>
  <v-app>
    <router-view />
  </v-app>
</template>
```

- `v-app`（Vuetifyのルートコンテナ）内に `router-view` を配置
- `onMounted` で `useAuth().checkAuth()` を呼び出し、アプリケーション起動時に認証状態をサーバーに問い合わせ
- 認証失敗時はコンソールにエラーログを出力

**アプリケーション起動時の認証チェック:**
```typescript
const { checkAuth } = useAuth()

onMounted(async () => {
  try {
    await checkAuth()
  } catch (error) {
    console.error('Authentication check failed:', error)
  }
})
```

---

## ルーティング

### ルート定義 (`src/router/index.ts`)

ルーターは `createWebHistory` モード（HTML5 History API）を使用し、全ルート遷移前に `authGuard` が実行される。

**ルーティング構造:**

| パス | ルート名 | コンポーネント | 読込方式 | メタ情報 |
|------|---------|--------------|---------|---------|
| `/login` | Login | `LoginForm.vue` | 即時 | `requiresAuth: false` |
| `/` | — | `DefaultLayout.vue` | 即時 | `requiresAuth: true` |
| `/menu` | ダッシュボード | `TopMenu.vue` | 即時 | `title: 'ダッシュボード'` |
| `/managers` | 監督一覧 | `ManagerList.vue` | 即時 | `title: '監督一覧'` |
| `/teams` | TeamList | `TeamList.vue` | 遅延 | `requiresAuth: true` |
| `/teams/:teamId/members` | TeamMembers | `TeamMembers.vue` | 遅延 | `requiresAuth: true, title: 'チームメンバー登録'` |
| `/players` | Players | `Players.vue` | 即時 | `requiresAuth: true, title: '選手一覧'` |
| `/cost_assignment` | CostAssignment | `CostAssignment.vue` | 即時 | `requiresAuth: true, title: 'コスト登録'` |
| `/settings` | 各種設定 | `Settings.vue` | 即時 | `title: '各種設定'` |
| `/commissioner/leagues` | Leagues | `LeaguesView.vue` | 遅延 | `requiresAuth: true, requiresCommissioner: true, title: 'リーグ管理'` |
| `/teams/:teamId/season` | SeasonPortal | `SeasonPortal.vue` | 遅延 | `requiresAuth: true, title: 'シーズンポータル'` |
| `/teams/:teamId/roster` | SeasonRoster | `ActiveRoster.vue` | 遅延 | `requiresAuth: true, title: '出場選手登録'` |
| `/teams/:teamId/season/games/:scheduleId` | GameResult | `GameResult.vue` | 遅延 | `requiresAuth: true, title: '試合結果入力'` |
| `/teams/:teamId/season/games/:scheduleId/scoresheet` | ScoreSheet | `ScoreSheet.vue` | 遅延 | `requiresAuth: true, title: 'スコアシート'` |
| `/teams/:teamId/season/player_absences` | PlayerAbsenceHistory | `PlayerAbsenceHistory.vue` | 遅延 | `requiresAuth: true, title: '離脱者履歴'` |
| `/:pathMatch(.*)*` | — | — | — | `/menu` へリダイレクト（キャッチオール） |

**ルーティング構造の特徴:**
- `/login` はレイアウトなしの独立ページ
- `/` 以下の認証済みルートは `DefaultLayout` の `children` として定義
- `/` へのアクセスは `/menu` へリダイレクト
- 未定義パスは `/:pathMatch(.*)*` でキャッチし `/menu` へリダイレクト
- 動的インポート（`() => import(...)` ）によるコード分割を一部ルートで使用

**動的パラメータ:**
- `:teamId` — チームID（チームメンバー登録、シーズン関連画面で使用）
- `:scheduleId` — スケジュールID（試合結果入力、スコアシートで使用）

### 認証ガード (`src/router/authGuard.ts`)

全ルート遷移前に `router.beforeEach(authGuard)` で実行されるグローバルナビゲーションガード。

**型シグネチャ:**
```typescript
export async function authGuard(
  to: RouteLocationNormalized,
  from: RouteLocationNormalized,
  next: NavigationGuardNext
)
```

**処理フロー:**

```
[1] 遷移先がログインページか判定
       ↓
[2a] /login の場合:
       isAuthenticated.value をチェック
       → ログイン済み: next('/menu') でメニューへリダイレクト
       → 未ログイン: next() でそのままログインページへ
       （checkAuth() は呼ばない — 無限ループ回避のため）
       ↓
[2b] /login 以外の場合:
       await checkAuth() でサーバーに認証状態を問い合わせ
       ↓
[3] メタ情報による権限チェック:
       - requiresAuth: true && 未認証 → next('/login')
       - requiresCommissioner: true && 非コミッショナー → next('/menu')
       - それ以外 → next()
```

**メタフィールド定義:**

| メタフィールド | 型 | 説明 |
|-------------|----|----|
| `requiresAuth` | `boolean` | `true` で認証必須ルート |
| `requiresCommissioner` | `boolean` | `true` でコミッショナー権限必須ルート |
| `title` | `string` | ページタイトル（ナビゲーション表示用） |

---

## 共通コンポーザブル

### useAuth (`src/composables/useAuth.ts`)

アプリケーション全体の認証状態を管理するComposition API関数。**モジュールスコープの `ref` を使用**しており、どこからインポートしても同一のリアクティブ状態を共有する（シングルトンパターン）。

**内部型定義:**
```typescript
interface User {
  id: number
  name: string
  role: number
}

interface LoginResponse {
  user: User
  message: string
}

interface ErrorResponse {
  error: string
}
```

**内部状態（モジュールスコープ）:**
```typescript
const user = ref<User | null>(null)    // 現在のログインユーザー
const loading = ref(false)              // API処理中フラグ
```

**公開API:**

| メソッド/プロパティ | 型 | 説明 |
|------------------|----|----|
| `user` | `ComputedRef<User \| null>` | 現在のログインユーザー情報（computed） |
| `isAuthenticated` | `ComputedRef<boolean>` | ログイン状態（`!!user.value`） |
| `isCommissioner` | `ComputedRef<boolean>` | コミッショナー権限有無（`user.value?.role === 'commissioner'`） |
| `loading` | `ComputedRef<boolean>` | API処理中フラグ |
| `login(name, password)` | `Promise<LoginResponse>` | ログイン実行 |
| `logout()` | `Promise<void>` | ログアウト実行、`/login` へリダイレクト |
| `checkAuth()` | `Promise<void>` | 認証状態をサーバーに問い合わせ |

**各メソッドの動作:**

**`login(name, password)`:**
1. `loading.value = true`
2. `POST auth/login` に `{ name, password }` を送信
3. 成功時: `user.value = response.data.user` に格納、レスポンスデータを返却
4. 失敗時: `error.response.data.error` があればそのメッセージで、なければ「ログインに失敗しました」で `Error` をスロー
5. `loading.value = false`

**`logout()`:**
1. `loading.value = true`
2. `POST auth/logout` を送信
3. `user.value = null` で認証状態をクリア
4. `router.push('/login')` でログイン画面へ遷移
5. エラー時もユーザー状態をクリア

**`checkAuth()`:**
1. `GET auth/current_user` を送信
2. 成功時: `user.value = response.data.user`
3. 失敗時: `user.value = null`（サイレントに認証状態をクリア）

### useSnackbar (`src/composables/useSnackbar.ts`)

アプリケーション全体で共有されるSnackbar（通知トースト）を管理するComposition API関数。`useAuth` と同様にモジュールスコープの `ref` でシングルトンパターンを実現。

**内部状態（モジュールスコープ）:**
```typescript
const isVisible = ref(false)
const message = ref('')
const color = ref<'success' | 'error' | 'info' | 'warning'>('info')
const timeout = ref(3000)
let timeoutId: number | undefined
```

**公開API:**

| プロパティ/メソッド | 型 | 説明 |
|------------------|----|----|
| `isVisible` | `Readonly<Ref<boolean>>` | Snackbar表示状態 |
| `message` | `Readonly<Ref<string>>` | 表示メッセージ |
| `color` | `Readonly<Ref<'success' \| 'error' \| 'info' \| 'warning'>>` | Snackbarの色 |
| `timeout` | `Readonly<Ref<number>>` | 表示時間（デフォルト: 3000ms） |
| `showSnackbar(text, snackbarColor?)` | `void` | Snackbarを表示 |

**`showSnackbar(text, snackbarColor)` の動作:**
1. `message.value = text` でメッセージ設定
2. `color.value = snackbarColor` で色設定（デフォルト: `'info'`）
3. `isVisible.value = true` で表示
4. 既存タイマーがあればクリア
5. `timeout.value` ミリ秒後に `isVisible.value = false` で自動非表示

**使用箇所:** `DefaultLayout.vue` で `v-snackbar` コンポーネントにバインドされ、各ページコンポーネントから `showSnackbar()` を呼び出すことで統一的な通知表示が可能。

---

## プラグイン設定

### Axios (`src/plugins/axios.ts`)

HTTP通信の基盤設定。サイドエフェクトとして `main.ts` からインポートされる。

**グローバル設定:**
```typescript
axios.defaults.baseURL = 'http://localhost:3000/api/v1'
axios.defaults.withCredentials = true
```

- `baseURL`: バックエンドAPIのベースURL。全リクエストに `/api/v1` プレフィクスが付与される
- `withCredentials: true`: 全リクエストでCookieを送信（セッションベース認証に必要）

**レスポンスインターセプター:**

| ケース | 動作 |
|--------|------|
| 成功レスポンス | `X-CSRF-Token` ヘッダーを抽出し、`axios.defaults.headers.common['X-CSRF-Token']` に設定。以降のリクエストに自動付与 |
| 401エラー | `router.push('/login')` でログイン画面へ自動リダイレクト |
| 403エラー | コンソール警告を出力（リダイレクトなし） |
| その他のエラー | `Promise.reject(error)` で呼び出し元に伝播 |

**CSRFトークンヘッダー検出:**
- `x-csrf-token`（小文字）
- `X-CSRF-Token`（通常）
- `X-Csrf-Token`（代替）

の3パターンに対応し、ブラウザによるヘッダー名の正規化差異を吸収。

### Vuetify (`src/plugins/vuetify.ts`)

Vuetify 3の設定ファイル。

**設定内容:**
```typescript
createVuetify({
  components,        // 全Vuetifyコンポーネント登録
  directives,        // 全Vuetifyディレクティブ登録
  icons: {
    defaultSet: 'mdi',  // Material Design Icons使用
    aliases,
    sets: { mdi },
  },
  theme: {
    defaultTheme: 'light',
    themes: {
      light: {
        colors: {
          primary: '#1976D2',    // 青（Material Blue 700）
          secondary: '#424242',  // ダークグレー
          accent: '#82B1FF',     // ライトブルー
          error: '#FF5252',      // 赤
          info: '#2196F3',       // ブルー
          success: '#4CAF50',    // グリーン
          warning: '#FFC107',    // アンバー
        },
      },
    },
  },
})
```

**注意:** このファイルは `main.ts` では直接使用されていない（`main.ts` で別途 `createVuetify()` が呼ばれている）。`main.ts` のインライン設定が実際に使用される。上記のカラーテーマ設定は適用されていない可能性がある。

### i18n (`src/plugins/i18n.ts`)

vue-i18nの設定ファイル。

**設定内容:**
```typescript
createI18n({
  legacy: false,           // Composition APIモード
  locale: 'ja',            // デフォルトロケール: 日本語
  fallbackLocale: 'ja',    // フォールバックロケール: 日本語
  messages: { ja },         // ja.json をメッセージソースとして登録
  missingWarn: false,       // 未定義キー警告を抑制
  fallbackWarn: false,      // フォールバック警告を抑制
})
```

**特徴:**
- `legacy: false` により、Composition API（`useI18n()`）での使用が可能
- 日本語のみの単一ロケール構成（多言語対応は未実装）
- 未定義キー・フォールバック時の警告を抑制

---

## レイアウト

### DefaultLayout (`src/layouts/DefaultLayout.vue`)

認証後の全ページで使用される共通レイアウト。アプリケーションバー、ナビゲーションドロワー、メインコンテンツエリア、グローバルSnackbarで構成される。

**レイアウト構造:**
```
┌────────────────────────────────────────────────┐
│ v-app-bar                                       │
│ ┌──────┬──────────────────────┬────────────────┐│
│ │ ≡    │ ⚾ 東方BIG野球まとめ  │         👤    ││
│ └──────┴──────────────────────┴────────────────┘│
├────────┬───────────────────────────────────────┤
│ v-nav  │ v-main                                 │
│ drawer │                                        │
│        │ <router-view />                        │
│ トップ  │                                        │
│ 監督    │     （ページコンテンツ）                  │
│ チーム  │                                        │
│ 選手    │                                        │
│ コスト  │                                        │
│ 設定    │                                        │
│ [リーグ]│                                        │
│        │                                        │
│ ◁/▷   │                                        │
├────────┴───────────────────────────────────────┤
│ v-snackbar (top, tonal)                         │
└────────────────────────────────────────────────┘
```

**コンポーネント構成:**

1. **`v-app-bar`（アプリケーションバー）:**
   - 左端: ハンバーガーメニューアイコン（ドロワーの開閉制御）
   - 中央: アプリタイトル「東方BIG野球まとめツール」（クリックでメニュー画面へ遷移）
   - 右端: ユーザーアイコンメニュー（ユーザー名表示、ログアウトボタン）

2. **`v-navigation-drawer`（ナビゲーションドロワー）:**
   - `rail` モード対応（縮小表示切り替え）
   - 縮小時にクリックすると自動展開

   **メニュー項目:**

   | アイコン | タイトル（i18nキー） | パス | 表示条件 |
   |---------|-------------------|------|---------|
   | `mdi-view-dashboard` | `navigation.dashboard` | `/menu` | 常時 |
   | `mdi-account-supervisor` | `navigation.managers` | `/managers` | 常時 |
   | `mdi-account-group` | `navigation.teams` | `/teams` | 常時 |
   | `mdi-account-multiple` | `navigation.players` | `/players` | 常時 |
   | `mdi-currency-usd` | `navigation.costAssignment` | `/cost_assignment` | 常時 |
   | `mdi-cog` | `navigation.settings` | `/settings` | 常時 |
   | `mdi-trophy` | リーグ管理 | `/commissioner/leagues` | `isCommissioner` が `true` の場合のみ |

   - 末尾にドロワー縮小/展開トグルボタン（`mdi-chevron-left` / `mdi-chevron-right`）

3. **`v-main`（メインコンテンツ）:**
   - `<router-view />` でルート定義に応じたページコンポーネントを表示

4. **`v-snackbar`（グローバル通知）:**
   - `useSnackbar()` の状態にバインド
   - 表示位置: `top`（画面上部）
   - バリアント: `tonal`

**スクリプトロジック:**
- `useAuth()` からユーザー情報、ログアウト関数、コミッショナー判定を取得
- `useSnackbar()` からSnackbar状態を取得
- `useI18n()` から翻訳関数 `t` を取得
- `drawer` / `rail` の状態管理（`ref<boolean>`）

---

## 型定義一覧

`src/types/` 配下に24ファイルの型定義が存在する。各ファイルはバックエンドAPIのレスポンス構造に対応した `interface` を提供する。

### マスターデータ系

| ファイル | 型名 | 用途 | 主要フィールド |
|---------|------|------|-------------|
| `playerType.ts` | `PlayerType` | 選手タイプ | `id`, `name`, `description` |
| `battingStyle.ts` | `BattingStyle` | 打者特徴 | `id`, `name`, `description` |
| `battingSkill.ts` | `BattingSkill`, `SkillType` | 打者特殊能力 | `id`, `name`, `description`, `skill_type` |
| `pitchingStyle.ts` | `PitchingStyle` | 投手特徴 | `id`, `name`, `description` |
| `pitchingSkill.ts` | `PitchingSkill`, `SkillType` | 投手特殊能力 | `id`, `name`, `description`, `skill_type` |
| `biorhythm.ts` | `Biorhythm` | バイオリズム | `id`, `name`, `start_date`, `end_date` |

**`SkillType` 定義（battingSkill.ts / pitchingSkill.ts で同一定義）:**
```typescript
type SkillType = 'positive' | 'negative' | 'neutral'
```

### 管理者・チーム系

| ファイル | 型名 | 用途 | 主要フィールド |
|---------|------|------|-------------|
| `manager.ts` | `Manager` | 監督情報 | `id`, `name`, `short_name?`, `irc_name?`, `user_id?`, `teams?`, `role` |
| `team.ts` | `Team` | チーム情報 | `id`, `name`, `short_name`, `is_active`, `has_season`, `director?`, `coaches?` |

**型の相互参照:** `Manager` は `Team[]` を、`Team` は `Manager` をインポートしている（相互依存）。

### 選手系

| ファイル | 型名 | 用途 | 主要フィールド |
|---------|------|------|-------------|
| `player.ts` | `Player` | 選手基本情報 | `id`, `name`, `short_name`, `number`, `position`, `throwing_hand`, `batting_hand`, `player_type_ids`, `cost_players`, 守備力・送球力各ポジション |
| `playerDetail.ts` | `PlayerDetail` | 選手詳細情報（編集用） | 上記に加え `batting_style_id`, `batting_skill_ids`, `biorhythm_ids`, `bunt`, `steal_start/end`, `speed`, `injury_rate`, 投手能力（`is_pitcher`, `starter_stamina`, `relief_stamina`, `pitching_style_id`, `pitching_skill_ids`）, 専属捕手（`catcher_ids`, `catcher_pitching_style_id`）, パートナー投手（`partner_pitcher_ids`）, `special_defense_c`, `special_throwing_c` |
| `playerAbsence.ts` | `PlayerAbsence` | 選手離脱情報 | `id`, `team_membership_id`, `season_id`, `absence_type`（`'injury' \| 'suspension' \| 'reconditioning'`）, `reason`, `start_date`, `duration`, `duration_unit`（`'days' \| 'games'`）, `player_name` |

### コスト系

| ファイル | 型名 | 用途 | 主要フィールド |
|---------|------|------|-------------|
| `cost.ts` | `Cost` | コスト一覧表 | `id`, `name`, `start_date`, `end_date`, `normal_cost`, `relief_only_cost`, `pitcher_only_cost`, `fielder_only_cost`, `two_way_cost` |
| `costList.ts` | `CostList` | コスト一覧（選択用） | `id`, `name`, `start_date`, `end_date`, `effective_date` |
| `costPlayer.ts` | `CostPlayer` | コスト登録画面の選手行 | `id`, `number`, `name`, `player_types`, 各コスト種別, `[key: string]: any` |
| `playerCost.ts` | `PlayerCost` | 選手のコスト割当 | `id`, `cost_id`, `player_id`, 各コスト種別 |

### シーズン・試合系

| ファイル | 型名 | 用途 | 主要フィールド |
|---------|------|------|-------------|
| `seasonDetail.ts` | `SeasonDetail` | シーズン詳細 | `id`, `name`, `current_date`, `start_date`, `end_date`, `season_schedules` |
| `seasonSchedule.ts` | `SeasonSchedule` | シーズンスケジュール項目 | `id`, `date`, `date_type`, `announced_starter?`, `game_result?` |
| `rosterPlayer.ts` | `RosterPlayer` | 出場選手登録行 | `team_membership_id`, `player_id`, `number`, `player_name`, `squad`（`'first' \| 'second'`）, `cost`, `selected_cost_type`, `position`, `throwing_hand`, `batting_hand`, `player_types`, `cooldown_until?` |
| `gameData.ts` | `GameData`, `LineupItem` | 試合データ | チーム情報、スコア、勝敗投手、スコアボード、スタメン |
| `startingMember.ts` | `StartingMember` | スタメン登録 | `battingOrder`, `position`, `player` |
| `scoreboard.ts` | `Scoreboard` | スコアボード | `home`, `away`（各イニングの得点配列） |

### スケジュール系

| ファイル | 型名 | 用途 | 主要フィールド |
|---------|------|------|-------------|
| `index.ts` | `Schedule` | 日程表 | `id`, `name`, `start_date`, `end_date` |
| `scheduleList.ts` | `ScheduleList` | 日程表一覧（選択用） | `id`, `name`, `start_date`, `end_date`, `effective_date` |
| `scheduleDetail.ts` | `ScheduleDetail` | 日程詳細 | `schedule_id`, `date`, `date_type` |

---

## 共有コンポーネント

`src/components/shared/` 配下に5つの汎用セレクタコンポーネントが存在する。いずれもVuetifyの `v-autocomplete` または `v-select` をラップし、特定のドメインオブジェクト向けに特化した選択UIを提供する。

### TeamSelect

**ファイル:** `src/components/shared/TeamSelect.vue`

**機能:** チーム一覧から1つのチームを選択するドロップダウン。

**Props:**

| Prop | 型 | 必須 | デフォルト | 説明 |
|------|----|----|----------|------|
| `teams` | `Team[]` | Yes | — | 選択肢となるチーム一覧 |
| `displayNameType` | `string` | No | `'name'` | 表示名のフィールド（`'name'` or `'short_name'`） |

**v-model:** `defineModel()` で双方向バインディング対応。選択されたチームID。

**使用コンポーネント:** `v-select`

### PlayerSelect

**ファイル:** `src/components/shared/PlayerSelect.vue`

**機能:** 選手一覧から選手を検索・選択するオートコンプリート。単一選択・複数選択両対応。

**Props:**

| Prop | 型 | 必須 | デフォルト | 説明 |
|------|----|----|----------|------|
| `modelValue` | `number \| number[]` | No | `null` | 選択値（v-model） |
| `players` | `Player[]` | Yes | — | 選択肢となる選手一覧 |
| `label` | `string` | Yes | — | ラベル表示 |
| `multiple` | `boolean` | No | `false` | 複数選択モード |

**カスタムフィルター:** `player.number`, `player.name`, `player.short_name` を結合した文字列に対して部分一致検索。

**使用コンポーネント:** `v-autocomplete`（`clearable`, `density="compact"`）

### PlayerDetailSelect

**ファイル:** `src/components/shared/PlayerDetailSelect.vue`

**機能:** 選手詳細情報に基づく複数選択オートコンプリート。常に `multiple` モード。

**Props:**

| Prop | 型 | 必須 | デフォルト | 説明 |
|------|----|----|----------|------|
| `modelValue` | `number[]` | No | `[]` | 選択値配列（v-model） |
| `players` | `PlayerDetail[]` | Yes | — | 選択肢となる選手詳細一覧 |
| `label` | `string` | Yes | — | ラベル表示 |

**カスタムフィルター:** `PlayerSelect` と同一ロジック（`number`, `name`, `short_name` の部分一致）。

**使用コンポーネント:** `v-autocomplete`（`multiple`, `chips`, `clearable`, `density="compact"`）

### TeamMemberSelect

**ファイル:** `src/components/shared/TeamMemberSelect.vue`

**機能:** 指定チームのメンバー一覧を自動取得し、選択するオートコンプリート。

**Props:**

| Prop | 型 | 必須 | デフォルト | 説明 |
|------|----|----|----------|------|
| `teamId` | `number` | Yes | — | メンバーを取得するチームID |

**API呼び出し:** `onMounted` で `GET /teams/{teamId}/team_memberships` を呼び出し、チームメンバー一覧を取得。

**内部型:**
```typescript
interface TeamMember {
  team_membership_id: number
  player_name: string
}
```

**Expose:** `selectedPlayer`（選択されたプレイヤーID）を `defineExpose` で公開。

**使用コンポーネント:** `v-autocomplete`

### CostListSelect

**ファイル:** `src/components/shared/CostListSelect.vue`

**機能:** コスト一覧表を選択するドロップダウン。マウント時に自動取得し、現在日時に有効なコスト表を自動選択。

**v-model:** `defineModel<CostList | null>()` で双方向バインディング対応。`return-object: true` により選択されたオブジェクト全体を返す。

**API呼び出し:** `onMounted` で `GET /costs` を呼び出し、コスト一覧表を取得。

**初期値自動選択ロジック:**
1. `modelValue` が未設定の場合、現在日時が `start_date` ～ `end_date` の範囲内にあるコスト表を検索
2. 該当するものがあればそれを選択
3. なければリストの最初のコスト表を選択

**使用コンポーネント:** `v-select`（`return-object: true`）

---

## 汎用コンポーネント

### ConfirmDialog (`src/components/ConfirmDialog.vue`)

Promiseベースの汎用確認ダイアログ。`defineExpose({ open })` により親コンポーネントからメソッド呼び出しで使用する。

**公開メソッド:**
```typescript
open(title: string, message?: string, options?: { color?: string }): Promise<boolean>
```

**動作:**
1. `open()` を呼び出すとダイアログが表示される
2. OKボタンクリック → `true` で resolve
3. キャンセルボタンクリック → `false` で resolve
4. `persistent` 属性により、ダイアログ外クリックでは閉じない

**使用例（呼び出し側）:**
```typescript
const confirmRef = ref()
const result = await confirmRef.value.open('削除確認', '本当に削除しますか？', { color: 'error' })
if (result) {
  // 削除処理
}
```

---

## 国際化

### 翻訳定義 (`src/locales/ja.json`)

日本語のみの単一ロケール構成。全てのUI表示テキストがこのファイルで管理される。

**翻訳キー構成（トップレベル）:**

| キー | 説明 | 主要サブキー |
|------|------|------------|
| `topMenu` | ダッシュボード画面 | `welcome`, `teamSelection`, `seasonInitialization`, `seasonPortal` |
| `common` | 共通テキスト | `close` |
| `seasonPortal` | シーズンポータル画面 | `title`, `currentDate`, `gameResult`, `registerAbsence`, `absenceInfo` |
| `playerAbsenceHistory` | 離脱者履歴画面 | `title`, `addAbsence`, `tableHeaders`, `confirmDelete` |
| `playerAbsenceDialog` | 離脱者登録ダイアログ | `title`, `form`, `notifications` |
| `activeRoster` | 出場選手登録画面 | `title`, `firstSquadCount/Cost`, `keyPlayerSelection`, `cooldownInfo`, `headers` |
| `gameResult` | 試合結果入力画面 | `basicInfo`, `homeAway`, `dhSystem`, `score`, `winningPitcher`, `losingPitcher`, `savePitcher` |
| `gameResults` | 試合結果表示 | `win`, `lose`, `draw` |
| `startingMemberDialog` | スタメン登録ダイアログ | `title`, `tableHeaders`, `homeTeamLineup`, `opponentTeamLineup` |
| `actions` | 共通アクションボタン | `save`, `cancel`, `ok` |
| `validation` | バリデーションメッセージ | `required`, `dateFormat`, `defenseFormat` |
| `loginForm` | ログインフォーム | `title`, `loginId`, `password`, `login`, `loggingIn`, `loginFailed` |
| `layout` | レイアウト共通 | `appTitle`, `logout` |
| `navigation` | ナビゲーションメニュー | `dashboard`, `managers`, `teams`, `players`, `costAssignment`, `settings`, `collapse`, `expand` |
| `teamList` | チーム一覧画面 | `title`, `addTeam`, `headers`, `deleteConfirm*`, `notifications` |
| `managerList` | 監督一覧画面 | `title`, `addManager`, `headers`, `expanded`, `deleteConfirm*`, `notifications` |
| `managerDialog` | 監督ダイアログ | `title`, `form`, `notifications` |
| `teamDialog` | チームダイアログ | `title`, `form`, `validation`, `notifications` |
| `settings` | 各種設定画面 | `title`, `description`, `tabs`, `pitchingStyle`, `battingStyle`, `pitchingSkill`, `battingSkill`, `biorhythm`, `cost`, `playerType`, `schedule` |
| `teamMembers` | チームメンバー画面 | `title`, `selectCostList`, `headers`, `costTypes`, `notifications` |
| `costAssignment` | コスト登録画面 | `title`, `costList`, `headers` |
| `playerList` | 選手一覧画面 | `title`, `addPlayer`, `headers`, `deleteConfirm*`, `notifications` |
| `playerDialog` | 選手ダイアログ | `title`, `form`, `notifications` |
| `baseball` | 野球用語 | `positions`, `throwingHands`, `battingHands`, `shortPositions`, `construction`（コスト種別略称） |
| `enums` | 列挙型表示 | `player_absence.absence_type`, `player_absence.duration_unit` |
| `scoreSheet` | スコアシート | `order`, `player`, `position`, `hits`, `rbi` |
| `messages` | その他メッセージ | `startingMembersSaved`, `failedToSaveStartingMembers` |

**翻訳キーの命名規則:**
- 画面ごとにトップレベルキーを分離（`teamList`, `managerList`, `settings` 等）
- `headers` — テーブルヘッダー定義
- `notifications` — 操作結果メッセージ（`fetchFailed`, `addSuccess`, `updateSuccess`, `deleteSuccess`, `saveFailed`, `saveFailedWithErrors`, `deleteFailed`）
- `dialog.title` — ダイアログタイトル（`add`/`edit` で分離）
- `dialog.form` — フォームフィールドラベル
- `deleteConfirmTitle` / `deleteConfirmMessage` — 削除確認ダイアログ

---

## ビルド・開発設定

### Vite設定 (`vite.config.ts`)

```typescript
export default defineConfig({
  plugins: [
    vue(),              // Vue 3 SFCサポート
    vueDevTools(),      // Vue DevToolsプラグイン（開発時）
  ],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))  // @/ パスエイリアス
    },
  },
})
```

**パスエイリアス:** `@` → `./src` ディレクトリにマッピング。全ソースコードで `@/composables/useAuth` のようにインポート可能。

### TypeScript設定

**`tsconfig.json`（ルート）:**
```json
{
  "files": [],
  "references": [
    { "path": "./tsconfig.node.json" },
    { "path": "./tsconfig.app.json" }
  ]
}
```
Project References構成で、アプリケーションコードとNode.js（ビルドツール）設定を分離。

**`tsconfig.app.json`（アプリケーション用）:**
```json
{
  "extends": "@vue/tsconfig/tsconfig.dom.json",
  "include": ["env.d.ts", "src/**/*", "src/**/*.vue"],
  "exclude": ["src/**/__tests__/*"],
  "compilerOptions": {
    "tsBuildInfoFile": "./node_modules/.tmp/tsconfig.app.tsbuildinfo",
    "paths": { "@/*": ["./src/*"] }
  }
}
```
- `@vue/tsconfig/tsconfig.dom.json` を拡張（DOM型定義を含む）
- `@/*` パスエイリアスをTypeScriptにも設定（Vite設定と一致）
- テストファイル（`__tests__/` 配下）を除外

**`tsconfig.node.json`（ビルドツール用）:**
```json
{
  "extends": "@tsconfig/node22/tsconfig.json",
  "include": ["vite.config.*", "vitest.config.*", "cypress.config.*", "nightwatch.conf.*", "playwright.config.*", "eslint.config.*"],
  "compilerOptions": {
    "noEmit": true,
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "types": ["node"]
  }
}
```
- Node.js 22向け設定を拡張
- ビルド・テスト設定ファイルのみ対象
- `moduleResolution: "Bundler"` でVite互換のモジュール解決

### NPMスクリプト

| コマンド | 説明 |
|---------|------|
| `npm run dev` | `vite` — 開発サーバー起動 |
| `npm run build` | `run-p type-check "build-only {@}"` — 型チェックとビルドを並列実行 |
| `npm run preview` | `vite preview` — ビルド成果物のプレビュー |
| `npm run build-only` | `vite build` — Viteビルドのみ |
| `npm run type-check` | `vue-tsc --build` — TypeScript型チェック |
| `npm run lint` | `eslint . --fix` — ESLintによるリント＋自動修正 |
| `npm run format` | `prettier --write src/` — Prettierによるフォーマット |

---

## 関連ファイル一覧

### コア

| ファイルパス | 役割 |
|------------|------|
| `src/main.ts` | アプリケーションエントリポイント（プラグイン登録） |
| `src/App.vue` | ルートコンポーネント（認証チェック起動） |
| `src/layouts/DefaultLayout.vue` | 認証後共通レイアウト |
| `src/router/index.ts` | ルート定義（15ルート） |
| `src/router/authGuard.ts` | 認証・権限ガード |

### プラグイン

| ファイルパス | 役割 |
|------------|------|
| `src/plugins/axios.ts` | HTTP通信設定（baseURL, CSRF, インターセプター） |
| `src/plugins/vuetify.ts` | Vuetify設定（テーマ、アイコン） |
| `src/plugins/i18n.ts` | vue-i18n設定 |

### コンポーザブル

| ファイルパス | 役割 |
|------------|------|
| `src/composables/useAuth.ts` | 認証状態管理（シングルトン） |
| `src/composables/useSnackbar.ts` | グローバルSnackbar管理（シングルトン） |

### 型定義

| ファイルパス | 役割 |
|------------|------|
| `src/types/` 配下24ファイル | APIレスポンス対応の型定義 |

### 共有コンポーネント

| ファイルパス | 役割 |
|------------|------|
| `src/components/shared/TeamSelect.vue` | チーム選択セレクタ |
| `src/components/shared/PlayerSelect.vue` | 選手選択オートコンプリート |
| `src/components/shared/PlayerDetailSelect.vue` | 選手詳細選択（複数） |
| `src/components/shared/TeamMemberSelect.vue` | チームメンバー選択 |
| `src/components/shared/CostListSelect.vue` | コスト一覧選択 |
| `src/components/ConfirmDialog.vue` | 汎用確認ダイアログ |

### 設定ファイル

| ファイルパス | 役割 |
|------------|------|
| `vite.config.ts` | Viteビルド設定 |
| `tsconfig.json` | TypeScript設定ルート |
| `tsconfig.app.json` | アプリケーション用TS設定 |
| `tsconfig.node.json` | ビルドツール用TS設定 |
| `package.json` | パッケージ・スクリプト定義 |

### 国際化

| ファイルパス | 役割 |
|------------|------|
| `src/locales/ja.json` | 日本語翻訳定義（全UI文言） |
