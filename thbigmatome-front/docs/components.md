# コンポーネント仕様書

最終更新日: 2026-03-10

## 参照ソースファイル一覧

- `src/components/AppBar.vue`
- `src/components/AppFooter.vue`
- `src/components/NavigationDrawer.vue`
- `src/components/EmptyState.vue`
- `src/components/ConfirmDialog.vue`
- `src/components/TeamNavigation.vue`
- `src/components/TeamDialog.vue`
- `src/components/ManagerDialog.vue`
- `src/components/Scoreboard.vue`
- `src/components/AtBatCard.vue`
- `src/components/BattingTable.vue`
- `src/components/PlayerCardItem.vue`
- `src/components/AbsenceInfo.vue`
- `src/components/PromotionCooldownInfo.vue`
- `src/components/PlayerAbsenceFormDialog.vue`
- `src/components/StartingMemberDialog.vue`
- `src/components/SeasonInitializationDialog.vue`
- `src/components/season/SeasonAbsenceTab.vue`
- `src/components/season/SeasonRosterTab.vue`
- `src/components/squad/SquadTextSettings.vue`
- `src/components/squad/SquadTextGenerator.vue`
- `src/components/squad/LineupTemplateEditor.vue`
- `src/components/players/PlayerDialog.vue`
- `src/components/players/PlayerIdentityForm.vue`
- `src/components/settings/GenericMasterSettings.vue`
- `src/components/settings/BattingSkillSettings.vue`
- `src/components/settings/PitchingSkillSettings.vue`
- `src/components/settings/BiorhythmSettings.vue`
- `src/components/settings/CostSettings.vue`
- `src/components/settings/PlayerTypeSettings.vue`
- `src/components/settings/BattingStyleSettings.vue`
- `src/components/settings/PitchingStyleSettings.vue`
- `src/components/settings/ScheduleSettings.vue`
- `src/components/shared/TeamMemberSelect.vue`
- `src/components/shared/CostListSelect.vue`
- `src/components/shared/PlayerDetailSelect.vue`
- `src/components/shared/PlayerSelect.vue`
- `src/components/shared/TeamSelect.vue`

---

## レイアウト系コンポーネント

### `AppBar.vue` (`src/components/AppBar.vue`)

アプリケーションの最上部に常時表示されるナビゲーションバー。

**props**: なし

**emits**:

| イベント名 | payload | 説明 |
|-----------|---------|------|
| `toggle-drawer` | なし | ナビゲーションドロワーの開閉トグル |

**主要機能・責務**:
- ハンバーガーボタンでドロワー開閉
- タイトルクリックでホームへナビゲーション
- ライト/ダークテーマ切り替え（`localStorage`に保存）
- ユーザーメニュー（ユーザー名表示・ログアウト）
- `useAuth`でユーザー情報・ログアウト処理を取得

**使用箇所**: `DefaultLayout.vue`

---

### `AppFooter.vue` (`src/components/AppFooter.vue`)

アプリケーション下部に表示されるフッター。バージョン番号を表示。

**props**: なし
**emits**: なし
**主要機能・責務**: バージョン表示のみ（`v0.1.0`）

**使用箇所**: `DefaultLayout.vue`

---

### `NavigationDrawer.vue` (`src/components/NavigationDrawer.vue`)

左側のナビゲーションドロワー。レール（縮小）モードとフル表示モードをサポート。

**props**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `modelValue` | `boolean` | ✓ | ドロワーの表示状態 |
| `rail` | `boolean` | ✓ | レール（縮小）モードフラグ |

**emits**:

| イベント名 | payload | 説明 |
|-----------|---------|------|
| `update:modelValue` | `boolean` | ドロワー表示状態変更 |
| `update:rail` | `boolean` | レールモード切り替え |

**主要機能・責務**:
- 通常メニュー（ホーム・試合ログ・レビュー・試合一覧・成績・選手カード）
- コミッショナー専用メニュー（`isCommissioner`が`true`の時のみ表示）
- 選択チームがある場合のみシーズンメニューを表示
- 外部リンク（公式Wiki）
- レール/フル表示のトグルボタン

**使用箇所**: `DefaultLayout.vue`

---

## 汎用UIコンポーネント

### `EmptyState.vue` (`src/components/EmptyState.vue`)

データが空の際に表示する共通空状態表示コンポーネント。

**props**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `icon` | `string` | ✓ | Material Design Iconsアイコン名（例: `mdi-account`） |
| `message` | `string` | ✓ | 表示メッセージ |

**emits**: なし
**使用箇所**: 各リストビュー・タブで空状態表示に使用

---

### `ConfirmDialog.vue` (`src/components/ConfirmDialog.vue`)

確認ダイアログ。Promiseを使った非同期API（`open()`メソッド）で使用する。

**props**: なし
**emits**: なし

**exposeメソッド**:

| 名前 | 引数 | 戻り値 | 説明 |
|------|------|--------|------|
| `open` | `title: string, message?: string, options?: { color?: string }` | `Promise<boolean>` | ダイアログを開いてユーザーの確認/キャンセルを待つ。OKで`true`、キャンセルで`false` |

**使用箇所**: `GenericMasterSettings.vue`（削除確認）、各ビューの削除操作

---

## チーム関連コンポーネント

### `TeamNavigation.vue` (`src/components/TeamNavigation.vue`)

チーム画面内のタブナビゲーション（チームメンバー・1軍ロスター・シーズンポータル・離脱履歴）。

**props**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `teamId` | `number \| string` | ✓ | チームID |

**emits**: なし

**主要機能・責務**:
- 4タブのルーター連動ナビゲーション
- `SeasonPortal`への`tab`クエリパラメータ付きリンク生成
- 現在のルート名に基づいてアクティブタブを計算

**使用箇所**: `TeamMembers.vue`（view）, `SeasonPortal.vue`（view）

---

### `TeamDialog.vue` (`src/components/TeamDialog.vue`)

チームの新規作成・編集ダイアログ。

**props**:

| 名前 | 型 | 必須 | デフォルト | 説明 |
|------|-----|------|-----------|------|
| `isVisible` | `boolean` | ✓ | `false` | ダイアログ表示フラグ |
| `team` | `Team \| null` | ✓ | `null` | 編集対象チーム（nullの場合は新規作成） |
| `defaultManagerId` | `number \| null` | - | `null` | 新規作成時の初期監督ID |

**emits**:

| イベント名 | payload | 説明 |
|-----------|---------|------|
| `update:isVisible` | `boolean` | ダイアログ表示状態変更 |
| `save` | なし | 保存完了通知（親で一覧再取得） |

**主要機能・責務**:
- チーム名・略称・監督・コーチ・アクティブフラグの入力フォーム
- POST `/teams` または PATCH `/teams/:id` でAPIコール
- `useSnackbar`でフィードバック表示

**使用箇所**: `TeamList.vue`（view）

---

### `ManagerDialog.vue` (`src/components/ManagerDialog.vue`)

監督の新規作成・編集ダイアログ。

**props**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `isVisible` | `boolean` | ✓ | ダイアログ表示フラグ |
| `manager` | `Manager \| null` | ✓ | 編集対象監督（nullの場合は新規作成） |

**emits**:

| イベント名 | payload | 説明 |
|-----------|---------|------|
| `update:isVisible` | `boolean` | ダイアログ表示状態変更 |
| `save` | なし | 保存完了通知 |

**主要機能・責務**:
- 名前・略称・IRC名・ユーザーIDの入力フォーム
- POST `/managers` または PATCH `/managers/:id` でAPIコール

**使用箇所**: `ManagerList.vue`（view）

---

## 試合関連コンポーネント

### `Scoreboard.vue` (`src/components/Scoreboard.vue`)

イニング別スコアボード表示・編集コンポーネント。

**props**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `modelValue` | `Scoreboard` | ✓ | スコアボードデータ（home/awayのイニング配列） |
| `homeTeamName` | `string` | ✓ | ホームチーム名 |
| `awayTeamName` | `string` | ✓ | アウェイチーム名 |

**emits**:

| イベント名 | payload | 説明 |
|-----------|---------|------|
| `update:modelValue` | `Scoreboard` | スコアボード変更（v-model対応） |

**主要機能・責務**:
- イニング別得点の表・編集（`v-text-field`）
- 合計スコアの自動計算
- イニング追加・削除ボタン
- サヨナラ（コールドゲーム）チェックボックス（ホーム最終イニングを削除）

**使用箇所**: `GameResult.vue`（view）, `GameDetailView.vue`（view）

---

### `AtBatCard.vue` (`src/components/AtBatCard.vue`)

1打席分の詳細表示・編集カードコンポーネント。折りたたみ式で詳細を開閉する。

**props**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `ab` | `AtBatRecord` | ✓ | 打席記録データ |
| `gameStatus` | `'draft' \| 'confirmed'` | ✓ | 試合ステータス（draftのみ編集可） |
| `activeFilter` | `string \| undefined` | - | 表示フィルタ（`all` / `declaration` / `dice` / `discrepancy`） |

**emits**:

| イベント名 | payload | 説明 |
|-----------|---------|------|
| `updated` | `AtBatRecord` | 打席記録更新完了 |
| `error` | `string` | エラーメッセージ |

**主要機能・責務**:
- ヘッダー: 打者名・投手名・結果コード・差異/確認済みバッジ表示
- ボディ: `source_events`あり → タイムライン表示（宣言/ダイス/自動計算/スキップセクション）
- ボディ: `source_events`なし → レガシーフィールド表示
- 差異（discrepancy）バナー: 原因ラベル・解決策バッジ
- 編集フォーム: 結果コード・得点・走者前後・レビューメモ（`gameStatus === 'draft'`時のみ）
- PATCH `/at_bat_records/:id` で保存
- 結果コードに応じた色分け（HR=紫、安打=緑、四死球=青、アウト=赤等）

**使用箇所**: `GameRecordDetailView.vue`（view）

---

### `BattingTable.vue` (`src/components/BattingTable.vue`)

選手カードの打撃結果テーブル（出目×投手フェーズ）を色分け表示するコンポーネント。

**props**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `table` | `string[][]` | ✓ | 打撃結果テーブルデータ（行=出目2〜12、列=投手フェーズ） |

**emits**: なし

**主要機能・責務**:
- 各セルをIRC結果コードに応じて色分け（安打/四死球=橙、アウト=赤、進塁打=青、レンジ=緑、UP=紫）
- スラッシュセル（2つの結果）はグラジエント表示
- ダーク/ライトテーマに対応（`vuetify`の`useTheme`を参照）
- 凡例表示

**使用箇所**: `PlayerCardDetailView.vue`（view）

---

### `PlayerCardItem.vue` (`src/components/PlayerCardItem.vue`)

選手カード一覧グリッドの1枚分カード表示コンポーネント。

**props**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `card` | `PlayerCard` | ✓ | 選手カードデータ |

**emits**:

| イベント名 | payload | 説明 |
|-----------|---------|------|
| `click` | なし | カードクリック時 |

**主要機能・責務**:
- カード画像（`image_url`あり）またはプレースホルダーアイコン表示
- 選手名・背番号・種別チップ（投手/野手）・ポジション・コスト・走力・特殊能力テキスト表示
- ホバーでカードが浮き上がるアニメーション

**使用箇所**: `PlayerCardsView.vue`（view）

---

## シーズン関連コンポーネント

### `AbsenceInfo.vue` (`src/components/AbsenceInfo.vue`)

シーズン現在日付時点での離脱中選手一覧をアラートで表示。

**props**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `seasonId` | `number \| null` | ✓ | シーズンID（nullの場合はAPIを呼ばない） |
| `currentDate` | `string` | ✓ | 現在日付（ISO文字列） |

**emits**: なし

**exposeメソッド**:

| 名前 | 説明 |
|------|------|
| `fetchPlayerAbsences` | 離脱情報を再取得する（親から呼び出し可能） |

**主要機能・責務**:
- GET `/player_absences?season_id=N` で離脱情報取得
- `currentDate`と各離脱の期間を比較し、現在離脱中のみ表示
- `duration_unit='days'`は日付計算、`'games'`は`effective_end_date`を使用
- 離脱者ゼロ時は青、あり時は赤のアラートスタイル

**使用箇所**: `SeasonRosterTab.vue`

---

### `PromotionCooldownInfo.vue` (`src/components/PromotionCooldownInfo.vue`)

昇格クールダウン中の選手一覧をアラートで表示。

**props**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `cooldownPlayers` | `RosterPlayer[]` | ✓ | クールダウン中の選手一覧（親で計算済み） |
| `currentDate` | `string` | ✓ | 現在日付（ISO文字列） |

**emits**: なし

**主要機能・責務**:
- クールダウン選手のリスト表示
- `same_day_exempt`フラグに応じてメッセージを切り替え

**使用箇所**: `SeasonRosterTab.vue`

---

### `PlayerAbsenceFormDialog.vue` (`src/components/PlayerAbsenceFormDialog.vue`)

選手離脱記録の新規作成・編集ダイアログ。`v-model`（defineModel）で表示状態を管理。

**props**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `modelValue` | `boolean` | ✓ | ダイアログ表示状態（v-model用） |
| `seasonId` | `number` | ✓ | シーズンID |
| `teamId` | `number` | ✓ | チームID |
| `initialStartDate` | `string` | ✓ | 新規作成時の初期開始日 |
| `initialAbsence` | `PlayerAbsence \| null \| undefined` | - | 編集対象（nullの場合は新規作成） |

**emits**:

| イベント名 | payload | 説明 |
|-----------|---------|------|
| `saved` | なし | 保存完了通知 |

**主要機能・責務**:
- `TeamMemberSelect`でチームメンバーを選択
- 離脱種別（負傷/出場停止/再調整）・理由・開始日・期間・単位の入力
- POST `/player_absences` または PUT `/player_absences/:id`

**使用箇所**: `SeasonAbsenceTab.vue`

---

### `SeasonAbsenceTab.vue` (`src/components/season/SeasonAbsenceTab.vue`)

シーズンポータルの「離脱者」タブ。現在離脱中の選手一覧・過去の離脱履歴・追加/編集/削除機能を提供。

**props**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `teamId` | `number` | ✓ | チームID |

**emits**: なし

**主要機能・責務**:
- GET `/teams/:teamId/season` でシーズン情報取得
- GET `/player_absences?season_id=N` で離脱情報取得
- 現在離脱中（`activeAbsences`）と過去離脱（`pastAbsences`）を`effective_end_date`で分類
- 残日数表示（2日以下は緑色ハイライト）
- `PlayerAbsenceFormDialog`で編集
- DELETE `/player_absences/:id` で削除

**使用箇所**: `SeasonPortal.vue`（view）の離脱者タブ

---

### `SeasonRosterTab.vue` (`src/components/season/SeasonRosterTab.vue`)

シーズンポータルの「ロスター」タブ。1軍・2軍の選手一覧表示と昇格/降格操作を提供する。

**props**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `teamId` | `number` | ✓ | チームID |

**emits**: なし

**主要機能・責務**:
- GET `/teams/:teamId/roster` で選手一覧・シーズン情報取得
- 1軍（最大29人）・2軍の2カラム表示
- 1軍コスト合計と上限（人数連動: 25人→114、26人→117、27人→119、28人→120）
- 外の世界キャラ上限（4人）チェック
- 昇格/降格ボタン（特例選手・再調整中は昇格不可）
- 離脱中選手の昇格時は確認ダイアログを表示
- `AbsenceInfo`, `PromotionCooldownInfo`を内包
- 特例選手（シーズン開幕日のみ選択可）の設定
- 投手グループ（先発/中継ぎ/野手）に分けてテーブル表示
- POST `/teams/:teamId/roster` でロスター保存
- POST `/teams/:teamId/key_player` で特例選手保存

**使用箇所**: `SeasonPortal.vue`（view）のロスタータブ

---

## スカッド（Squad）コンポーネント

### `SquadTextSettings.vue` (`src/components/squad/SquadTextSettings.vue`)

スカッドテキスト書式設定コンポーネント。APIから設定を読み込み・保存する。

**props**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `teamId` | `number` | ✓ | チームID |

**emits**: なし

**主要機能・責務**:
- GET `/teams/:teamId/squad_text_settings` で設定読み込み
- ポジション表記（英語/日本語）・投打表記（アルファベット/漢字）・セクションヘッダー・背番号接頭辞の設定
- 打者/投手成績表示項目の個別ON/OFF切り替え
- PUT `/teams/:teamId/squad_text_settings` で保存

**使用箇所**: `SeasonPortal.vue`（view）のオーダー生成タブ

---

### `SquadTextGenerator.vue` (`src/components/squad/SquadTextGenerator.vue`)

スカッドテキスト（IRC投稿用メンバー表）を生成するメインコンポーネント。

**props**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `teamId` | `number` | ✓ | チームID |

**emits**: なし

**主要機能・責務**:
- 開始方法選択: テンプレートから / 前回オーダーから
- テンプレート選択（DH有/無 × 対右/左の4パターン）
- スタメン打順リスト表示（バリデーション警告付き）
- スタメン以外の野手・投手のベンチ/オフ振り分け
- 公示日付入力による公示テキスト取得
- リアルタイムプレビュー（右カラム）
- クリップボードコピー + 自動保存（前回データとして保存）
- `useSquadTextStore`, `useLineupTemplate`, `useSquadTextGenerator`を使用

**使用箇所**: `SeasonPortal.vue`（view）のオーダー生成タブ

---

### `LineupTemplateEditor.vue` (`src/components/squad/LineupTemplateEditor.vue`)

打順テンプレートの編集コンポーネント。DH有/無×対右/左の4パターンを管理する。

**props**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `teamId` | `number` | ✓ | チームID |

**emits**: なし

**主要機能・責務**:
- 4パターンのタブ切り替え（DH有対右・DH有対左・DH無対右・DH無対左）
- 各パターンで9打順分のポジション・選手（1軍オートコンプリート）設定
- 行の上下移動で打順変更
- GET `/teams/:teamId/lineup_templates` でテンプレート一覧取得
- POST `/teams/:teamId/lineup_templates` または PUT で保存
- DELETE `/teams/:teamId/lineup_templates/:id` で削除（確認ダイアログ付き）

**使用箇所**: `SeasonPortal.vue`（view）のオーダータブ

---

## 選手（Players）コンポーネント

### `PlayerDialog.vue` (`src/components/players/PlayerDialog.vue`)

選手の新規作成・編集ダイアログ。フォーム部分は`PlayerIdentityForm`に委譲。

**props**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `modelValue` | `boolean` | ✓ | ダイアログ表示状態 |
| `item` | `PlayerDetail \| null` | ✓ | 編集対象選手（nullの場合は新規作成） |

**emits**:

| イベント名 | payload | 説明 |
|-----------|---------|------|
| `update:modelValue` | `boolean` | ダイアログ表示状態変更 |
| `save` | なし | 保存完了通知 |

**主要機能・責務**:
- PUT `/players/:id` または POST `/players` でAPIコール
- `useSnackbar`でフィードバック表示

**使用箇所**: `Players.vue`（view）, `PlayerDetailView.vue`（view）

---

### `PlayerIdentityForm.vue` (`src/components/players/PlayerIdentityForm.vue`)

選手基本情報フォーム（背番号・名前・略称）。`defineModel`で`PlayerDetail`を直接双方向バインド。

**props（defineModel）**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `modelValue` | `PlayerDetail` | ✓ | 編集対象選手データ（v-model） |

**主要機能・責務**:
- 背番号（最大4文字）・名前（必須）・略称のテキストフィールド
- バリデーション（名前は必須）

**使用箇所**: `PlayerDialog.vue`

---

## 試合入力関連コンポーネント

### `StartingMemberDialog.vue` (`src/components/StartingMemberDialog.vue`)

試合のスターティングラインナップ入力ダイアログ（ホーム・ビジター両チーム対応）。

**props**:

| 名前 | 型 | 必須 | デフォルト | 説明 |
|------|-----|------|-----------|------|
| `modelValue` | `boolean` | ✓ | — | ダイアログ表示状態 |
| `homeTeamId` | `number` | ✓ | — | ホームチームID |
| `allPlayers` | `Player[]` | - | `[]` | 全選手一覧（ビジター選手選択用） |
| `initialHomeLineup` | `LineupMember[]` | - | `[]` | ホームラインナップ初期値 |
| `initialOpponentLineup` | `LineupMember[]` | - | `[]` | ビジターラインナップ初期値 |
| `designatedHitterEnabled` | `boolean` | - | `false` | DH制フラグ |

**emits**:

| イベント名 | payload | 説明 |
|-----------|---------|------|
| `update:modelValue` | `boolean` | ダイアログ表示状態変更 |
| `save` | `{ homeLineup, opponentLineup }` | ラインナップ保存 |

**主要機能・責務**:
- DH制対応の打順数（9人/10人）
- ポジションキーボードショートカット（1→P、2→C、3→1B...）
- ホームチーム選手はAPIから取得、ビジターは`allPlayers`から選択

**使用箇所**: `GameResult.vue`（view）

---

### `SeasonInitializationDialog.vue` (`src/components/SeasonInitializationDialog.vue`)

シーズン初期化ダイアログ。シーズン名とスケジュールを選択してシーズンを開始する。

**props**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `isVisible` | `boolean` | ✓ | ダイアログ表示フラグ |
| `schedules` | `ScheduleList[]` | ✓ | 選択可能なスケジュール一覧 |
| `selectedTeam` | `Team \| null` | ✓ | 対象チーム |

**emits**:

| イベント名 | payload | 説明 |
|-----------|---------|------|
| `update:isVisible` | `boolean` | ダイアログ表示状態変更 |
| `save` | なし | シーズン作成完了通知 |

**主要機能・責務**:
- シーズン名・スケジュール選択フォーム
- POST `/seasons` でシーズン作成

**使用箇所**: `SeasonPortal.vue`（view）

---

## 設定（Settings）コンポーネント

### `GenericMasterSettings.vue` (`src/components/settings/GenericMasterSettings.vue`)

マスタデータ管理の汎用コンポーネント。折りたたみパネル内にデータテーブルを表示し、追加・編集・削除を提供する。

**props**:

| 名前 | 型 | 必須 | デフォルト | 説明 |
|------|-----|------|-----------|------|
| `title` | `string` | ✓ | — | パネルタイトル |
| `endpoint` | `string` | ✓ | — | CRUD対象のAPIエンドポイント（例: `/batting-skills`） |
| `i18nKey` | `string` | ✓ | — | i18nキープレフィックス |
| `dialogComponent` | `Component` | ✓ | — | 追加・編集に使うダイアログコンポーネント |
| `additionalHeaders` | `any[]` | - | — | テーブルの追加カラム定義 |
| `hasDescriptionColumn` | `boolean` | - | `true` | 説明カラムの表示 |
| `descriptionMaxWidth` | `string` | - | `'250px'` | 説明カラムの最大幅 |
| `readonly` | `boolean` | - | `false` | 読み取り専用モード（追加・編集・削除を非表示） |

**emits**: なし

**主要機能・責務**:
- `GET {endpoint}` で一覧取得
- 追加ボタン → `dialogComponent`を新規モードで表示
- 編集アイコン → `dialogComponent`を編集モードで表示
- 削除アイコン → `ConfirmDialog`で確認後`DELETE {endpoint}/:id`
- `readonly=true`の場合は操作ボタンを非表示

**使用箇所**: `Settings.vue`（view）内の各マスタセクションから`BattingSkillSettings`等のラッパーを経由して使用

---

### マスタ設定ラッパーコンポーネント

以下は全て`GenericMasterSettings`のラッパーで、特定のマスタデータに特化した設定UIを提供する。

| コンポーネント | エンドポイント | readonly | 追加機能 | 説明 |
|--------------|-------------|---------|---------|------|
| `BattingSkillSettings.vue` | `/batting-skills` | `true` | skill_typeによる色分けチップ | 打撃スキルマスタ（読み取り専用） |
| `PitchingSkillSettings.vue` | `/pitching-skills` | `true` | skill_typeによる色分けチップ | 投球スキルマスタ（読み取り専用） |
| `BattingStyleSettings.vue` | `/batting-styles` | `true` | なし | 打撃スタイルマスタ（読み取り専用） |
| `PitchingStyleSettings.vue` | `/pitching-styles` | `true` | なし | 投球スタイルマスタ（読み取り専用） |
| `PlayerTypeSettings.vue` | `/player-types` | `true` | なし | プレイヤータイプマスタ（読み取り専用） |
| `BiorhythmSettings.vue` | `/biorhythms` | `false` | start_date/end_date列追加 | バイオリズム期間設定（CRUD可能） |

**使用箇所**: 全て `Settings.vue`（view）から使用

---

### `CostSettings.vue` (`src/components/settings/CostSettings.vue`)

コスト表の管理コンポーネント。`GenericMasterSettings`は使わず独自実装。

**props**: なし
**emits**: なし

**主要機能・責務**:
- GET `/costs` でコスト表一覧取得
- `CostDialog`で追加・編集
- 複製機能（POST `/costs/:id/duplicate`）
- DELETE `/costs/:id` で削除

**使用箇所**: `Settings.vue`（view）

---

### `ScheduleSettings.vue` (`src/components/settings/ScheduleSettings.vue`)

スケジュールマスタの管理コンポーネント。`GenericMasterSettings`は使わず独自実装。

**props**: なし
**emits**: なし

**主要機能・責務**:
- GET `/schedules` でスケジュール一覧取得
- `ScheduleDialog`でスケジュール基本情報（名前・期間）の編集
- `ScheduleDetailEditor`でスケジュール詳細（日付タイプ設定）の編集
- DELETE `/schedules/:id` で削除

**使用箇所**: `Settings.vue`（view）

---

## 共通選択系コンポーネント（shared/）

### `TeamSelect.vue` (`src/components/shared/TeamSelect.vue`)

チーム選択ドロップダウン。`v-select`のシンプルなラッパー。

**props（defineModel + props）**:

| 名前 | 型 | 必須 | デフォルト | 説明 |
|------|-----|------|-----------|------|
| `modelValue` | any | — | — | 選択中チームID（v-model） |
| `teams` | `Team[]` | ✓ | — | 選択肢チーム一覧 |
| `displayNameType` | `string` | - | `'name'` | 表示名の属性（`name` または `short_name`） |

**使用箇所**: `GameResult.vue`（view）等

---

### `PlayerSelect.vue` (`src/components/shared/PlayerSelect.vue`)

選手選択オートコンプリート。背番号・名前・略称で検索可能。

**props**:

| 名前 | 型 | 必須 | デフォルト | 説明 |
|------|-----|------|-----------|------|
| `modelValue` | `number \| number[] \| null` | - | `null` | 選択中選手ID（v-model対応） |
| `players` | `Player[]` | ✓ | — | 選択肢の選手一覧 |
| `label` | `string` | ✓ | — | フィールドラベル |
| `multiple` | `boolean` | - | `false` | 複数選択モード |

**使用箇所**: `GameResult.vue`（view）等

---

### `PlayerDetailSelect.vue` (`src/components/shared/PlayerDetailSelect.vue`)

選手詳細（`PlayerDetail`型）の複数選択オートコンプリート。背番号・名前・略称で検索可能。複数選択専用。

**props**:

| 名前 | 型 | 必須 | デフォルト | 説明 |
|------|-----|------|-----------|------|
| `modelValue` | `number[]` | - | `[]` | 選択中選手IDリスト（v-model） |
| `players` | `PlayerDetail[]` | ✓ | — | 選択肢の選手一覧 |
| `label` | `string` | ✓ | — | フィールドラベル |

**使用箇所**: `CardSetsView.vue`等

---

### `TeamMemberSelect.vue` (`src/components/shared/TeamMemberSelect.vue`)

チームメンバー（在籍中の選手）の選択オートコンプリート。チームIDからAPIでメンバーを取得する。

**props**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `teamId` | `number` | ✓ | チームID |

**emits**:

| イベント名 | payload | 説明 |
|-----------|---------|------|
| `player-selected` | — | 選手選択時（実装内は未使用）|

**exposeメソッド**:

| 名前 | 説明 |
|------|------|
| `selectedPlayer` | 選択中の選手ID（`ref<number \| null>`） |

**主要機能・責務**:
- GET `/teams/:teamId/team_memberships` でメンバー一覧取得
- 選択した`team_membership_id`を`selectedPlayer`として公開

**使用箇所**: `PlayerAbsenceFormDialog.vue`

---

### `CostListSelect.vue` (`src/components/shared/CostListSelect.vue`)

コスト表選択ドロップダウン。現在日付に有効なコスト表を自動選択する。

**props（defineModel）**:

| 名前 | 型 | 必須 | 説明 |
|------|-----|------|------|
| `modelValue` | `CostList \| null` | — | 選択中のコスト表オブジェクト（v-model、return-object） |

**主要機能・責務**:
- GET `/costs` でコスト表一覧取得
- 初期値なしの場合、現在日付が有効期間内のコスト表を自動選択
- マッチしない場合は最初のコスト表を選択

**使用箇所**: `CostAssignment.vue`（view）
