class BattingStatsCalculator
  DOUBLE_CODES   = %w[2H 2B].freeze
  TRIPLE_CODES   = %w[3H 3B].freeze
  HR_CODES       = %w[HR].freeze
  HIT_CODES      = %w[H 1B].freeze
  WALK_CODES     = %w[BB].freeze
  HBP_CODES      = %w[HBP].freeze
  SAC_CODES      = %w[SAC SH].freeze
  SF_CODES       = %w[SF].freeze

  def initialize(competition)
    @competition = competition
  end

  def calculate
    game_ids = @competition.games.where(status: "confirmed").pluck(:id)
    return [] if game_ids.empty?

    at_bats = AtBat.where(game_id: game_ids, status: :confirmed).includes(:batter)

    at_bats.group_by(&:batter_id).map do |batter_id, bats|
      player = bats.first.batter
      calc_batter_stats(batter_id, player.name, bats, game_ids)
    end.sort_by { |s| -s[:batting_average] }
  end

  private

  def calc_batter_stats(player_id, player_name, bats, game_ids)
    games_played    = bats.map(&:game_id).uniq.size
    hits            = 0
    doubles         = 0
    triples         = 0
    home_runs       = 0
    walks           = 0
    hbp             = 0
    strikeouts      = 0
    sacrifice_hits  = 0
    sacrifice_flies = 0
    at_bat_count    = 0
    total_rbi       = 0

    bats.each do |ab|
      code = ab.result_code.to_s.upcase
      total_rbi += ab.rbi.to_i

      if HR_CODES.include?(code)
        hits += 1; home_runs += 1; at_bat_count += 1
      elsif TRIPLE_CODES.include?(code)
        hits += 1; triples += 1; at_bat_count += 1
      elsif DOUBLE_CODES.include?(code)
        hits += 1; doubles += 1; at_bat_count += 1
      elsif HIT_CODES.include?(code)
        hits += 1; at_bat_count += 1
      elsif WALK_CODES.include?(code)
        walks += 1
      elsif HBP_CODES.include?(code)
        hbp += 1
      elsif SAC_CODES.include?(code)
        sacrifice_hits += 1
      elsif SF_CODES.include?(code)
        sacrifice_flies += 1
      elsif code.start_with?("K")
        strikeouts += 1; at_bat_count += 1
      else
        at_bat_count += 1
      end
    end

    plate_appearances = at_bat_count + walks + hbp + sacrifice_hits + sacrifice_flies
    singles           = hits - doubles - triples - home_runs

    batting_average = at_bat_count > 0 ? (hits.to_f / at_bat_count).round(3) : 0.0

    obp_denom   = at_bat_count + walks + hbp + sacrifice_flies
    on_base_pct = obp_denom > 0 ? ((hits + walks + hbp).to_f / obp_denom).round(3) : 0.0

    total_bases  = singles + 2 * doubles + 3 * triples + 4 * home_runs
    slugging_pct = at_bat_count > 0 ? (total_bases.to_f / at_bat_count).round(3) : 0.0

    ops = (on_base_pct + slugging_pct).round(3)

    stolen_bases = GameEvent.where(game_id: game_ids, event_type: "stolen_base")
                            .where("details->>'player_id' = ?", player_id.to_s)
                            .count

    {
      player_id:        player_id,
      player_name:      player_name,
      games_played:     games_played,
      plate_appearances: plate_appearances,
      at_bat_count:     at_bat_count,
      hits:             hits,
      doubles:          doubles,
      triples:          triples,
      home_runs:        home_runs,
      rbi:              total_rbi,
      strikeouts:       strikeouts,
      walks:            walks,
      hbp:              hbp,
      sacrifice_hits:   sacrifice_hits,
      sacrifice_flies:  sacrifice_flies,
      stolen_bases:     stolen_bases,
      batting_average:  batting_average,
      on_base_pct:      on_base_pct,
      slugging_pct:     slugging_pct,
      ops:              ops
    }
  end
end
