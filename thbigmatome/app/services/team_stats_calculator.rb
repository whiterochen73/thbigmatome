class TeamStatsCalculator
  # top half = visitor batting / home pitching
  # bottom half = home batting / visitor pitching
  HIT_CODES     = %w[H 1B 2H 2B 3H 3B HR].freeze
  NON_AB_CODES  = %w[BB HBP SAC SH SF].freeze

  def initialize(competition)
    @competition = competition
  end

  def calculate
    confirmed_games = @competition.games.where(status: "confirmed")
                                  .includes(:home_team, :visitor_team)
    return [] if confirmed_games.empty?

    game_ids       = confirmed_games.map(&:id)
    at_bats        = AtBat.where(game_id: game_ids, status: :confirmed)
    abs_by_game    = at_bats.group_by(&:game_id)

    pgs_records    = PitcherGameState.where(game_id: game_ids)
    pgs_by_game    = pgs_records.group_by(&:game_id)

    team_records   = Hash.new { |h, k| h[k] = zero_record }
    teams_cache    = {}
    team_ip_thirds = Hash.new(0)
    team_er        = Hash.new(0)

    confirmed_games.each do |game|
      home_id    = game.home_team_id
      visitor_id = game.visitor_team_id
      teams_cache[home_id]    = game.home_team
      teams_cache[visitor_id] = game.visitor_team

      # W / L / D and runs
      if game.home_score && game.visitor_score
        home_rec    = team_records[home_id]
        visitor_rec = team_records[visitor_id]

        home_rec[:runs_scored]    += game.home_score
        home_rec[:runs_allowed]   += game.visitor_score
        visitor_rec[:runs_scored]  += game.visitor_score
        visitor_rec[:runs_allowed] += game.home_score

        if game.home_score > game.visitor_score
          home_rec[:wins]    += 1
          visitor_rec[:losses] += 1
        elsif game.visitor_score > game.home_score
          visitor_rec[:wins] += 1
          home_rec[:losses]  += 1
        else
          home_rec[:draws]    += 1
          visitor_rec[:draws] += 1
        end
      end

      # Batting stats (hits / at-bats per team)
      (abs_by_game[game.id] || []).each do |ab|
        batting_team_id = ab.half == "bottom" ? home_id : visitor_id
        code            = ab.result_code.to_s.upcase
        rec             = team_records[batting_team_id]

        rec[:hits]    += 1 if HIT_CODES.include?(code)
        rec[:at_bats] += 1 unless NON_AB_CODES.include?(code)
      end

      # Innings pitched and earned runs per team (for ERA)
      (pgs_by_game[game.id] || []).each do |pgs|
        ip    = pgs.innings_pitched.to_f
        whole = ip.floor
        third = (ip * 10 % 10).round
        team_ip_thirds[pgs.team_id] += whole * 3 + third
        team_er[pgs.team_id] += pgs.earned_runs.to_i
      end
    end

    # Build output
    team_records.map do |team_id, rec|
      ba     = rec[:at_bats] > 0 ? (rec[:hits].to_f / rec[:at_bats]).round(3) : 0.0
      thirds = team_ip_thirds[team_id]
      actual_ip = thirds / 3.0
      era    = actual_ip > 0 ? ((team_er[team_id].to_f / actual_ip) * 9).round(2) : 0.0

      {
        team_id:         team_id,
        team_name:       teams_cache[team_id]&.name,
        wins:            rec[:wins],
        losses:          rec[:losses],
        draws:           rec[:draws],
        runs_scored:     rec[:runs_scored],
        runs_allowed:    rec[:runs_allowed],
        batting_average: ba,
        era:             era
      }
    end.sort_by { |s| -s[:wins] }
  end

  private

  def zero_record
    { wins: 0, losses: 0, draws: 0, runs_scored: 0, runs_allowed: 0, hits: 0, at_bats: 0 }
  end
end
