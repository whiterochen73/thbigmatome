# 日程マスタの余分な試合日 2016-09-26 を予備日に直す（cmd_1802 段3。Operator 決定 2026-11-02）。
#
# 調査: context/thbig-dugout-schedule-extra-game-day.md。ペナント日程表（schedule_details）は通常試合日が 126 で、規定（NPB 143 = 通常 125 + 交流戦 18、
# THBIG ルールブック §4.5「通常 143 試合」）より 1 日多い。余分な日は最後の通常試合日 2016-09-26（月）。マスタ作成時（2025-08-09）からの混入。
#
# 直す範囲:
#   - 日程マスタ（schedule_details）の 2016-09-26 の game_day → reserve_day
#   - 9/26 が game_day の既存シーズン（season_schedules）→ reserve_day（シーズンはマスタの写しなので、マスタだけ直しても総数が揃わない）
#   - ただし結果・登板などの入力の痕跡がある行は直さず、keep として理由つきで一覧に出す（前橋: 9/26 に結果 3-1 と登板 7 行。Operator 決定でそのまま）
#
# 書き込みは save!（updated_at は動かさない: touch: false。戻した時に完全に元の値になる）。得点・ノーゲームは変えないので登板の保存値の作り直しは走らない。
# 全体で 1 トランザクション。何度流しても同じ結果になる（9/26 が game_day の行が無ければ直す対象は 0 件。keep の行は毎回一覧に出る）。
class ExtraGameDayFixer
  DATE = Date.new(2016, 9, 26)
  FROM_TYPE = "game_day".freeze
  TO_TYPE = "reserve_day".freeze

  # 入力の痕跡とみなすシーズン側の列。1 つでも入っている行は直さない（no_game は真の時だけ。pitcher_game_states は別に数える）
  RECORD_COLUMNS = %i[score opponent_score opponent_team_id announced_starter_id winning_pitcher_id losing_pitcher_id save_pitcher_id
                      game_log scoreboard starting_lineup opponent_starting_lineup real_date real_start_time venue stadium home_away
                      designated_hitter_enabled].freeze

  # kind: "master"（schedule_details）/ "season"（season_schedules）。status: :fix / :keep（入力の痕跡があるので直さない）
  Row = Struct.new(:kind, :record_id, :season_id, :team_id, :date, :old_date_type, :new_date_type, :status, :pitcher_count, :reasons, keyword_init: true) do
    def to_csv_h
      { kind: kind, record_id: record_id, season_id: season_id, team_id: team_id, date: date, old_date_type: old_date_type,
        new_date_type: new_date_type, status: status.to_s, pitcher_count: pitcher_count, reasons: reasons.join(" ") }
    end
  end

  attr_reader :rows

  def initialize(team_id: nil)
    @team_id = team_id.presence&.to_i
    @rows = []
  end

  # 対象を数える（DB は書かない）。team_id を渡した時はそのチームのシーズンだけ（マスタは対象にしない）
  def call
    @rows = []
    master_rows unless @team_id
    season_rows
    self
  end

  def fixes
    @rows.select { |r| r.status == :fix }
  end

  def keeps
    @rows.select { |r| r.status == :keep }
  end

  # { master_fix:, season_fix:, season_keep: }（件数。0 の項目も出す）
  def summary
    {
      master_fix: @rows.count { |r| r.kind == "master" && r.status == :fix },
      season_fix: @rows.count { |r| r.kind == "season" && r.status == :fix },
      season_keep: @rows.count { |r| r.kind == "season" && r.status == :keep }
    }
  end

  # 書く（全体で 1 トランザクション）。:fix の行だけ
  def apply!
    ActiveRecord::Base.transaction do
      fixes.each { |row| write_type!(row.kind, row.record_id, row.new_date_type) }
    end
    self
  end

  # apply! の CSV（kind, record_id, old_date_type, new_date_type, status）から逆向きに当てる。今の値が new_date_type と一致する行だけ戻す
  # （食い違う行は戻さず返す）。戻り値: { reverted: 件数, skipped: [[kind, record_id], ...] }
  def self.revert!(csv_rows)
    reverted = 0
    skipped = []
    ActiveRecord::Base.transaction do
      csv_rows.each do |r|
        kind = r.fetch("kind")
        id = r.fetch("record_id").to_i
        record = model_of(kind).find_by(id: id)
        if record.nil? || record.date_type != r.fetch("new_date_type")
          skipped << [ kind, id ]
          next
        end

        write_type!(kind, id, r.fetch("old_date_type"))
        reverted += 1
      end
    end
    { reverted: reverted, skipped: skipped }
  end

  def self.model_of(kind)
    kind == "master" ? ScheduleDetail : SeasonSchedule
  end

  def self.write_type!(kind, id, date_type)
    record = model_of(kind).find(id)
    record.date_type = date_type
    record.save!(touch: false)
  end

  private

  def write_type!(kind, id, date_type)
    self.class.write_type!(kind, id, date_type)
  end

  def master_rows
    ScheduleDetail.where(date: DATE, date_type: FROM_TYPE).order(:id).each do |detail|
      @rows << Row.new(kind: "master", record_id: detail.id, date: detail.date, old_date_type: detail.date_type, new_date_type: TO_TYPE,
                       status: :fix, pitcher_count: 0, reasons: [])
    end
  end

  def season_rows
    targets = SeasonSchedule.joins(:season).where(date: DATE, date_type: FROM_TYPE).order(:id)
    targets = targets.where(seasons: { team_id: @team_id }) if @team_id
    pitcher_counts = PitcherGameState.group(:team_id, :schedule_date).count
    linked_counts = PitcherGameState.where(season_schedule_id: targets.select(:id)).group(:season_schedule_id).count

    targets.includes(:season).each do |schedule|
      team_id = schedule.season.team_id
      pitcher_count = [ pitcher_counts[[ team_id, schedule.date.to_s ]] || 0, linked_counts[schedule.id] || 0 ].max
      reasons = record_reasons(schedule, pitcher_count)
      @rows << Row.new(kind: "season", record_id: schedule.id, season_id: schedule.season_id, team_id: team_id, date: schedule.date,
                       old_date_type: schedule.date_type, new_date_type: TO_TYPE, status: reasons.empty? ? :fix : :keep,
                       pitcher_count: pitcher_count, reasons: reasons)
    end
  end

  # 入力の痕跡がある列の名前（空なら空の行）
  def record_reasons(schedule, pitcher_count)
    reasons = RECORD_COLUMNS.select { |column| (value = schedule[column]).respond_to?(:empty?) ? !value.empty? : !value.nil? }
    reasons << :no_game if schedule.no_game
    reasons << :pitcher_game_states if pitcher_count.positive?
    reasons
  end
end
