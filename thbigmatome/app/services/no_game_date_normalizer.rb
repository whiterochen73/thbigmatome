# 日程の種別 "no_game" の日を、シーズン作成元の日程マスタ（schedule_details）の種別に戻し、真偽値 no_game を真にする
# （cmd_1784 段4。設計書 §4.6）。ノーゲームの表し方を真偽値に一本化するための移行。
#
# シーズンは作成時に日程マスタの schedule_details を season_schedules へ写して作る（seasons#create）が、season が元の schedule の id を
# 持たない。そのため元のマスタは「そのシーズンの日付の集合と同じ日付の集合を持つ schedule」で引き、その日の種別を採る。
#   - 候補が 1 つ以上あり、その日の種別が 1 通りで、no_game でもない → restore（戻す）
#   - 候補が無い（日付の集合が合う schedule が無い）、その日がマスタに無い → unresolved（止める）
#   - 候補ごとに種別が割れる → ambiguous（止める）
#   - マスタの種別自体が no_game → master_no_game（止める）
# 止める行が 1 つでもあれば、APPLY=1 でも何も書かない（呼び出し側が expect_clean! で止める）。
#
# マスタの種別が予備日（reserve_day / interleague_reserve_day）の日は、予備日のままではなく試合日（game_day / interleague_game_day）＋
# no_game 真に戻す（RESERVE_AS_GAME_DAY。Operator 2026-11-02。予備日に組まれた試合がノーゲームになったと読む）。種別が試合日なので画面から
# 勝敗・登板を触れ、試合数（counted_games）には数えない。
# それ以外の試合日でない種別に戻る日（移動日など）があれば、種別が試合日でないまま真偽値 no_game が立つ。画面から勝敗・登板を触れるのは
# 種別が試合日の日だけなので、一覧（not_game_type）に出す。
#
# 書き込みは SeasonSchedule#save!（updated_at は動かさない: touch: false）。after_save が登板の結果区分・疲労P を作り直す
# （画面でノーゲームを立てた時と同じ経路）。作り直しが落ちたら全体を巻き戻す。
class NoGameDateNormalizer
  class Unresolved < StandardError; end

  # マスタの種別が予備日の日にノーゲームがあった時、戻す先の種別（予備日に組まれた試合がノーゲームになったと読む）
  RESERVE_AS_GAME_DAY = { "reserve_day" => "game_day", "interleague_reserve_day" => "interleague_game_day" }.freeze

  # status: :restore / :unresolved / :ambiguous / :master_no_game
  Row = Struct.new(:schedule_id, :season_id, :team_id, :date, :old_date_type, :old_no_game, :new_date_type, :new_no_game,
                   :status, :master_types, :pitcher_count, keyword_init: true) do
    def stop?
      status != :restore
    end

    def not_game_type?
      status == :restore && !SeasonSchedule::GAME_DATE_TYPES.include?(new_date_type)
    end
  end

  attr_reader :rows

  def initialize(team_id: nil)
    @team_id = team_id.presence&.to_i
    @rows = []
  end

  def call
    targets = SeasonSchedule.joins(:season).where(date_type: SeasonSchedule::NO_GAME_DATE_TYPE).order(:id)
    targets = targets.where(seasons: { team_id: @team_id }) if @team_id
    pitcher_counts = PitcherGameState.group(:team_id, :schedule_date).count
    masters = master_index

    targets.includes(:season).each do |schedule|
      date_set = SeasonSchedule.where(season_id: schedule.season_id).pluck(:date).to_set
      types = masters.filter_map { |dates| dates[schedule.date] if dates.keys.to_set == date_set }.uniq
      status, new_type = classify(types)
      @rows << Row.new(
        schedule_id: schedule.id, season_id: schedule.season_id, team_id: schedule.season.team_id, date: schedule.date,
        old_date_type: schedule.date_type, old_no_game: schedule.no_game, new_date_type: new_type, new_no_game: true,
        status: status, master_types: types, pitcher_count: pitcher_counts[[ schedule.season.team_id, schedule.date.to_s ]] || 0
      )
    end
    self
  end

  def stops
    @rows.select(&:stop?)
  end

  def not_game_type
    @rows.select(&:not_game_type?)
  end

  def summary
    @rows.group_by(&:status).transform_values(&:size)
  end

  # 止める行があれば例外にする
  def expect_clean!
    return if stops.empty?

    raise Unresolved, "元の種別を決められない日が #{stops.size} 日ある（#{stops.map { |r| "#{r.schedule_id}:#{r.status}" }.join(', ')}）。何も書かない"
  end

  # 書く（全体で 1 トランザクション）。種別と真偽値を直し、登板の保存値の作り直しが落ちたら全体を巻き戻す
  def apply!
    expect_clean!
    SeasonSchedule.transaction do
      @rows.each do |row|
        schedule = SeasonSchedule.find(row.schedule_id)
        schedule.date_type = row.new_date_type
        schedule.no_game = row.new_no_game
        schedule.save!(touch: false)
        raise schedule.pitcher_rebuild_error if schedule.pitcher_rebuild_error
      end
    end
    self
  end

  # apply! が出した CSV（schedule_id, old_*, new_*）から逆向きに当てる。今の値が new_* と一致する行だけ戻す（食い違う行は戻さず返す）。
  # 戻り値: { reverted: 件数, skipped: [schedule_id, ...] }
  def self.revert!(csv_rows)
    reverted = 0
    skipped = []
    SeasonSchedule.transaction do
      csv_rows.each do |r|
        schedule = SeasonSchedule.find_by(id: r.fetch("schedule_id"))
        if schedule.nil? || schedule.date_type != r.fetch("new_date_type") || schedule.no_game != (r.fetch("new_no_game").to_s == "true")
          skipped << r.fetch("schedule_id")
          next
        end

        # 種別 no_game は新たには作れない（検証）。戻す時だけ検証を通さず列を書き、真偽値の保存で登板の保存値を作り直す
        schedule.update_columns(date_type: r.fetch("old_date_type"))
        schedule.no_game = r.fetch("old_no_game").to_s == "true"
        schedule.save!(touch: false)
        raise schedule.pitcher_rebuild_error if schedule.pitcher_rebuild_error

        reverted += 1
      end
    end
    { reverted: reverted, skipped: skipped }
  end

  private

  # [{ date => date_type }, ...]（schedule ごと）
  def master_index
    ScheduleDetail.pluck(:schedule_id, :date, :date_type).group_by(&:first)
                  .values.map { |list| list.to_h { |_, date, type| [ date, type ] } }
  end

  def classify(types)
    return [ :unresolved, nil ] if types.empty?
    return [ :ambiguous, nil ] if types.size > 1
    return [ :master_no_game, nil ] if types.first == SeasonSchedule::NO_GAME_DATE_TYPE

    [ :restore, RESERVE_AS_GAME_DAY.fetch(types.first, types.first) ]
  end
end
