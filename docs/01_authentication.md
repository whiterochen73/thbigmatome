# 01. 認証機能仕様書

## 概要

本システムでは、セッションベースの認証機能を採用している。バックエンドはRails 8のセッション管理を使用し、フロントエンドはVue 3 Composition APIを用いてログイン状態を管理する。CSRF保護がグローバルに有効化されており、全てのAPIリクエストにCSRFトークンが必要となる。

**主要な特徴:**
- セッションベース認証（Cookie使用）
- BCryptによるパスワードハッシュ化（`has_secure_password`）
- CSRF保護（全エンドポイントでグローバル有効、ログインアクションのみスキップ）
- ロールベースアクセス制御（general / commissioner）
- Axiosインターセプターによる自動CSRF トークン管理
- ルートガードによる未認証アクセス制限

---

## 画面構成（フロントエンド）

### ログインフォーム画面

**パス:** `/login`

**コンポーネント:** `src/views/LoginForm.vue`

**レイアウト:**
```
┌─────────────────────────────────┐
│                                 │
│    [ログインフォーム]            │
│                                 │
│    ┌─────────────────────┐      │
│    │ ログインID          │      │
│    │ [input text]        │      │
│    └─────────────────────┘      │
│                                 │
│    ┌─────────────────────┐      │
│    │ パスワード          │      │
│    │ [input password]    │      │
│    └─────────────────────┘      │
│                                 │
│    [エラーメッセージ]            │
│                                 │
│    ┌─────────────────────┐      │
│    │  [ログイン]ボタン    │      │
│    └─────────────────────┘      │
│                                 │
└─────────────────────────────────┘
```

**フォームフィールド:**

| フィールドID | ラベル | 入力タイプ | バリデーション | プレースホルダー |
|-------------|--------|-----------|--------------|----------------|
| `loginName` | ログインID | text | required | `t('loginForm.loginIdPlaceholder')` |
| `password` | パスワード | password | required | `t('loginForm.passwordPlaceholder')` |

**ボタン制御:**

| ボタン | 有効条件 | 無効条件 | ラベル（通常時） | ラベル（処理中） |
|--------|---------|---------|-----------------|-----------------|
| ログインボタン | `isFormValid && !loading` | `!isFormValid || loading` | `t('loginForm.login')` | `t('loginForm.loggingIn')` |

**`isFormValid` 計算ロジック:**
```typescript
const isFormValid = computed(() => {
  return form.value.loginName.trim() !== '' && form.value.password.trim() !== ''
})
```

**動作フロー:**

```
[1] ユーザーがログインIDとパスワードを入力
       ↓
[2] フォーム送信（@submit.prevent="handleLogin"）
       ↓
[3] useAuth.login(loginName, password) 呼び出し
       ↓
[4] POST /api/v1/auth/login リクエスト送信
       ↓
[5a] 成功時: router.push('/menu') でメニュー画面へ遷移
       ↓
[5b] 失敗時: エラーメッセージ表示（error.value にセット）
```

**国際化（i18n）キー:**
- `loginForm.title`: ページタイトル
- `loginForm.loginId`: ログインIDラベル
- `loginForm.loginIdPlaceholder`: ログインIDプレースホルダー
- `loginForm.password`: パスワードラベル
- `loginForm.passwordPlaceholder`: パスワードプレースホルダー
- `loginForm.login`: ログインボタンラベル
- `loginForm.loggingIn`: ログイン処理中ボタンラベル
- `loginForm.loginFailed`: ログイン失敗時デフォルトメッセージ

**スタイリング:**
- `.login-container`: 画面中央配置（flexbox）、背景色 `#f5f5f5`
- `.login-card`: 白背景、角丸 `8px`、シャドウあり、最大幅 `400px`
- `.error-message`: 赤系エラー表示（背景 `#f8d7da`, 文字色 `#dc3545`）

---

## APIエンドポイント

### 1. ログイン

**エンドポイント:** `POST /api/v1/auth/login`

**コントローラー:** `Api::V1::AuthController#login`

**CSRF保護:** スキップ（`skip_before_action :verify_authenticity_token`）

**認証要否:** 不要（`skip_before_action :authenticate_user!, only: [:login, :logout]`）

**リクエスト:**
```json
{
  "name": "user123",
  "password": "password123"
}
```

**レスポンス（成功時 200 OK）:**
```json
{
  "user": {
    "id": 1,
    "name": "user123"
  },
  "message": "ログイン成功"
}
```

**レスポンス（失敗時 401 Unauthorized）:**
```json
{
  "error": "メールアドレスまたはパスワードが間違っています"
}
```

**処理フロー:**
```
[1] User.find_by(name: params[:name]) でユーザー検索
       ↓
[2] user&.authenticate(params[:password]) でパスワード検証
       ↓
[3a] 成功時: session[:user_id] = user.id をセット
       ↓     レスポンスに user.slice(:id, :name) を含めて返す
       ↓
[3b] 失敗時: 401 Unauthorized, エラーメッセージ返却
```

**セッション操作:**
- `session[:user_id]` にユーザーIDを格納

**実装コード（`app/controllers/api/v1/auth_controller.rb:8-17`）:**
```ruby
def login
  user = User.find_by(name: params[:name])

  if user&.authenticate(params[:password])
    session[:user_id] = user.id
    render json: { user: user.slice(:id, :name), message: 'ログイン成功' }
  else
    render json: { error: 'メールアドレスまたはパスワードが間違っています' }, status: :unauthorized
  end
end
```

---

### 2. ログアウト

**エンドポイント:** `POST /api/v1/auth/logout`

**コントローラー:** `Api::V1::AuthController#logout`

**CSRF保護:** スキップ（`skip_before_action :verify_authenticity_token`）

**認証要否:** 不要（`skip_before_action :authenticate_user!, only: [:login, :logout]`）

**リクエスト:** なし（パラメータ不要）

**レスポンス（200 OK）:**
```json
{
  "message": "ログアウトしました"
}
```

**処理フロー:**
```
[1] session[:user_id] = nil でセッションクリア
       ↓
[2] session.clear でセッション全体をクリア
       ↓
[3] reset_session でセッションリセット
       ↓
[4] レスポンス返却
```

**セッション操作:**
- `session[:user_id] = nil`
- `session.clear`
- `reset_session`

**実装コード（`app/controllers/api/v1/auth_controller.rb:19-24`）:**
```ruby
def logout
  session[:user_id] = nil
  session.clear
  reset_session
  render json: { message: 'ログアウトしました' }
end
```

---

### 3. 現在ログイン中ユーザー情報取得

**エンドポイント:** `GET /api/v1/auth/current_user`

**コントローラー:** `Api::V1::AuthController#show_current_user`

**CSRF保護:** 有効（グローバル設定）

**認証要否:** 不要（個別にcurrent_userの有無で判定）

**リクエスト:** なし

**レスポンス（ログイン中 200 OK）:**
```json
{
  "user": {
    "id": 1,
    "name": "user123",
    "role": 0
  }
}
```

**レスポンス（未ログイン 401 Unauthorized）:**
```json
{
  "error": "ログインしていません"
}
```

**処理フロー:**
```
[1] current_user ヘルパーメソッドでユーザー取得
       ↓
[2a] current_user が存在する場合:
       → user.slice(:id, :name, :role) をレスポンス
       ↓
[2b] current_user が nil の場合:
       → 401 Unauthorized, エラーメッセージ返却
```

**実装コード（`app/controllers/api/v1/auth_controller.rb:27-34`）:**
```ruby
def show_current_user
  if current_user
    render json: { user: current_user.slice(:id, :name, :role) }
  else
    render json: { error: 'ログインしていません' }, status: :unauthorized
  end
end
```

---

## データモデル

### usersテーブル

**スキーマ定義（`db/schema.rb:363-370`）:**
```ruby
create_table "users", force: :cascade do |t|
  t.string "name"
  t.string "display_name"
  t.string "password_digest"
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.integer "role", default: 0, null: false
end
```

**カラム詳細:**

| カラム名 | 型 | NULL | デフォルト | 説明 |
|---------|----|----|----------|------|
| `id` | bigint | NO | AUTO_INCREMENT | 主キー |
| `name` | string | YES | - | ログインID（ユニーク制約あり） |
| `display_name` | string | YES | - | 表示名 |
| `password_digest` | string | YES | - | BCryptハッシュ化パスワード |
| `created_at` | datetime | NO | - | 作成日時 |
| `updated_at` | datetime | NO | - | 更新日時 |
| `role` | integer | NO | 0 | ロール（0: general, 1: commissioner） |

**インデックス:** なし（name カラムにユニーク制約はモデル層バリデーションで実施）

**外部キー:** なし

---

### Userモデル

**ファイル:** `app/models/user.rb`

**コード全文:**
```ruby
class User < ApplicationRecord
  has_secure_password
  validates :name, presence: true, uniqueness: true
  validates :display_name, presence: true

  enum :role, { general: 0, commissioner: 1 }
end
```

**バリデーション:**

| フィールド | ルール | エラーメッセージ |
|-----------|-------|---------------|
| `name` | 必須、ユニーク | 標準Railsバリデーションメッセージ |
| `display_name` | 必須 | 標準Railsバリデーションメッセージ |
| `password` | `has_secure_password`により自動バリデーション | BCryptによる検証 |

**Enum定義:**
```ruby
enum :role, { general: 0, commissioner: 1 }
```
- `general`: 一般ユーザー（デフォルト）
- `commissioner`: コミッショナー権限

**has_secure_password の機能:**
- `password` および `password_confirmation` 仮想属性を追加
- `password_digest` カラムに BCrypt ハッシュを保存
- `authenticate(password)` メソッドを提供（パスワード検証用）

**リレーション:** なし

**スコープ:** なし

---

## ビジネスロジック

### 認証フロー

#### ログインフロー

```
[フロントエンド]
  ユーザーがLoginForm.vueでログインID/パスワード入力
       ↓
  handleLogin() 実行
       ↓
  useAuth.login(loginName, password) 呼び出し
       ↓
  axios.post('auth/login', { name, password }) 実行
       ↓

[バックエンド]
  POST /api/v1/auth/login リクエスト受信
       ↓
  AuthController#login アクション実行
       ↓
  User.find_by(name: params[:name]) でユーザー検索
       ↓
  user&.authenticate(params[:password]) でパスワード検証
       ↓
  [成功時]
    session[:user_id] = user.id をセット
    → { user: { id, name }, message: 'ログイン成功' } を返却
       ↓

[フロントエンド]
  レスポンス受信
       ↓
  user.value = response.data.user にユーザー情報格納
       ↓
  router.push('/menu') でメニュー画面へ遷移
```

#### ログアウトフロー

```
[フロントエンド]
  ユーザーがログアウトボタンクリック
       ↓
  useAuth.logout() 呼び出し
       ↓
  axios.post('auth/logout') 実行
       ↓

[バックエンド]
  POST /api/v1/auth/logout リクエスト受信
       ↓
  AuthController#logout アクション実行
       ↓
  session[:user_id] = nil
  session.clear
  reset_session
       ↓
  { message: 'ログアウトしました' } を返却
       ↓

[フロントエンド]
  レスポンス受信
       ↓
  user.value = null にユーザー情報クリア
       ↓
  router.push('/login') でログイン画面へ遷移
```

#### 認証状態チェックフロー（ページ遷移時）

```
[フロントエンド]
  ルート変更検知（Vue Router）
       ↓
  authGuard(to, from, next) 実行
       ↓
  [ログインページへの遷移の場合]
    isAuthenticated.value をチェック
      → ログイン済みなら next('/menu')
      → 未ログインなら next()
       ↓
  [その他のページの場合]
    useAuth.checkAuth() 呼び出し
       ↓
    axios.get('auth/current_user') 実行
       ↓

[バックエンド]
  GET /api/v1/auth/current_user リクエスト受信
       ↓
  AuthController#show_current_user アクション実行
       ↓
  current_user ヘルパーでユーザー取得
    → session[:user_id] から User.find(session[:user_id])
       ↓
  [ログイン中]
    { user: { id, name, role } } を返却
       ↓

[フロントエンド]
  レスポンス受信
       ↓
  user.value = response.data.user にセット
       ↓
  authGuard が遷移先のメタ情報をチェック
    - to.meta.requiresAuth && !isAuthenticated
      → next('/login')
    - to.meta.requiresCommissioner && !isCommissioner
      → next('/menu')
    - それ以外
      → next()
```

---

### CSRF保護

#### 全体方針

本システムでは、Rails標準のCSRF保護機能を**グローバルに有効化**している。ただし、ログインアクションのみ例外的にCSRF保護をスキップする。

#### バックエンド設定

**ApplicationController（`app/controllers/application_controller.rb`）:**
```ruby
class ApplicationController < ActionController::API
  # CSRF保護を有効にする
  include ActionController::RequestForgeryProtection
  protect_from_forgery with: :exception # 例外を発生させる

  # フロントエンドにCSRFトークンを送信するためのメソッド (Ajax通信用)
  # これにより、Railsのセッションクッキーが送信されると同時に、
  # X-CSRF-Token ヘッダーにトークンがセットされる
  before_action :set_csrf_token_header

  include ActionController::Cookies

  private

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end

  def authenticate_user!
    render json: { error: 'ログインが必要です' }, status: :unauthorized unless current_user
  end

  def set_csrf_token_header
    if protect_against_forgery?
      # ヘッダーにX-CSRF-Tokenとしてトークンをセット
      # このトークンは、フォーム送信時やAjaxリクエスト時に
      # フロントエンドがリクエストヘッダーに含める必要がある
      response.set_header('X-CSRF-Token', form_authenticity_token)
    end
  end
end
```

**重要ポイント:**
- `ActionController::API` を継承しつつ、CSRF保護を有効化
- `protect_from_forgery with: :exception` により、トークン不一致時は例外発生
- `set_csrf_token_header` により、**全てのレスポンスに `X-CSRF-Token` ヘッダーを付与**
- `include ActionController::Cookies` によりCookie使用を有効化

**AuthController のスキップ設定（`app/controllers/api/v1/auth_controller.rb:2-6`）:**
```ruby
class Api::V1::AuthController < ApplicationController
  # ログインとログアウトは認証不要
  # ログインアクション (例: create) ではCSRF保護をスキップ
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!, only: [:login, :logout], raise: false
```

- `skip_before_action :verify_authenticity_token` により、AuthController全体でCSRF保護をスキップ
- ログイン前はCSRFトークンを持っていないため、スキップが必須

#### フロントエンド設定

**Axiosプラグイン（`src/plugins/axios.ts`）:**
```typescript
// src/plugins/axios.ts
import axios, { AxiosError, type AxiosResponse } from 'axios';
import router from '@/router';

axios.defaults.baseURL = 'http://localhost:3000/api/v1';
axios.defaults.withCredentials = true;

// レスポンスインターセプター
axios.interceptors.response.use(
  (response: AxiosResponse) => {
    // レスポンスヘッダーからCSRFトークンを確実に取得するロジック
    const csrfToken = response.headers['x-csrf-token'] || response.headers['X-CSRF-Token'] || response.headers['X-Csrf-Token'];

    if (csrfToken) {
      axios.defaults.headers.common['X-CSRF-Token'] = csrfToken;
    }
    return response;
  },
  (error: AxiosError) => {
    console.error('Axios plugin: Response interceptor error.', error.config?.url, error.response?.status);
    if (error.response?.status === 401) {
      console.warn('Authentication error (401). Redirecting to login page.');
      router.push('/login');
    } else if (error.response?.status === 403) {
      console.warn('Authorization error (403). Access denied.');
    }
    return Promise.reject(error);
  }
);

export default axios;
```

**動作:**
1. `withCredentials: true` により、全リクエストでCookieを送信
2. レスポンスインターセプターで `X-CSRF-Token` ヘッダーを抽出
3. 次回リクエスト以降、`axios.defaults.headers.common['X-CSRF-Token']` にトークンを自動付与
4. 401エラー時は自動的に `/login` へリダイレクト

**トークン取得タイミング:**
- ログイン成功時のレスポンスで初回トークン取得
- 以降、全APIレスポンスにトークンが含まれるため、常に最新のトークンを保持

---

## フロントエンド実装詳細

### useAuth Composable

**ファイル:** `src/composables/useAuth.ts`

**型定義:**
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

**Reactive状態:**
```typescript
const user = ref<User | null>(null)
const loading = ref(false)
```

**公開API:**

| メソッド/プロパティ | 型 | 説明 |
|------------------|----|----|
| `user` | `ComputedRef<User \| null>` | 現在のログインユーザー情報（computed） |
| `isAuthenticated` | `ComputedRef<boolean>` | ログイン状態（`!!user.value`） |
| `isCommissioner` | `ComputedRef<boolean>` | コミッショナー権限有無（`user.value?.role === 'commissioner'`） |
| `loading` | `ComputedRef<boolean>` | API処理中フラグ |
| `login(name, password)` | `Promise<LoginResponse>` | ログイン実行 |
| `logout()` | `Promise<void>` | ログアウト実行 |
| `checkAuth()` | `Promise<void>` | 現在の認証状態をサーバーに問い合わせ |

**`login(name: string, password: string)` メソッド:**
```typescript
const login = async (name: string, password: string): Promise<LoginResponse> => {
  loading.value = true
  try {
    const response = await axios.post<LoginResponse>('auth/login', {
      name,
      password
    })
    user.value = response.data.user
    return response.data
  } catch (error: any) {
    if (error.response?.data?.error) {
      throw new Error(error.response.data.error)
    }
    throw new Error('ログインに失敗しました')
  } finally {
    loading.value = false
  }
}
```

**`logout()` メソッド:**
```typescript
const logout = async (): Promise<void> => {
  loading.value = true
  try {
    await axios.post('auth/logout')
    user.value = null // 認証状態をクリア
    // ログアウト成功後、明示的にログインページへリダイレクト
    router.push('/login') // ★ここを追加★
  } catch (error) {
    console.error('ログアウト時にエラーが発生しました:', error)
    user.value = null // エラー時も一応認証状態をクリアしておく
  } finally {
    loading.value = false
  }
}
```

**`checkAuth()` メソッド:**
```typescript
const checkAuth = async (): Promise<void> => {
  try {
    const response = await axios.get<{ user: User }>('auth/current_user')
    user.value = response.data.user
  } catch (error) {
    user.value = null
  }
}
```

**重要な挙動:**
- `user` 状態は ref として内部管理され、computed で公開（リアクティブ維持）
- `login` 成功時、`user.value` にユーザー情報を格納
- `logout` 実行後、`user.value = null` でクリアし、`router.push('/login')` で画面遷移
- エラー時は常に `user.value = null` にして認証状態をクリア

---

### authGuard ルートガード

**ファイル:** `src/router/authGuard.ts`

**型シグネチャ:**
```typescript
export async function authGuard(
  to: RouteLocationNormalized,
  from: RouteLocationNormalized,
  next: NavigationGuardNext
)
```

**処理フロー全文:**

```typescript
// authGuard.ts
import { type NavigationGuardNext, type RouteLocationNormalized } from 'vue-router'
import { useAuth } from '@/composables/useAuth'

export async function authGuard(
  to: RouteLocationNormalized,
  from: RouteLocationNormalized,
  next: NavigationGuardNext
) {
  const { isAuthenticated, checkAuth, isCommissioner } = useAuth()

  // ログインページへの遷移中に checkAuth を呼ばないようにする
  // または、checkAuth の結果で適切に遷移を制御する
  if (to.path === '/login') {
    // ログインページへのアクセスの場合、checkAuthは行わない (無限ループ回避)
    // ただし、ログイン済みであればメニュー画面へリダイレクト
    if (isAuthenticated.value) {
      next('/menu')
    } else {
      next() // 未ログインであればそのままログインページへ
    }
    return; // ここでガードの処理を終了
  }

  // それ以外のページの場合のみ認証チェックを行う
  await checkAuth()

  if (to.meta.requiresAuth && !isAuthenticated.value) {
    // 認証が必要なページで未認証の場合、ログインページへリダイレクト
    next('/login')
  } else if (to.meta.requiresCommissioner && !isCommissioner.value) {
    // コミッショナー権限が必要なページでコミッショナーでない場合、メニュー画面へリダイレクト
    next('/menu')
  } else if (to.path === '/menu' && !to.meta.requiresAuth && isAuthenticated.value) {
    // この条件は通常発生しないが、念のため
    // 例外的なケースでログイン済みで/menuにいるがrequiresAuthがfalseの場合など
    next()
  } else {
    next()
  }
}
```

**重要な設計判断:**
- `/login` への遷移時は `checkAuth()` を呼ばない（無限ループ回避）
- `/login` 以外のページでは常に `checkAuth()` を実行し、サーバー側のセッション状態と同期
- ルートメタ情報 `requiresAuth` / `requiresCommissioner` で権限制御

---

### ルーティング設定

**ファイル:** `src/router/index.ts`

**ルートメタ情報の例:**

```typescript
const routes: RouteRecordRaw[] = [
  {
    path: '/login',
    name: 'Login',
    component: LoginForm,
    meta: { requiresAuth: false }
  },
  {
    path: '/',
    component: DefaultLayout,
    meta: { requiresAuth: true },
    children: [
      {
        path: '',
        redirect: '/menu'
      },
      {
        path: 'menu',
        name: 'ダッシュボード',
        component: TopMenu,
        meta: { title: 'ダッシュボード' }
      },
      // ... 他のルート
      {
        path: 'commissioner/leagues',
        name: 'Leagues',
        component: () => import('@/views/commissioner/LeaguesView.vue'),
        meta: { requiresAuth: true, requiresCommissioner: true, title: 'リーグ管理' }
      }
    ]
  }
]

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes
})

// 認証ガードを適用
router.beforeEach(authGuard)

export default router
```

**メタフィールド:**
- `requiresAuth: true` — 認証必須（未認証ならログインページへ）
- `requiresCommissioner: true` — コミッショナー権限必須（権限不足ならメニューへ）
- `title` — ページタイトル（認証とは無関係）

---

## セキュリティ考慮事項

### パスワード保護

- BCryptによるハッシュ化（`has_secure_password`）
- `password_digest` カラムに保存、平文パスワードは保存しない
- デフォルトコストファクター使用

### セッション管理

- Rails標準のCookieベースセッション
- `session[:user_id]` にユーザーIDのみ格納
- ログアウト時に `reset_session` で完全リセット

### CSRF保護

- Rails標準CSRF保護機能（`protect_from_forgery with: :exception`）
- トークン不一致時は例外発生（ステータス 422）
- ログインアクションのみCSRF保護スキップ（初回トークン取得のため）

### 認証状態の検証

- 全エンドポイントで `before_action :authenticate_user!`（ApplicationController経由）
- `current_user` ヘルパーでセッションからユーザー取得
- 認証失敗時は 401 Unauthorized レスポンス

### フロントエンド側の権限制御

- ルートガードによる未認証アクセス防止
- `isCommissioner` computed によるコミッショナー権限チェック
- Axiosインターセプターによる401エラー時自動ログインリダイレクト

---

## 関連ファイル一覧

### バックエンド

| ファイルパス | 役割 |
|------------|------|
| `app/controllers/api/v1/auth_controller.rb` | 認証エンドポイント（login/logout/current_user） |
| `app/controllers/application_controller.rb` | CSRF保護、current_user/authenticate_user! ヘルパー |
| `app/models/user.rb` | Userモデル（バリデーション、role enum） |
| `db/schema.rb:363-370` | usersテーブル定義 |
| `config/routes.rb:14-16` | 認証ルート定義 |

### フロントエンド

| ファイルパス | 役割 |
|------------|------|
| `src/views/LoginForm.vue` | ログインフォーム画面 |
| `src/composables/useAuth.ts` | 認証状態管理Composable |
| `src/router/authGuard.ts` | ルートガード（認証チェック） |
| `src/router/index.ts` | ルーティング設定（メタ情報定義） |
| `src/plugins/axios.ts` | Axios設定（CSRF トークン自動管理） |

---

## 既知の問題点と制約

### 1. role enumの型不一致

**問題:** `User` モデルでは `role` が integer enum（0: general, 1: commissioner）として定義されているが、フロントエンドの型定義では以下のように文字列として扱っている箇所がある:

```typescript
// src/composables/useAuth.ts:25
const isCommissioner = computed(() => user.value?.role === 'commissioner')
```

実際のAPIレスポンスでは `role` は数値（0 or 1）で返却されるため、上記の比較は常に `false` となる。

**影響範囲:**
- コミッショナー権限チェックが正常に機能しない
- コミッショナー専用画面（`/commissioner/leagues`など）へのアクセスが不可能

**修正案1（フロントエンド修正）:**
```typescript
const isCommissioner = computed(() => user.value?.role === 1)
```

**修正案2（バックエンドにシリアライザー追加）:**
```ruby
# app/serializers/user_serializer.rb
class UserSerializer < ActiveModel::Serializer
  attributes :id, :name, :role_name

  def role_name
    object.role
  end
end
```

### 2. ログインエラーメッセージの不適切な表現

**問題:** エラーメッセージが「メールアドレスまたはパスワードが間違っています」となっているが、本システムではメールアドレスではなくログインIDを使用している。

**現在の実装（`auth_controller.rb:15`）:**
```ruby
render json: { error: 'メールアドレスまたはパスワードが間違っています' }, status: :unauthorized
```

**推奨修正:**
```ruby
render json: { error: 'ログインIDまたはパスワードが間違っています' }, status: :unauthorized
```

### 3. ユーザー登録機能の未実装

**現状:** ルーティングに `post 'users', to: 'users#create'` が定義されているが、コントローラー実装は未確認。通常、新規ユーザー登録フローが必要。

**影響:** 現時点では、データベース直接操作またはシードデータでユーザーを作成する必要がある。

### 4. パスワードリセット機能の未実装

**現状:** パスワード忘れ時の復旧手段が存在しない。

**影響:** パスワード忘失時はデータベース管理者による手動リセットが必要。

---

## 今後の拡張可能性

### パスワードリセット機能

将来的には以下を実装可能:
- パスワードリセットトークン発行エンドポイント
- メール送信機能（Action Mailer）
- トークン有効期限管理

### 多要素認証（MFA）

TOTP（Time-based One-Time Password）などの導入可能:
- usersテーブルに `otp_secret` カラム追加
- ログインフロー拡張（2段階認証）

### リフレッシュトークン方式への移行

現在のセッションベース認証から、JWT + リフレッシュトークン方式への移行も検討可能:
- トークンベース認証への切り替え
- フロントエンドでのトークン管理（localStorage or secure cookie）

---

## まとめ

本認証機能は、セッションベース認証とCSRF保護を組み合わせた、標準的なRails + Vue構成を採用している。フロントエンドではComposition APIとルートガードを活用し、バックエンドでは`has_secure_password`とenum roleによるシンプルな権限管理を実現している。

**主要な特徴:**
- セッションCookieによる認証状態管理
- グローバルCSRF保護（ログインのみ例外）
- Axiosインターセプターによる自動トークン管理
- Vue Router ガードによるアクセス制御
- ロールベース権限管理（general / commissioner）

**既知の課題:**
- role enumの型不一致（integer vs string）
- エラーメッセージの表現不整合

今後の拡張として、パスワードリセット機能や多要素認証の追加が検討できる。
