class Api::V1::GameRecordsController < Api::V1::BaseController
  before_action :set_game_record, only: [ :show, :confirm ]

  # GET /api/v1/game_records
  def index
    game_records = GameRecord.all.order(id: :desc)
    game_records = game_records.where(team_id: params[:team_id]) if params[:team_id].present?
    game_records = game_records.where(status: params[:status]) if params[:status].present?
    if params[:game_date_from].present? && params[:game_date_to].present?
      game_records = game_records.where(game_date: params[:game_date_from]..params[:game_date_to])
    end

    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 20).to_i.clamp(1, 100)
    total = game_records.count
    game_records = game_records.offset((page - 1) * per_page).limit(per_page)

    render json: {
      game_records: game_records.map { |gr| serialize_game_record(gr) },
      pagination: {
        page: page,
        per_page: per_page,
        total: total,
        total_pages: (total.to_f / per_page).ceil
      }
    }
  end

  # GET /api/v1/game_records/:id
  def show
    render json: serialize_game_record(@game_record, include_at_bats: true)
  end

  # POST /api/v1/game_records
  def create
    game_record = GameRecord.new(game_record_params)
    game_record.status = "draft"

    GameRecord.transaction do
      game_record.save!

      if params[:at_bat_records].present?
        params[:at_bat_records].each do |ab_params|
          attrs = at_bat_record_create_params(ab_params).to_h
          raw_disc = ab_params[:discrepancies] || ab_params["discrepancies"]
          attrs[:discrepancies] = AtBatRecordBuilder.normalize_discrepancies(raw_disc) if raw_disc.present?
          attrs[:source_events] = AtBatRecordBuilder.build_source_events(ab_params)
          game_record.at_bat_records.create!(attrs)
        end
      end
    end

    render json: serialize_game_record(game_record, include_at_bats: true), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_content
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordNotSaved => e
    render json: { errors: [ e.message ] }, status: :unprocessable_content
  end

  # POST /api/v1/game_records/:id/confirm
  def confirm
    unless @game_record.draft?
      return render json: { error: "Game record is not in draft status" }, status: :unprocessable_content
    end

    GameRecord.transaction do
      @game_record.update!(status: "confirmed", confirmed_at: Time.current)
      @game_record.at_bat_records.update_all(is_reviewed: true)

      # Calculate and persist stats based on adopted_value
      calculate_game_stats(@game_record)
    end
    render json: serialize_game_record(@game_record, include_at_bats: false)
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_content
  end

  private

  def set_game_record
    @game_record = GameRecord.includes(:at_bat_records).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Game record not found" }, status: :not_found
  end

  def game_record_params
    params.permit(
      :team_id, :opponent_team_name, :game_date, :played_at, :stadium,
      :score_home, :score_away, :result, :source_log, :parser_version, :parsed_at
    )
  end

  def at_bat_record_create_params(ab_params)
    ab_params.permit(
      :inning, :half, :ab_num, :pitcher_name, :pitcher_id, :batter_name, :batter_id,
      :pitch_roll, :pitch_result, :bat_roll, :bat_result, :result_code, :strategy,
      :outs_before, :outs_after, :runs_scored, :play_description,
      runners_before: {}, runners_after: {}, extra_data: {}, source_events: []
    )
  end

  def serialize_game_record(game_record, include_at_bats: false)
    data = {
      id: game_record.id,
      team_id: game_record.team_id,
      opponent_team_name: game_record.opponent_team_name,
      game_date: game_record.game_date,
      played_at: game_record.played_at,
      stadium: game_record.stadium,
      score_home: game_record.score_home,
      score_away: game_record.score_away,
      result: game_record.result,
      status: game_record.status,
      parser_version: game_record.parser_version,
      parsed_at: game_record.parsed_at,
      confirmed_at: game_record.confirmed_at,
      batting_stats: game_record.batting_stats,
      pitching_stats: game_record.pitching_stats,
      created_at: game_record.created_at,
      updated_at: game_record.updated_at
    }

    if include_at_bats
      data[:at_bat_records] = game_record.at_bat_records.order(:ab_num).map do |ab|
        serialize_at_bat_record(ab)
      end
    end

    data
  end

  def serialize_at_bat_record(ab)
    {
      id: ab.id,
      game_record_id: ab.game_record_id,
      inning: ab.inning,
      half: ab.half,
      ab_num: ab.ab_num,
      pitcher_name: ab.pitcher_name,
      pitcher_id: ab.pitcher_id,
      batter_name: ab.batter_name,
      batter_id: ab.batter_id,
      pitch_roll: ab.pitch_roll,
      pitch_result: ab.pitch_result,
      bat_roll: ab.bat_roll,
      bat_result: ab.bat_result,
      result_code: ab.result_code,
      strategy: ab.strategy,
      runners_before: ab.runners_before,
      runners_after: ab.runners_after,
      outs_before: ab.outs_before,
      outs_after: ab.outs_after,
      runs_scored: ab.runs_scored,
      is_modified: ab.is_modified,
      modified_fields: ab.modified_fields,
      is_reviewed: ab.is_reviewed,
      review_notes: ab.review_notes,
      play_description: ab.play_description,
      extra_data: ab.extra_data,
      discrepancies: ab.discrepancies,
      gsm_value: ab.gsm_value,
      adopted_value: ab.adopted_value,
      source_events: ab.source_events,
      created_at: ab.created_at,
      updated_at: ab.updated_at
    }
  end

  private

  def calculate_game_stats(game_record)
    # Calculate batting and pitching stats based on adopted_value
    # Stats are calculated from adopted_value to reflect human corrections
    at_bat_records = game_record.at_bat_records.order(:ab_num)

    batting_stats = {}
    pitching_stats = {}

    at_bat_records.each do |ab|
      # Use adopted_value if available, otherwise use current values
      result_code = ab.adopted_value&.dig("result_code") || ab.result_code
      runs_scored = (ab.adopted_value&.dig("runs_scored") || ab.runs_scored).to_i

      # Accumulate batting stats
      batter_id = ab.batter_id
      if batting_stats[batter_id].nil?
        batting_stats[batter_id] = {
          batter_id: batter_id,
          batter_name: ab.batter_name,
          games: 1,
          at_bats: 0,
          hits: 0,
          doubles: 0,
          triples: 0,
          home_runs: 0,
          walks: 0,
          strikeouts: 0,
          rbi: 0
        }
      end

      # Update batting stats based on result_code
      case result_code
      when /^HR/               # 1. 本塁打（HRで始まる → 最初に評価）
        batting_stats[batter_id][:hits] += 1
        batting_stats[batter_id][:home_runs] += 1
        batting_stats[batter_id][:at_bats] += 1
        batting_stats[batter_id][:rbi] += runs_scored
      when /^3[BH]/            # 2. 三塁打
        batting_stats[batter_id][:hits] += 1
        batting_stats[batter_id][:triples] += 1
        batting_stats[batter_id][:at_bats] += 1
        batting_stats[batter_id][:rbi] += runs_scored
      when /^2[BH]/            # 3. 二塁打
        batting_stats[batter_id][:hits] += 1
        batting_stats[batter_id][:doubles] += 1
        batting_stats[batter_id][:at_bats] += 1
        batting_stats[batter_id][:rbi] += runs_scored
      when /^(?:H|1B|IH)/     # 4. 単打・内野安打（Hで始まるが非HR）
        batting_stats[batter_id][:hits] += 1
        batting_stats[batter_id][:at_bats] += 1
        batting_stats[batter_id][:rbi] += runs_scored
      when /^(?:BB|DB|SAC|SF)/ # 5. 打数不算入
        # at_bats 加算なし
        batting_stats[batter_id][:walks] += 1 if /^BB/.match?(result_code)
      when /^K/                # 6. 三振
        batting_stats[batter_id][:strikeouts] += 1
        batting_stats[batter_id][:at_bats] += 1
      else                     # 7. その他
        batting_stats[batter_id][:at_bats] += 1
        batting_stats[batter_id][:rbi] += runs_scored
      end

      # Accumulate pitching stats
      pitcher_id = ab.pitcher_id
      if pitching_stats[pitcher_id].nil?
        pitching_stats[pitcher_id] = {
          pitcher_id: pitcher_id,
          pitcher_name: ab.pitcher_name,
          innings_pitched: 0,
          _outs: 0,
          hits_allowed: 0,
          runs_allowed: 0,
          strikeouts: 0,
          walks: 0
        }
      end

      # Update pitching stats
      case result_code
      when /^(?:H|1B|IH|2B|2H|3B|3H|HR)/ # すべての安打（IH含む）
        pitching_stats[pitcher_id][:hits_allowed] += 1
      when /^K/
        pitching_stats[pitcher_id][:strikeouts] += 1
      when /^(?:BB|DB|SAC|SF)/ # 打数に含めない結果
        pitching_stats[pitcher_id][:walks] += 1 if /^BB/.match?(result_code)
      end

      pitching_stats[pitcher_id][:runs_allowed] += runs_scored if runs_scored > 0

      outs_gained = [ (ab.outs_after || 0).to_i - (ab.outs_before || 0).to_i, 0 ].max
      pitching_stats[pitcher_id][:_outs] += outs_gained
    end

    # Convert accumulated outs to innings_pitched (baseball notation: 1.1 = 1 1/3)
    pitching_stats.each_value do |stats|
      total_outs = stats.delete(:_outs) || 0
      stats[:innings_pitched] = (total_outs / 3) + (total_outs % 3) * 0.1
    end

    # Save stats to game_record
    game_record.update!(
      batting_stats: batting_stats,
      pitching_stats: pitching_stats
    )
  end
end
