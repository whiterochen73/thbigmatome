class Api::V1::Commissioner::DashboardController < Api::V1::Commissioner::BaseController
  def absences
    teams = Team.where(is_active: true).includes(
      :season,
      team_memberships: [ :player, { player_absences: :season } ]
    )

    absences = []
    teams.each do |team|
      season = team.season
      next unless season

      team.team_memberships.each do |tm|
        tm.player_absences.each do |pa|
          next unless pa.season_id == season.id
          end_date = pa.effective_end_date
          next if end_date && end_date < season.current_date

          remaining = calculate_remaining(pa, season)
          absences << {
            id: pa.id,
            team_name: team.name,
            team_id: team.id,
            player_name: tm.player.name,
            player_id: tm.player_id,
            absence_type: pa.absence_type,
            reason: pa.reason,
            start_date: pa.start_date,
            duration: pa.duration,
            duration_unit: pa.duration_unit,
            effective_end_date: end_date,
            season_current_date: season.current_date,
            **remaining
          }
        end
      end
    end

    render json: absences
  end

  private

  def calculate_remaining(absence, season)
    end_date = absence.effective_end_date
    return { remaining_days: nil, remaining_games: nil } unless end_date

    if absence.duration_unit == "days"
      remaining_days = (end_date.to_date - season.current_date.to_date).to_i
      { remaining_days: [ remaining_days, 0 ].max, remaining_games: nil }
    else
      remaining_games = season.season_schedules
        .where(date_type: %w[game_day interleague_game_day])
        .where("date >= ? AND date < ?", season.current_date, end_date)
        .count
      { remaining_days: nil, remaining_games: remaining_games }
    end
  end
end
