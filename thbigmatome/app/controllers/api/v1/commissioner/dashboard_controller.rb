require "csv"

class Api::V1::Commissioner::DashboardController < Api::V1::Commissioner::BaseController
  include CooldownCalculable

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

  def costs
    current_cost = Cost.current_cost
    return render json: [] unless current_cost

    teams = Team.where(is_active: true).includes(
      team_memberships: { player: :cost_players }
    )

    result = teams.map do |team|
      memberships = team.team_memberships
      first_squad = memberships.select { |tm| tm.squad == "first" }

      total = memberships.reject(&:excluded_from_team_total).sum do |tm|
        cp = tm.player.cost_players.find { |c| c.cost_id == current_cost.id }
        cp&.send(tm.selected_cost_type) || 0
      end

      first_cost = first_squad.sum do |tm|
        cp = tm.player.cost_players.find { |c| c.cost_id == current_cost.id }
        cp&.send(tm.selected_cost_type) || 0
      end

      first_limit = Team.first_squad_cost_limit_for_count(first_squad.count)
      exempt_count = memberships.count(&:excluded_from_team_total)

      {
        team_id: team.id,
        team_name: team.name,
        team_type: team.team_type,
        total_cost: total,
        total_cost_limit: 200,
        first_squad_cost: first_cost,
        first_squad_cost_limit: first_limit,
        first_squad_count: first_squad.count,
        exempt_count: exempt_count,
        cost_usage_ratio: total / 200.0
      }
    end

    render json: result
  end

  def cooldowns
    teams = Team.where(is_active: true).includes(
      :season,
      team_memberships: [ :player, :season_rosters ]
    )

    cooldowns = []
    teams.each do |team|
      season = team.season
      next unless season

      team.team_memberships.each do |tm|
        next unless tm.squad == "second"

        info = calculate_cooldown_info(tm, season.current_date)
        next unless info[:cooldown_until]

        remaining_days = (info[:cooldown_until].to_date - season.current_date.to_date).to_i
        cooldowns << {
          team_name: team.name,
          team_id: team.id,
          player_name: tm.player.name,
          player_id: tm.player_id,
          demotion_date: info[:demotion_date],
          cooldown_until: info[:cooldown_until],
          remaining_days: [ remaining_days, 0 ].max,
          same_day_exempt: info[:same_day_exempt]
        }
      end
    end

    render json: cooldowns
  end

  def roster_status
    current_cost = Cost.current_cost

    teams = Team.where(is_active: true).includes(
      :season,
      team_memberships: [
        :season_rosters,
        { player_absences: :season },
        { player: [ :cost_players ] },
        { player_card: [ :card_set, :player_card_defenses ] }
      ]
    ).order(:name)

    team_id = params[:team_id]
    teams = teams.where(id: team_id) if team_id.present?

    if params[:format] == "csv"
      csv_data = build_roster_csv(teams, current_cost)
      filename = if team_id.present?
        team = teams.first
        short = team&.name&.gsub(/\s+/, "_") || "team"
        "roster_status_#{short}_#{Date.today.strftime('%Y%m%d')}.csv"
      else
        "roster_status_all_#{Date.today.strftime('%Y%m%d')}.csv"
      end
      send_data csv_data, filename: filename, type: "text/csv; charset=utf-8", disposition: "attachment"
    else
      result = teams.map { |team| build_roster_summary(team, current_cost) }
      render json: result
    end
  end

  private

  def build_roster_summary(team, current_cost)
    season = team.season
    memberships = team.team_memberships
    first_squad = memberships.select { |tm| tm.squad == "first" }
    second_squad = memberships.select { |tm| tm.squad == "second" }

    native_series = Team::NATIVE_SERIES[team.team_type] || Team::NATIVE_SERIES["normal"]
    outside_world_count = first_squad.count { |tm| !native_series.include?(tm.player.series) }

    first_cost = 0
    if current_cost
      first_cost = first_squad.sum do |tm|
        cp = tm.player.cost_players.find { |c| c.cost_id == current_cost.id }
        cp&.send(tm.selected_cost_type) || 0
      end
    end

    first_cost_limit = Team.first_squad_cost_limit_for_count(first_squad.count)

    warnings = []
    warnings << "コスト上限を超過しています" if first_cost_limit && first_cost > first_cost_limit
    warnings << "外の世界枠が上限を超過しています" if outside_world_count > Team::OUTSIDE_WORLD_LIMIT

    {
      team_id: team.id,
      team_name: team.name,
      team_type: team.team_type,
      game_date: season&.current_date,
      first_count: first_squad.count,
      second_count: second_squad.count,
      first_cost: first_cost,
      first_cost_limit: first_cost_limit,
      outside_world_count: outside_world_count,
      outside_world_limit: Team::OUTSIDE_WORLD_LIMIT,
      warnings: warnings
    }
  end

  def build_roster_csv(teams, current_cost)
    bom = "\uFEFF"
    headers = %w[チーム名 チーム種別 ゲーム内日付 背番号 選手名 軍 ポジション 投打 シリーズ 外の世界枠 コスト種別 コスト 離脱種別 クールダウン終了日]

    csv_string = CSV.generate(bom, encoding: "UTF-8") do |csv|
      csv << headers
      teams.each do |team|
        season = team.season
        native_series = Team::NATIVE_SERIES[team.team_type] || Team::NATIVE_SERIES["normal"]
        game_date = season&.current_date

        memberships = team.team_memberships.sort_by do |tm|
          squad_order = tm.squad == "first" ? 0 : 1
          [ squad_order, tm.player.number.to_i ]
        end

        memberships.each do |tm|
          player = tm.player
          card = tm.player_card
          is_fielder_only = tm.selected_cost_type == "fielder_only_cost"
          position = if card&.card_type == "pitcher" && !is_fielder_only
            "pitcher"
          else
            card&.player_card_defenses&.first&.position&.downcase
          end

          cost_value = 0
          if current_cost
            cp = player.cost_players.find { |c| c.cost_id == current_cost.id }
            cost_value = cp&.send(tm.selected_cost_type) || 0
          end

          absence_type = nil
          cooldown_until = nil

          if season
            active_absence = tm.player_absences.find do |pa|
              next false unless pa.season_id == season.id
              end_date = pa.effective_end_date
              end_date.nil? || end_date >= season.current_date
            end
            absence_type = active_absence&.absence_type

            cooldown_info = calculate_cooldown_info(tm, season.current_date)
            cooldown_until = cooldown_info[:cooldown_until]
          end

          effective_series = card&.card_set&.series.presence || player.series
          is_outside_world = effective_series.present? && !native_series.include?(effective_series)

          csv << [
            team.name,
            translate_team_type(team.team_type),
            game_date,
            player.number,
            player.short_name.presence || player.name,
            translate_squad(tm.squad),
            translate_position(position),
            card&.handedness,
            player.series,
            is_outside_world ? "○" : "×",
            translate_cost_type(tm.selected_cost_type),
            cost_value,
            translate_absence_type(absence_type),
            cooldown_until
          ]
        end
      end
    end

    csv_string
  end

  def translate_team_type(value)
    { "normal" => "通常", "hachinai" => "ハチナイ" }[value] || value
  end

  def translate_squad(value)
    { "first" => "1軍", "second" => "2軍" }[value] || value
  end

  def translate_position(value)
    {
      "pitcher" => "投手", "catcher" => "捕手",
      "first_base" => "一塁手", "second_base" => "二塁手",
      "third_base" => "三塁手", "shortstop" => "遊撃手",
      "left_field" => "左翼手", "center_field" => "中堅手",
      "right_field" => "右翼手", "dh" => "指名打者"
    }[value] || value
  end

  def translate_cost_type(value)
    {
      "normal_cost" => "通常", "relief_only_cost" => "リリーフ専",
      "pitcher_only_cost" => "投手専", "fielder_only_cost" => "野手専",
      "dual_cost" => "二刀流"
    }[value] || value
  end

  def translate_absence_type(value)
    return nil if value.nil?
    { "injury" => "負傷", "suspension" => "出場停止", "reconditioning" => "再調整" }[value] || value
  end

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
