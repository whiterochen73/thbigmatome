class PitchingStatsCalculator
  HIT_CODES = %w[H 1B 2H 2B 3H 3B HR].freeze
  HR_CODE   = "HR"

  def initialize(competition)
    @competition = competition
  end

  def calculate
    confirmed_games = @competition.games.where(status: "confirmed")
    return [] if confirmed_games.empty?

    game_ids     = confirmed_games.pluck(:id)

    pgs_records  = PitcherGameState.where(game_id: game_ids).includes(:pitcher)
    at_bats      = AtBat.where(game_id: game_ids, status: :confirmed)
    abs_by_pitcher = at_bats.group_by(&:pitcher_id)

    pgs_records.group_by(&:pitcher_id).map do |pitcher_id, pgs_list|
      pitcher         = pgs_list.first.pitcher
      pitcher_at_bats = abs_by_pitcher[pitcher_id] || []
      calc_pitcher_stats(pitcher_id, pitcher.name, pgs_list, pitcher_at_bats)
    end.sort_by { |s| s[:era] }
  end

  private

  # Convert baseball IP notation (6.1 = 6⅓) to thirds of an inning
  def ip_to_thirds(ip_stored)
    ip    = ip_stored.to_f
    whole = ip.floor
    third = (ip * 10 % 10).round
    whole * 3 + third
  end

  def calc_pitcher_stats(player_id, player_name, pgs_list, at_bats)
    total_thirds = pgs_list.sum { |pgs| ip_to_thirds(pgs.innings_pitched) }
    actual_ip    = total_thirds / 3.0
    # Display format: e.g. 19 thirds → 6.1 (6 innings and 1 out)
    ip_display   = (total_thirds / 3).floor + (total_thirds % 3) / 10.0

    strikeouts   = 0
    walks        = 0
    hits_allowed = 0
    hr_allowed   = 0

    at_bats.each do |ab|
      code = ab.result_code.to_s.upcase
      if code.start_with?("K")
        strikeouts += 1
      elsif code == "BB"
        walks += 1
      elsif HIT_CODES.include?(code)
        hits_allowed += 1
        hr_allowed += 1 if code == HR_CODE
      end
    end

    earned_runs = pgs_list.sum(&:earned_runs)

    wins   = pgs_list.count { |pgs| pgs.decision == "W" }
    losses = pgs_list.count { |pgs| pgs.decision == "L" }
    saves  = pgs_list.count { |pgs| pgs.decision == "S" }

    era  = actual_ip > 0 ? ((earned_runs.to_f / actual_ip) * 9).round(2) : 0.0
    whip = actual_ip > 0 ? ((walks + hits_allowed).to_f / actual_ip).round(2) : 0.0

    {
      player_id:       player_id,
      player_name:     player_name,
      wins:            wins,
      losses:          losses,
      saves:           saves,
      era:             era,
      innings_pitched: ip_display,
      strikeouts:      strikeouts,
      walks:           walks,
      whip:            whip,
      hits_allowed:    hits_allowed,
      hr_allowed:      hr_allowed
    }
  end
end
