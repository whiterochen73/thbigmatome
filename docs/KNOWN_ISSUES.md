# 既知の問題一覧

最終更新: 2026-02-15

## バグ（コード不具合）

| ID | ファイル | 深刻度 | 内容 | 発見元 |
|----|---------|--------|------|--------|
| BUG-001 | src/views/Players.vue:100 | high | ✅ 修正済み (cmd_132) 削除エンドポイントが `/managers/:id` になっている (正: `/players/:id`) → 選手削除が404エラーで動作しない | 04_player_management.md |
| BUG-004 | src/types/playerDetail.ts:19-33 | high | ✅ 修正済み (cmd_132) 守備力フィールド10個が `number \| null` だが `string \| null` であるべき (schema.rb では string 型) → "5A" 等の文字列入力が正しく保存されない可能性。throwing_c は integer 型のため対象外 | 04_player_management.md |
| BUG-005 | src/types/playerDetail.ts:46 | high | ✅ 修正済み (cmd_132) `special_throwing_c` が `string \| null` だが `number \| null` であるべき (schema.rb では integer 型) → 整数入力が正しく保存されない可能性 | 04_player_management.md |
| BUG-006 | src/composables/useAuth.ts:25 | high | ✅ 修正済み (cmd_132) TypeScript 型定義で `role: number` となっていたが、Rails enum は `.slice` 経由のシリアライズ時に文字列 (`"commissioner"`) を返すため `role: string` が正しい。比較ロジック (`=== 'commissioner'`) 自体は正しく、型定義のみ修正 | 01_authentication.md |
| BUG-007 | src/views/TeamList.vue:27 | high | ✅ 修正済み (cmd_132) `item.manager?.name` を参照しているが、TeamSerializer は `has_one :director` で返却しており `manager` プロパティは存在しない → 監督名が常に `-` と表示される | 03_team_management.md |
| BUG-008 | app/controllers/api/v1/auth_controller.rb:15 | medium | ✅ 修正済み (cmd_141) エラーメッセージが「メールアドレスまたはパスワードが間違っています」となっているが、本システムではログインIDを使用している | 01_authentication.md |
| BUG-002 | app/models/player.rb:122 | medium | ✅ 修正済み (cmd_141) `injury_rate` のメッセージが「1〜6」だがコードは `1..7` → ユーザー混乱 | 04_player_management.md |
| BUG-009 | db/schema.rb (season_schedules) | medium | ✅ 修正済み (cmd_142) カラム名が `oppnent_score`, `oppnent_team_id` (正しくは `opponent_*`) → コントローラーで変換して吸収しているが不整合 | 10_game_management.md |
| BUG-012 | src/types/playerDetail.ts:45 | high | ✅ 修正済み (cmd_141) `special_defense_c` が `number \| null` だが schema.rb では string 型 → BUG-004 と同種の型不一致 | 04_player_management.md (cmd_132 精査) |
| BUG-003 | app/serializers/player_detail_serializer.rb:12-13,27-28 | low | ✅ 修正済み (cmd_149) `catcher_ids` メソッドが重複定義 → コードが冗長 | 04_player_management.md |
| BUG-010 | app/serializers/roster_player_serializer.rb:4,12 | low | ✅ 修正済み (cmd_149) `number` メソッドが重複定義 | 09_roster_management.md |
| BUG-011 | app/serializers/roster_player_serializer.rb:8,24 | low | ✅ 修正済み (cmd_149) `player_name` メソッドが重複定義 (`short_name` vs `name`) → 現在は後者 (`name`) が有効 | 09_roster_management.md |

## 設計上の問題

| ID | ファイル | 深刻度 | 内容 | 発見元 |
|----|---------|--------|------|--------|
| DESIGN-001 | teams.manager_id | high | ✅ 修正済み (cmd_139) `teams.manager_id` カラム (NOT NULL、外部キー制約あり) が存在するが、現在のコントローラーでは `director_id` / `coach_ids` パラメータで `team_managers` テーブル経由で管理 → チーム作成時に設定されるが監督変更では更新されず実データと乖離 | 03_team_management.md |
| DESIGN-002 | teams.manager_id | high | ✅ 修正済み (cmd_139) 監督削除時、`TeamManager` レコードは自動削除されるが `teams.manager_id` は自動更新されない → 削除対象の監督が主監督として設定されているチームがある場合エラー発生 | 02_manager_management.md |
| DESIGN-003 | managers.role | high | `managers.role` カラム (director=0, coach=1) が存在するが ManagersController / ManagerSerializer / フロントエンドで使用されていない → `team_managers.role` との整合性が保証されない | 02_manager_management.md |
| DESIGN-004 | db/schema.rb (外野守備) | medium | ✅ 修正済み (cmd_144) `defense_of` (統合) と `defense_lf/cf/rf` (個別) が同時に設定可能だが、どちらが優先されるかのビジネスルールが未定義 | 04_player_management.md |
| DESIGN-005 | player.rb (投球スタイル) | medium | `pitching_style_id`, `pinch_pitching_style_id`, `catcher_pitching_style_id` の3種類があるが、優先順位や適用条件のドキュメントが不足 → 仕様通り（投手特徴: 通常/走者あり時/専属捕手時の3種） | 04_player_management.md |
| DESIGN-006 | app/models/team_manager.rb | medium | リーグ内兼任制約チェックで `team.leagues.first` を使用 → チームが複数リーグに所属している場合、最初のリーグのみで兼任チェックが行われる → 保留（仕様未確定、現状実害なし） | 02_manager_management.md |
| DESIGN-007 | routes.rb (managers/:manager_id/teams) | medium | ✅ 修正済み (cmd_143) ネストされたルート `/api/v1/managers/:manager_id/teams` が定義されているが TeamsController で実装されていない → ルーティングの複雑性が増している | 02_manager_management.md |
| DESIGN-008 | game_controller.rb / season_schedule_serializer.rb | medium | ✅ 修正済み (cmd_148) `game_number` の重複実装: コントローラー内で動的計算 (`season_schedule.game_number || 計算ロジック`) → DB保存値と計算値の整合性管理が曖昧 | 10_game_management.md |
| DESIGN-009 | game_controller.rb / season_schedule_serializer.rb | medium | ✅ 修正済み (cmd_148) `game_result` の重複実装: `GameController#show` と `SeasonScheduleSerializer#game_result` で同じロジック → 略称 (`short_name`) の使用がシリアライザーのみ | 10_game_management.md |
| DESIGN-010 | db/schema.rb (batting_styles, pitching_styles) | medium | ✅ 修正済み (cmd_143) DB上の NOT NULL 制約・UNIQUE INDEX がなく、モデルバリデーションに完全に依存 → データ整合性の観点ではDB制約の追加が望ましい | 05_master_data.md |
| DESIGN-011 | app/models/pitching_skill.rb | medium | ✅ 修正済み (cmd_143) `has_many :player_pitching_skills` / `has_many :players, through:` の定義がない → 削除時は `dependent: :restrict_with_error` ではなくDB外部キー制約のみで制限され、エラーメッセージ形式が異なる | 05_master_data.md |
| DESIGN-012 | app/models/batting_style.rb | medium | ✅ 修正済み (cmd_143) `has_many :players` の定義がない → `BattingStyle.find(1).players` のような逆引きクエリが使用できない (PitchingStyle も同様) | 05_master_data.md |
| DESIGN-013 | app/models/biorhythm.rb | low | ✅ 修正済み (cmd_149) `start_date` と `end_date` の存在チェックのみで、`start_date <= end_date` の論理チェック、期間重複チェック、年度範囲チェック等が未実装 | 05_master_data.md |
| DESIGN-014 | src/types/ (battingSkill.ts, pitchingSkill.ts) | low | ✅ 修正済み (cmd_149) `SkillType` 型 (`'positive' \| 'negative' \| 'neutral'`) が2箇所で個別定義 → 共通の型定義ファイルに統合されていない | 05_master_data.md |
| DESIGN-015 | src/types/costList.ts | low | ✅ 修正済み (cmd_149) `effective_date` フィールドが定義されているがバックエンドの `costs` テーブルにこのカラムは存在せず、`CostSerializer` も出力しない → 常に `undefined` となる未使用フィールド | 06_cost_management.md |

## 未実装機能

| ID | ファイル | 深刻度 | 内容 | 発見元 |
|----|---------|--------|------|--------|
| UNIMPL-001 | 全コントローラー (マスタデータ) | high | ✅ 修正済み (cmd_137) 6種類のマスタデータコントローラはいずれも認証ガード (`before_action :authenticate_user!` 等) を実装していない → 全マスタデータのCRUD操作は認証なしでアクセス可能 | 05_master_data.md |
| UNIMPL-002 | users_controller.rb | medium | ユーザー登録機能: ルーティングに `post 'users', to: 'users#create'` が定義されているがコントローラー実装未確認 → 現時点ではデータベース直接操作またはシードデータでユーザー作成が必要 | 01_authentication.md |
| UNIMPL-003 | auth (パスワードリセット) | medium | パスワード忘れ時の復旧手段が存在しない → パスワード忘失時はデータベース管理者による手動リセットが必要 | 01_authentication.md |
| UNIMPL-004 | teams_controller.rb | medium | チーム削除時の `ActiveRecord::DeleteRestrictionError` ハンドリング未実装 → 削除失敗時に 500 Internal Server Error が返却される | 03_team_management.md |
| UNIMPL-005 | src/views/TeamList.vue | medium | ✅ 実装済み (cmd_154) チーム一覧→チームメンバー編集画面 (`/teams/:teamId/members`) へ直接遷移するリンク/ボタンが存在しない | 03_team_management.md |
| UNIMPL-006 | players (一括インポート) | medium | CSV/Excel からの一括登録機能未実装 | 04_player_management.md |
| UNIMPL-007 | players (画像アップロード) | medium | プロフィール画像の管理未実装 | 04_player_management.md |
| UNIMPL-008 | players (詳細統計) | medium | 過去の成績データとの連携未実装 | 04_player_management.md |
| UNIMPL-009 | players (検索・フィルター) | medium | ✅ 実装済み (cmd_155) 一覧画面での条件絞り込み（選手名検索・ポジションフィルター）を実装 | 04_player_management.md |
| UNIMPL-010 | costs_controller.rb | medium | ルーティングに `:show` が含まれるがコントローラーに `show` アクションがない → 呼び出すとエラー | 06_cost_management.md |
| UNIMPL-011 | src/views/ScoreSheet.vue | medium | 打撃記録の自動集計未実装: 打撃記録入力欄は存在するが「安打」「打点」列の自動計算機能なし → `battingResults` はローカル状態のみで保存機能なし | 10_game_management.md |
| UNIMPL-012 | src/components/AbsenceInfo.vue | medium | ✅ 実装済み (cmd_164) games 単位の離脱期間フィルタリング未実装: `duration_unit === 'games'` の場合フィルタリングされない → シーズンスケジュールと照合して試合数をカウントする必要あり | 11_player_absence.md |
| UNIMPL-013 | src/components/PlayerAbsenceFormDialog.vue | low | ✅ 実装済み (cmd_164) 保存失敗時のユーザーへの通知が未実装 (TODOコメントあり) → スナックバー等での統一的なエラー表示が望ましい | 11_player_absence.md |
| UNIMPL-014 | roster / player_absence連携 | low | ✅ 実装済み (cmd_164) 離脱中の選手がロースターに登録できないようにする制約未実装、離脱期間終了時の自動復帰通知未実装 | 11_player_absence.md |
| UNIMPL-015 | managers_controller.rb | low | 監督一覧のページネーション未実装 → 監督数が数百件以上になった場合、レスポンス時間が長くなりブラウザでのレンダリング負荷が増加 | 02_manager_management.md | ✅ 実装済み (cmd_163) |
| UNIMPL-016 | LeaguesView.vue (コミッショナー) | low | ✅ 実装済み (cmd_163) チーム管理ダイアログを開くボタンが未配置、シーズン管理・対戦管理・選手プール管理・チームスタッフ管理・選手離脱管理の画面が未確認 (APIのみ実装済みと推定) | 12_commissioner.md |

## バリデーション不足・制約

| ID | ファイル | 深刻度 | 内容 | 発見元 |
|----|---------|--------|------|--------|
| VALID-001 | app/models/team_membership.rb | high | ✅ 修正済み (cmd_138) `selected_cost_type` に `presence: true` のみで `inclusion` バリデーションがない → 無効な値 (例: `"invalid_type"`) が保存された場合、`send` メソッドで `NoMethodError` が発生するリスク | 03_team_management.md / 06_cost_management.md |
| VALID-002 | app/models/season_schedule.rb | medium | ✅ 修正済み (cmd_141) バリデーション記述なし → `home_away` の値制約 ('home' / 'visitor' のみ許可) はモデルレベルで未強制 | 10_game_management.md |
| VALID-003 | app/models/team_manager.rb | low | ✅ 修正済み (cmd_149) バリデーションメッセージが日本語ハードコーディング → 多言語対応が困難 | 02_manager_management.md |
| VALID-004 | app/models/biorhythm.rb / src/components/settings/BiorhythmDialog.vue | low | ✅ 修正済み (cmd_149) 日付形式の正規表現チェックのみで、論理的な期間バリデーション (`start_date <= end_date`) は未実装 | 05_master_data.md |

## 注意事項・リスク

| ID | ファイル | 深刻度 | 内容 | 発見元 |
|----|---------|--------|------|--------|
| WARN-001 | app/serializers/roster_player_serializer.rb | high | ✅ 修正済み (cmd_138) `Cost.current_cost` が `nil` を返す場合 (`end_date` が `null` のコスト表が存在しない場合) `NoMethodError` が発生、また選手に `cost_player` レコードが存在しない場合も同様のエラー発生 | 06_cost_management.md |
| WARN-002 | cost.rb (current_cost) | medium | ✅ 修正済み (cmd_143) `end_date` が `null` のレコードが複数存在した場合、`first` により取得されるレコードは不定 → 運用上、`end_date` が `null` のコスト表は1件のみに制限すべき | 06_cost_management.md |
| WARN-003 | cost_assignments_controller.rb | medium | ✅ 修正済み (cmd_143) `create` アクションの一括保存にトランザクション制御がない (`duplicate` アクションにはある) → 途中で `save!` が失敗した場合、それ以前の保存は確定済みとなり部分的な保存状態になる可能性 | 06_cost_management.md |
| WARN-004 | src/components/shared/CostListSelect.vue | medium | ✅ 修正済み (cmd_141) コスト表が0件の場合、`costLists.value[0]` は `undefined` となり、`costList.value` に `undefined` が設定される | 06_cost_management.md |
| WARN-005 | app/models/player.rb (N+1クエリ) | medium | `player.teams` など、一部のリレーションで eager_load 未実施 → N+1クエリの残存 | 04_player_management.md |
| WARN-006 | players (ページネーション) | medium | 選手数が1000人を超えると一覧画面の初期ロードが遅延する可能性 | 04_player_management.md |
| WARN-007 | costs / cost_players (バリデーション差異) | low | ✅ 修正済み (cmd_141) バックエンドではコスト値の最小値は `1` (`greater_than_or_equal_to: 1`) だが、フロントエンドのバリデーションでは `0以上` を許容 → フロントエンドで `0` を入力した場合、バックエンドでバリデーションエラー | 06_cost_management.md |
| WARN-008 | schedule_details_controller.rb (upsert_all) | low | `upsert_all` 使用時には ActiveRecord のバリデーションおよびコールバックがスキップされる → データ整合性はDBレベルの制約とフロントエンドの入力制御に依存 → 許容（DB制約でカバー） | 07_schedule_management.md |
| WARN-009 | app/serializers/ (マスタデータ) | low | マスタデータのAPIレスポンスは `to_json` による直接シリアライズを使用 → `created_at`, `updated_at` がレスポンスに常に含まれる (フロントエンド側では使用していない)、レスポンス形式のカスタマイズができない → 許容（実害なし） | 05_master_data.md |

---

## カテゴリ別集計

- **バグ (コード不具合)**: 12件 (高: 6件 [うち5件修正済み]、中: 4件、低: 2件)
- **設計上の問題**: 15件 (高: 3件 [うち2件修正済み]、中: 9件、低: 3件)
- **未実装機能**: 16件 (高: 1件、中: 11件、低: 4件)
- **バリデーション不足・制約**: 4件 (高: 1件、中: 1件、低: 2件)
- **注意事項・リスク**: 9件 (高: 1件、中: 5件、低: 3件)

**合計**: 56件

---

**集約日**: 2026-02-14 (初版), 2026-02-15 (cmd_132修正反映)
**集約元**: 足軽4-6号報告YAML + 仕様書01-13 (全13ファイル)
**作成者**: 足軽2号 (初版) / 足軽5号 (cmd_132修正反映)
