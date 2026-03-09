# Composables & Pinia ストア 仕様書

最終更新日: 2026-03-10

## 参照ソースファイル一覧

- `src/composables/useSnackbar.ts`
- `src/composables/useAuth.ts`
- `src/composables/useLineupTemplate.ts`
- `src/composables/useSquadTextGenerator.ts`
- `src/stores/teamSelection.ts`
- `src/stores/squadText.ts`

---

## Composables

### `useSnackbar` (`src/composables/useSnackbar.ts`)

アプリケーション全体で共有されるスナックバー（トースト通知）を管理するコンポーザブル。
モジュールスコープの `ref` を使って状態をグローバルに共有する設計。

#### 公開 ref / computed

| 名前 | 型 | 説明 |
|------|-----|------|
| `isVisible` | `Readonly<Ref<boolean>>` | スナックバーの表示状態 |
| `message` | `Readonly<Ref<string>>` | 表示するメッセージ |
| `color` | `Readonly<Ref<'success' \| 'error' \| 'info' \| 'warning'>>` | スナックバーの色 |
| `timeout` | `Readonly<Ref<number>>` | 自動非表示までのミリ秒（デフォルト3000ms） |

#### 公開関数

| 名前 | 引数 | 戻り値 | 説明 |
|------|------|--------|------|
| `showSnackbar` | `text: string, snackbarColor?: 'success' \| 'error' \| 'info' \| 'warning'` | `void` | スナックバーを表示する。既存のタイマーをリセットしてから新しいタイマーをセット |

**使用箇所**: ほぼ全ビュー・ダイアログコンポーネントで使用（`TeamDialog`, `ManagerDialog`, `PlayerDialog`, `GenericMasterSettings` 等）

**設計意図**: `ref`をモジュールレベルに置くことで、複数コンポーネントが同じ状態を共有できる。Piniaストア化しない軽量な実装。

---

### `useAuth` (`src/composables/useAuth.ts`)

ユーザー認証状態を管理するコンポーザブル。`useSnackbar`と同様にモジュールスコープの`ref`でグローバル共有。

#### 公開 ref / computed

| 名前 | 型 | 説明 |
|------|-----|------|
| `user` | `Computed<User \| null>` | 現在ログイン中のユーザー情報 |
| `isAuthenticated` | `Computed<boolean>` | 認証済みかどうか |
| `isCommissioner` | `Computed<boolean>` | コミッショナー権限があるかどうか |
| `loading` | `Computed<boolean>` | 認証API呼び出し中フラグ |

`User`型（ファイル内ローカル）:

| 属性 | 型 | 説明 |
|------|-----|------|
| `id` | `number` | ユーザーID |
| `name` | `string` | ユーザー名 |
| `role` | `string` | 役割（commissioner等） |

#### 公開関数

| 名前 | 引数 | 戻り値 | 説明 |
|------|------|--------|------|
| `login` | `name: string, password: string` | `Promise<LoginResponse>` | POST `/auth/login` でログイン。成功時にユーザー情報を保存 |
| `logout` | なし | `Promise<void>` | POST `/auth/logout` でログアウト。成功/失敗問わず `user = null` にリセットし `/login` へリダイレクト |
| `checkAuth` | なし | `Promise<void>` | GET `/auth/current_user` でセッション確認。失敗時は `user = null` |

**使用箇所**: `AppBar.vue`, `NavigationDrawer.vue`, `LoginForm.vue`, `src/router/authGuard.ts`

**設計意図**: ページリロード後のセッション復元は `checkAuth` を `App.vue` のライフサイクルフックから呼び出すことで実現。

---

### `useLineupTemplate` (`src/composables/useLineupTemplate.ts`)

ラインナップテンプレートおよび前回データの読み込みを管理するコンポーザブル。`useSquadTextStore`と連携して状態を反映する。

#### 引数

| 名前 | 型 | 説明 |
|------|-----|------|
| `teamId` | `Ref<number>` | チームID（リアクティブ） |

#### 公開 ref

| 名前 | 型 | 説明 |
|------|-----|------|
| `loading` | `Ref<boolean>` | API呼び出し中フラグ |
| `error` | `Ref<string \| null>` | エラーメッセージ |

#### 公開関数

| 名前 | 引数 | 戻り値 | 説明 |
|------|------|--------|------|
| `loadFromTemplate` | `templateId: number, firstSquadMembers: RosterPlayer[], absentPlayers: RosterPlayer[]` | `Promise<TemplateValidationResult[]>` | GET `/teams/:teamId/lineup_templates/:templateId` からテンプレートを読み込み、`squadText`ストアに反映する |
| `loadFromPrevious` | `firstSquadMembers: RosterPlayer[], absentPlayers: RosterPlayer[]` | `Promise<TemplateValidationResult[] \| null>` | GET `/teams/:teamId/game_lineup` から前回データを読み込む。404の場合は`null`を返す |

**使用箇所**: `SquadTextGenerator.vue`

**設計意図**: ストアへのデータ流し込みを担当する。表示ロジックはストア・Generator composableに委譲。

---

### `useSquadTextGenerator` (`src/composables/useSquadTextGenerator.ts`)

スカッドテキスト（IRC投稿用メンバー表）を生成するコンポーザブル。打順・ベンチ・投手セクションのテキストを算出する。`useSquadTextStore`の状態を参照してテキストを生成。

#### 引数

| 名前 | 型 | 説明 |
|------|-----|------|
| `teamId` | `Ref<number>` | チームID（リアクティブ） |

#### 公開 ref

| 名前 | 型 | 説明 |
|------|-----|------|
| `loading` | `Ref<boolean>` | 初期化中フラグ |
| `settings` | `Ref<SquadTextSettingData>` | 書式設定（ポジション表記・投打表記等） |
| `rosterChangesText` | `Ref<string>` | 公示変更テキスト |

`SquadTextSettingData`（ファイル内ローカル）の主要フィールド:

| 属性 | 型 | 説明 |
|------|-----|------|
| `position_format` | `string` | ポジション表記（`english` / `japanese`） |
| `handedness_format` | `string` | 投打表記（`alphabet` / `kanji`） |
| `section_header_format` | `string` | セクションヘッダー形式（`bracket` / `none`） |
| `show_number_prefix` | `boolean` | 背番号接頭辞表示 |
| `batting_stats_config` | `Record<string, boolean>` | 表示する打撃成績項目 |
| `pitching_stats_config` | `Record<string, boolean>` | 表示する投手成績項目 |

#### 公開 computed

| 名前 | 型 | 説明 |
|------|-----|------|
| `headerText` | `Computed<string>` | 日付ヘッダー行（当日日付 `YYYY/MM/DD` 形式） |
| `starterText` | `Computed<string>` | スタメン打順セクションテキスト |
| `benchHitterText` | `Computed<string>` | 控え野手セクションテキスト |
| `reliefPitcherText` | `Computed<string>` | 中継ぎ投手セクションテキスト |
| `starterBenchText` | `Computed<string>` | 先発ベンチ投手セクションテキスト |
| `offText` | `Computed<string>` | オフ選手セクションテキスト |
| `generatedText` | `Computed<string>` | 上記セクションをまとめた最終生成テキスト |

#### 公開関数

| 名前 | 引数 | 戻り値 | 説明 |
|------|------|--------|------|
| `fetchStats` | `playerIds: number[]` | `Promise<void>` | GET `/teams/:teamId/imported_stats` から打撃・投手成績を取得 |
| `fetchPitcherGameStates` | `pitcherIds: number[]` | `Promise<void>` | GET `/teams/:teamId/pitcher_game_states` から投手ゲーム状態を取得 |
| `fetchSettings` | なし | `Promise<void>` | GET `/teams/:teamId/squad_text_settings` から書式設定を取得 |
| `fetchRosterChanges` | `sinceDate: string, seasonId: number` | `Promise<void>` | GET `/teams/:teamId/roster_changes` から公示変更テキストを取得 |
| `saveAsGameLineup` | なし | `Promise<void>` | PUT `/teams/:teamId/game_lineup` で現在のラインナップを前回データとして保存 |
| `init` | `players: RosterPlayer[]` | `Promise<void>` | 成績・設定の一括取得と投手初期振り分けを実行する初期化関数 |

**使用箇所**: `SquadTextGenerator.vue`

**設計意図**: ストア（`useSquadTextStore`）の状態をテキストに変換する純粋な変換層。データ取得（fetchXxx）と生成（generatedText）を同一コンポーザブルにまとめることで、`SquadTextGenerator.vue`のテンプレートをシンプルに保つ。

---

## Pinia ストア

### `useTeamSelectionStore` (`src/stores/teamSelection.ts`)

ストアID: `teamSelection`

アプリ全体で選択中チームを保持するストア。選択内容を`localStorage`に永続化する。

#### state

| 名前 | 型 | 初期値 | 説明 |
|------|-----|--------|------|
| `selectedTeamId` | `Ref<number \| null>` | localStorage から復元 / `null` | 選択中チームID |
| `selectedTeamName` | `Ref<string>` | localStorage から復元 / `''` | 選択中チーム名 |

#### actions

| 名前 | 引数 | 戻り値 | 説明 |
|------|------|--------|------|
| `selectTeam` | `teamId: number, teamName: string` | `void` | チームを選択してstateとlocalStorageを更新 |
| `clearTeam` | なし | `void` | 選択をリセットしてlocalStorageも削除 |

**使用箇所**: `NavigationDrawer.vue`, `HomePortalView.vue`, `SeasonPortal.vue`等

**状態管理の設計方針**: チーム選択はページをまたいで維持する必要があるため、localStorageへの永続化をストア内で完結させている。

---

### `useSquadTextStore` (`src/stores/squadText.ts`)

ストアID: `squadText`

スカッドテキスト生成のための打順・ベンチ構成状態を管理するストア。`useLineupTemplate`によってデータが投入され、`useSquadTextGenerator`によって参照される。

#### 公開型

```typescript
interface LineupEntry {
  battingOrder: number   // 打順
  playerId: number       // 選手ID
  position: string       // ポジション（例: 'C', '1B'）
  playerName?: string    // 選手名（表示用）
  playerNumber?: string  // 背番号（表示用）
}

interface TemplateValidationResult {
  battingOrder: number
  playerId: number
  status: 'ok' | 'not_first_squad' | 'absent'  // バリデーション結果
  reason?: string         // エラー理由
  candidates?: RosterPlayer[]  // 代替候補
}
```

#### state

| 名前 | 型 | 初期値 | 説明 |
|------|-----|--------|------|
| `mode` | `Ref<'template' \| 'previous' \| null>` | `null` | 読み込みモード |
| `dhEnabled` | `Ref<boolean>` | `false` | DH制フラグ |
| `opponentPitcherHand` | `Ref<'left' \| 'right'>` | `'right'` | 対戦投手の投球腕 |
| `startingLineup` | `Ref<LineupEntry[]>` | `[]` | スタメン打順 |
| `benchPlayers` | `Ref<number[]>` | `[]` | 控え野手IDリスト |
| `offPlayers` | `Ref<number[]>` | `[]` | オフ選手IDリスト |
| `reliefPitcherIds` | `Ref<number[]>` | `[]` | 中継ぎ投手IDリスト |
| `starterBenchPitcherIds` | `Ref<number[]>` | `[]` | 先発ベンチ投手IDリスト |
| `validationResults` | `Ref<TemplateValidationResult[]>` | `[]` | テンプレートバリデーション結果 |

#### actions

| 名前 | 引数 | 戻り値 | 説明 |
|------|------|--------|------|
| `reset` | なし | `void` | 全stateを初期値にリセット |
| `loadFromTemplate` | `entries: LineupEntry[], firstSquadMembers: RosterPlayer[], absentPlayers: RosterPlayer[]` | `void` | テンプレートデータをstoreに反映しバリデーション実行 |
| `loadFromPrevious` | `lineupData: {...}, firstSquadMembers: RosterPlayer[], absentPlayers: RosterPlayer[]` | `void` | 前回データをstoreに反映（DH制・対戦投手手も復元）しバリデーション実行 |

#### getters（なし）

ストア自体にgetterはなく、`useSquadTextGenerator`内のcomputedで算出している。

#### バリデーションロジック（内部）

`validateLineupEntries`関数により以下を判定:
- `absent`: 離脱中（`absentPlayers`に含まれる）
- `not_first_squad`: 2軍（`firstSquadMembers`に含まれない）
- `ok`: 問題なし

**使用箇所**: `SquadTextGenerator.vue`（表示）, `useLineupTemplate.ts`（データ投入）, `useSquadTextGenerator.ts`（テキスト生成）
