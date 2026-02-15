# 14. テスト戦略

## 1. 現状調査

### 1.1 バックエンド (Rails 8.0.2)

#### テスト関連gem

| gem | 状態 | 備考 |
|-----|------|------|
| minitest | **あり** (Rails標準) | `test/` ディレクトリ、`test_helper.rb` が存在 |
| rspec-rails | なし | - |
| factory_bot_rails | なし | - |
| shoulda-matchers | なし | - |
| database_cleaner | なし | - |
| faker | なし | - |
| webmock / vcr | なし | - |

#### 既存テストファイル

`test/` ディレクトリにRails生成時のスケルトンが存在するが、全ファイルがコメントアウト状態で**実質テストゼロ**。

| ディレクトリ | ファイル数 | 実装状況 |
|-------------|-----------|---------|
| test/models/ | 13 | 全て `# test "the truth"` のみ（未実装） |
| test/controllers/ | 3 | 全て未実装 |
| test/fixtures/ | 存在 | 未使用 |
| test/integration/ | 存在 | 空 |
| test/mailers/ | 存在 | 空 |

#### CI/CD

- `.github/workflows/` なし
- CI設定なし

#### コード規模

| 対象 | 数 |
|------|-----|
| モデル | 32ファイル（`app/models/`） |
| APIコントローラー | 25ファイル（`api/v1/`）+ 9ファイル（`commissioner/`） |
| シリアライザー | 17ファイル |
| ルーティング | 85行 |
| DBテーブル | 25テーブル（`db/schema.rb` 416行） |
| Rakeタスク | 1（`master_data.rake`） |
| 設定ファイル | `config/cost_limits.yml`（コスト上限） |

### 1.2 フロントエンド (Vue 3.5 + Vite 7 + Vuetify 3.9)

#### テスト関連パッケージ

| パッケージ | 状態 |
|-----------|------|
| vitest | なし |
| @vue/test-utils | なし |
| jest | なし |
| @testing-library/vue | なし |
| cypress / playwright | なし |

#### テスト設定・テストファイル

- `vitest.config.ts` / `jest.config.ts` : なし
- `*.spec.ts` / `*.test.ts` : なし（`node_modules/` 内のみ）
- テスト基盤は完全に未整備

#### コード規模

| 対象 | 数 |
|------|-----|
| ページ (views/) | 13 + 1ディレクトリ(commissioner/) |
| コンポーネント (components/) | 11 + 3サブディレクトリ(players/, settings/, shared/) |
| Composables | 2 (useAuth.ts, useSnackbar.ts) |
| 型定義 (types/) | 25ファイル |
| ルーター | 認証ガード付き |
| 国際化 (locales/) | ja.json |

### 1.3 Linter / フォーマッター

| ツール | 対象 | 設定 |
|--------|------|------|
| RuboCop | BE (*.rb) | Gemfileに `rubocop-rails-omakase` あり |
| ESLint | FE (*.js, *.ts, *.vue) | eslint.config あり |
| Prettier | FE (*.js, *.ts, *.vue) | prettier 3.5 |
| Lefthook | 全体 | pre-commit で rubocop + eslint + prettier を自動実行 |

---

## 2. テスト対象の優先順位

cmd_149〜179の実装内容およびソースコード調査に基づき、リスク×影響度で優先順位を付ける。

### 2.1 優先順位表

| # | テスト対象 | テスト種別 | リスク | 影響度 | 優先度 | 根拠 |
|---|-----------|-----------|--------|--------|--------|------|
| 1 | コスト上限バリデーション（Team モデル） | モデルテスト | **高** | **高** | **最優先** | チーム全体200上限 + 1軍人数別段階制(25人=114, 26=117, 27=119, 28+=120)。計算ロジックが複雑で `config/cost_limits.yml` に依存。excluded_from_team_total の影響範囲がチーム全体と1軍で異なる |
| 2 | 外の世界枠バリデーション（Team モデル） | モデルテスト | **高** | **高** | **最優先** | 4人上限 + 投手/野手混在制約(4人時のみ) + 二刀流カウント。`validate_outside_world_limit` / `validate_outside_world_balance` の条件分岐が多い |
| 3 | ロスター操作（TeamRostersController） | リクエストテスト | **高** | **高** | **最優先** | 昇降格のcooldown計算(10日ルール)、same_day_exempt、再調整中の昇格ブロック、Phase1-3のトランザクション制御。最もビジネスロジックが集中するコントローラー |
| 4 | 認証・認可チェーン | リクエストテスト | **高** | **中** | **高** | ApplicationController → BaseController → Commissioner::BaseController の継承チェーン。session認証 + commissionerロール制御。不正アクセスの直接的なリスク |
| 5 | 離脱管理（PlayerAbsence モデル） | モデルテスト | **高** | **中** | **高** | `effective_end_date` の計算: days(単純日数加算) vs games(シーズンスケジュール参照)。gamesベースの計算はseason_schedulesとの結合が必要 |
| 6 | Playerモデル バリデーション | モデルテスト | **中** | **高** | **高** | 守備力フォーマット(DEFENSE_RATING_FORMAT)、送球値バリデーション、外野守備の排他性(defense_of vs defense_lf/cf/rf)、スタミナ範囲。バリデーションルール数が最多 |
| 7 | TeamMembershipモデル | モデルテスト | **中** | **中** | **中** | squad/selected_cost_type のinclusion、excluded_from_team_totalスコープ。コスト計算の基盤 |
| 8 | マスタデータ Rakeタスク | Rakeテスト | **中** | **中** | **中** | `master_data:sync` のupsert動作（新規作成/更新/スキップ）。データ整合性に直結 |
| 9 | Userモデル + AuthController | モデル+リクエスト | **中** | **中** | **中** | has_secure_password、role enum。ログイン/ログアウト/show_current_user のセッション管理 |
| 10 | TopMenu.vue | コンポーネントテスト | **低** | **中** | **中** | 2回の回帰バグ(cmd_150, cmd_165)が発生。APIレスポンス形式への依存が原因 |
| 11 | ActiveRoster.vue | コンポーネントテスト | **低** | **中** | **低** | ロスター表示ロジック。BE側のテストが充実していれば優先度は下がる |
| 12 | シリアライザー | ユニットテスト | **低** | **低** | **低** | 出力フォーマットの保証。リクエストテストで間接的にカバー可能 |

### 2.2 テスト対象のトップ5まとめ

1. **Team#validate_team_total_cost / first_squad_cost_limit_for_count** — コスト計算ロジック
2. **Team#validate_outside_world_limit / validate_outside_world_balance** — 外の世界枠ルール
3. **TeamRostersController#create** — ロスター操作（cooldown, 再調整チェック, コスト検証のトランザクション）
4. **認証・認可チェーン** — ApplicationController → BaseController → Commissioner::BaseController
5. **PlayerAbsence#effective_end_date** — 離脱終了日計算（days/games）

---

## 3. テスト戦略

### 3.1 フレームワーク選定

#### バックエンド: RSpec

| 項目 | 選定理由 |
|------|---------|
| **フレームワーク** | RSpec (`rspec-rails`) |
| **選定理由** | Railsコミュニティのデファクトスタンダード。describe/context/itによる階層的な記述がバリデーションの網羅的テストに適する。既存のminitest骨格はコメントアウト状態のため移行コストなし |
| **ファクトリ** | FactoryBot (`factory_bot_rails`) — fixtureより柔軟。複雑なリレーション(Player ↔ TeamMembership ↔ SeasonRoster等)の組み立てに必須 |
| **マッチャ拡張** | shoulda-matchers — `validate_presence_of`, `validate_inclusion_of` 等のワンライナーでバリデーションテストを簡潔に書ける |
| **テストデータ** | Faker — 選手名・チーム名等のダミーデータ生成 |
| **DB管理** | database_cleaner-active_record — トランザクション戦略でテスト間のデータ分離 |

追加で導入を検討するgem:

| gem | 用途 | 優先度 |
|-----|------|--------|
| simplecov | カバレッジ計測 | 中（初期は不要、テストが増えてから導入） |
| webmock | 外部API モック（現時点では不要） | 低 |

#### フロントエンド: Vitest

| 項目 | 選定理由 |
|------|---------|
| **フレームワーク** | Vitest |
| **選定理由** | Vite 7ベースのプロジェクトとネイティブ統合。設定がvite.config.tsを再利用でき、HMR対応でテスト実行が高速。Vue 3公式ドキュメントでも推奨 |
| **コンポーネントテスト** | @vue/test-utils — Vue 3公式のテストユーティリティ。mount/shallowMount、props/emits検証 |
| **DOM操作** | happy-dom（jsdomより高速、Vitest推奨） |

追加で検討するパッケージ:

| パッケージ | 用途 | 優先度 |
|-----------|------|--------|
| @testing-library/vue | よりユーザー視点のテスト記述 | 低（test-utilsで十分） |
| msw (Mock Service Worker) | APIモック | 中（コンポーネントテスト拡充時） |

#### E2E: Playwright（将来フェーズ）

| 項目 | 選定理由 |
|------|---------|
| **フレームワーク** | Playwright |
| **選定理由** | クロスブラウザ対応、自動待機、TypeScriptネイティブサポート。Cypressと比較してCI環境での安定性が高い |
| **導入時期** | Phase 3以降。BE/FEのユニット/リクエストテストが一定量揃ってから |

### 3.2 テスト種別ごとの方針

#### 3.2.1 モデルテスト (BE)

**テストする内容:**
- バリデーション（presence, inclusion, format, numericality, カスタムバリデーション）
- スコープ（`included_in_team_total`, `excluded_from_team_total` 等）
- インスタンスメソッド（`effective_end_date`, `validate_team_total_cost` 等）
- enum定義（`absence_type`, `role`, `position` 等）
- アソシエーション（belongs_to, has_many, through）

**テストしない内容:**
- ActiveRecordの標準機能（find, create等）そのもの
- DBカラムの型チェック（schema.rbで保証）

#### 3.2.2 リクエストテスト (BE)

**テストする内容:**
- 各アクションの正常系レスポンス（ステータスコード、JSONフォーマット）
- 認証チェック（未ログイン → 401）
- 認可チェック（commissioner以外 → 403）
- バリデーションエラー時のレスポンス（422）
- トランザクション内の複合バリデーション（TeamRostersController#create のPhase1-3）
- エラーハンドリング（RecordNotFound → 404）

**テストしない内容:**
- シリアライザーの詳細な出力フォーマット（リクエストテストで間接的にカバー）
- ルーティングの単体テスト（リクエストテストに包含）

#### 3.2.3 Rakeタスクテスト (BE)

**テストする内容:**
- `master_data:sync` の新規作成・更新・スキップ動作
- YAML読み込みエラー時の挙動
- `master_data:export` の出力フォーマット

#### 3.2.4 コンポーネントテスト (FE)

**テストする内容:**
- Composables（useAuth, useSnackbar）の状態管理ロジック
- バリデーションを含むフォームコンポーネント
- APIレスポンスに依存する表示ロジック（TopMenu.vue等の回帰バグ防止）
- 型定義との整合性（props/emitsの型チェック）

**テストしない内容:**
- Vuetifyコンポーネントの内部動作
- 純粋な見た目（CSS/スタイル）
- ルーティング遷移の詳細（E2Eで対応）

### 3.3 ディレクトリ構成案

#### バックエンド

```
thbigmatome/
├── spec/
│   ├── spec_helper.rb
│   ├── rails_helper.rb
│   ├── support/
│   │   ├── factory_bot.rb          # FactoryBot設定
│   │   └── shared_contexts/
│   │       └── authenticated.rb    # 認証済みユーザーの共通コンテキスト
│   ├── factories/
│   │   ├── users.rb
│   │   ├── teams.rb
│   │   ├── players.rb
│   │   ├── team_memberships.rb
│   │   ├── seasons.rb
│   │   ├── season_rosters.rb
│   │   ├── player_absences.rb
│   │   ├── costs.rb
│   │   ├── cost_players.rb
│   │   └── player_types.rb
│   ├── models/
│   │   ├── team_spec.rb            # コスト上限、外の世界枠
│   │   ├── player_spec.rb          # 守備力バリデーション、排他性
│   │   ├── player_absence_spec.rb  # effective_end_date
│   │   ├── team_membership_spec.rb # squad, cost_type
│   │   ├── user_spec.rb            # 認証、ロール
│   │   ├── season_roster_spec.rb
│   │   └── ...
│   ├── requests/
│   │   ├── api/v1/
│   │   │   ├── auth_spec.rb
│   │   │   ├── team_rosters_spec.rb
│   │   │   ├── teams_spec.rb
│   │   │   ├── players_spec.rb
│   │   │   └── ...
│   │   └── api/v1/commissioner/
│   │       ├── player_absences_spec.rb
│   │       └── ...
│   └── tasks/
│       └── master_data_spec.rb
├── test/                             # 既存(minitest)は削除可
```

#### フロントエンド

```
thbigmatome-front/
├── vitest.config.ts                  # Vitest設定（vite.config.tsを拡張）
├── src/
│   ├── composables/
│   │   ├── __tests__/
│   │   │   ├── useAuth.spec.ts
│   │   │   └── useSnackbar.spec.ts
│   ├── views/
│   │   ├── __tests__/
│   │   │   ├── TopMenu.spec.ts
│   │   │   ├── ActiveRoster.spec.ts
│   │   │   └── ...
│   ├── components/
│   │   ├── __tests__/
│   │   │   ├── PromotionCooldownInfo.spec.ts
│   │   │   └── ...
```

> テストファイルは対象ファイルと同じディレクトリ内の `__tests__/` に配置（colocateパターン）。テストと実装の対応が明確で、ファイル移動時にも追従しやすい。

### 3.4 テスト実行環境

#### ローカル実行

```bash
# バックエンド
cd thbigmatome/
bundle exec rspec                           # 全テスト
bundle exec rspec spec/models/              # モデルテストのみ
bundle exec rspec spec/models/team_spec.rb  # 個別ファイル

# フロントエンド
cd thbigmatome-front/
npx vitest                                  # watchモード
npx vitest run                              # 一括実行
npx vitest run src/composables/             # ディレクトリ指定
```

#### Lefthook連携（将来）

pre-commitフックにテスト実行を追加する場合:

```yaml
# lefthook.yml に追加
pre-commit:
  commands:
    rspec:
      root: "thbigmatome/"
      glob: "thbigmatome/spec/**/*_spec.rb"
      run: bundle exec rspec --fail-fast {staged_files}
    vitest:
      root: "thbigmatome-front/"
      glob: "thbigmatome-front/src/**/*.spec.ts"
      run: npx vitest run --reporter=dot {staged_files}
```

> ただし、pre-commitでの全テスト実行は遅延の原因になるため、CIでの実行を優先推奨。

#### CI/CD（将来フェーズ）

GitHub Actionsで以下を構築:

```
.github/workflows/test.yml
├── BE: PostgreSQL service + bundle exec rspec
├── FE: npx vitest run
└── (将来) E2E: Playwright
```

---

## 4. 実装ロードマップ

### Phase 1: テスト基盤構築 + 最優先テスト

**目標**: RSpec/FactoryBot/Vitest のセットアップ + 最優先テスト対象のテスト作成

| ステップ | 内容 | 見積り |
|---------|------|--------|
| 1-1 | Gemfileにテスト関連gem追加、`rails generate rspec:install` | 小 |
| 1-2 | FactoryBotで基本ファクトリ作成（User, Team, Player, TeamMembership, Cost, CostPlayer） | 中 |
| 1-3 | 認証用shared_context作成 | 小 |
| 1-4 | Team モデルテスト（コスト上限 + 外の世界枠） | 中 |
| 1-5 | TeamRostersController リクエストテスト（昇降格 + cooldown + 再調整チェック） | 大 |
| 1-6 | 認証・認可チェーンのリクエストテスト | 中 |

### Phase 2: 高優先テスト拡充

| ステップ | 内容 | 見積り |
|---------|------|--------|
| 2-1 | PlayerAbsence モデルテスト（effective_end_date） | 中 |
| 2-2 | Player モデルテスト（バリデーション網羅） | 中 |
| 2-3 | Commissioner系コントローラー認可テスト | 中 |
| 2-4 | FE: Vitest + @vue/test-utils セットアップ | 小 |
| 2-5 | FE: useAuth / useSnackbar composableテスト | 小 |
| 2-6 | FE: TopMenu.vue テスト（回帰バグ防止） | 中 |

### Phase 3: 中優先テスト + E2E基盤

| ステップ | 内容 | 見積り |
|---------|------|--------|
| 3-1 | TeamMembership, SeasonRoster, User モデルテスト | 中 |
| 3-2 | master_data.rake テスト | 小 |
| 3-3 | 残りのコントローラーリクエストテスト | 大 |
| 3-4 | FE: ActiveRoster.vue, CostAssignment.vue テスト | 中 |
| 3-5 | Playwright導入 + ログイン→ロスター操作のE2Eテスト | 大 |
| 3-6 | CI/CD（GitHub Actions）構築 | 中 |

---

## 5. Gemfile / package.json 変更案

### バックエンド (Gemfile)

```ruby
group :development, :test do
  gem 'rspec-rails', '~> 7.0'
  gem 'factory_bot_rails'
  gem 'faker'
end

group :test do
  gem 'shoulda-matchers', '~> 6.0'
  gem 'database_cleaner-active_record'
end
```

### フロントエンド (package.json devDependencies)

```json
{
  "vitest": "^3.0.0",
  "@vue/test-utils": "^2.4.0",
  "happy-dom": "^17.0.0"
}
```
