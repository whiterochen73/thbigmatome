# 登板の保存値（結果区分・疲労P・連続中4日回数）の作り直しの入口（cmd_1784 段3。設計書 §4.5）。
#
# 保存値は前の登板・離脱・得点・カードに依存するのに、作り直しの引き金が得点とノーゲームの変更だけだった（S8）。
# 作り直しは必ずここを通す。呼ぶ側は「どのチームの、いつから、どの投手を」だけを渡す。
#
#   - 登板の保存・削除        : 保存した日の翌日から（その日の値は保存時に求めている）。登板を入れた・消した投手
#   - 離脱の作成・変更・削除  : 開始日（変更前の開始日の早い方）から。その選手
#   - 得点・ノーゲームの変更  : その試合日から。その日の先発（SeasonSchedule）。得点未入力の先発はその日の分だけ作り直し、それ以降は動かさない
#   - カードの変更            : 変更の日から。その選手（TeamMembershipWriter）。疲労P がカードで決まるため
#   - 過去分の一括            : date を渡さない（rake pitcher_game_states:recalculate_result_category）
#
# 契約（selected_cost_type）の変更では作り直さない: 保存値は契約に依らない（PitcherStarterFatigue はカードの疲労P だけを読む）。
#
# 中身（走査と判定）は PitcherResultCategoryRebuilder。1 チームの登板は多くて 400 件前後で、投手を絞れば数十件。
class PitcherHistoryRebuild
  # error: 作り直しが落ちた時の例外（成功なら nil）。rebuilder: 走査した行（rows / summary）を持つ
  Outcome = Struct.new(:rebuilder, :error, keyword_init: true) do
    def ok? = error.nil?
  end

  # 作り直す。date が nil なら全期間、pitcher_ids が nil なら投手を絞らない（空配列なら誰も作り直さない）。
  # 失敗は例外のまま上げる（rake・試運転向け）。書き込みの途中で呼ぶ側は guarded を使う
  # unscored_not_loss_on: 得点未入力の先発のうちこの日の分だけ「負けではない」として作り直す（それ以外の未入力は unscored に従う）
  def self.from(team_id: nil, date: nil, pitcher_ids: nil, apply: true, unscored: :skip, unscored_not_loss_on: nil, recompute_no_game_on: nil)
    rebuilder = PitcherResultCategoryRebuilder.new(apply: apply, unscored: unscored, unscored_not_loss_on: unscored_not_loss_on)
    rebuilder.rebuild_from(team_id: team_id, date: date, pitcher_ids: pitcher_ids, recompute_no_game_on: recompute_no_game_on)
    rebuilder
  end

  # 親の保存を取り消さずに作り直す。PostgreSQL は SQL エラーでトランザクション全体が中断状態になり、後続の文もすべて失敗するため、
  # セーブポイント（requires_new）の中で走らせる。失敗したら作り直しの途中の書き込みだけが戻り、例外は Outcome#error に持つ
  # （作り直しは後で rake から再実行できる）。
  def self.guarded(**args)
    rebuilder = nil
    ApplicationRecord.transaction(requires_new: true) { rebuilder = from(**args) }
    Outcome.new(rebuilder: rebuilder, error: nil)
  rescue StandardError => e
    Rails.logger.error(
      "[PitcherHistoryRebuild] 保存値の作り直しに失敗（保存は済み） #{args.except(:pitcher_ids).inspect} pitchers=#{Array(args[:pitcher_ids]).first(20)} " \
      "#{e.class}: #{e.message}\n#{Array(e.backtrace).first(10).join("\n")}"
    )
    Outcome.new(rebuilder: nil, error: e)
  end

  # 画面に返す警告の文言
  def self.failure_message(error)
    "登板の保存値（結果区分・疲労P・連続中4日回数）の作り直しに失敗しました（保存は済んでいます。管理者に連絡してください）: #{error.class}"
  end
end
