module Api
  module V1
    class TeamRostersController < Api::V1::BaseController
      def show
        team = Team.find(params[:team_id])
        season = team.season
        if season.nil?
          render json: { error: "Season not initialized for this team" }, status: :not_found
          return
        end

        current_cost_list = Cost.current_cost

        # Get the date from params, default to season's current_date if not provided
        target_date = season.current_date

        # Fetch all team memberships for the team
        team_memberships = team.team_memberships.preload(:season_rosters, :player_absences, player: [ :cost_players, :player_types ])
        start_date = season.season_schedules.minimum(:date)

        # Determine current squad for each player based on the latest SeasonRoster entry
        roster_data = team_memberships.map do |tm|
          latest_roster_entry = tm.season_rosters
                                  .where("registered_on <= ?", target_date)
                                  .order(registered_on: :desc, created_at: :desc)
                                  .first

          squad_status = latest_roster_entry ? latest_roster_entry.squad : tm.squad # Fallback to default squad from team_membership

          cooldown_info = calculate_cooldown_info(tm, target_date)

          {
            team_membership_id: tm.id,
            player_id: tm.player.id,
            number: tm.player.number,
            player_name: tm.player.short_name,
            throwing_hand: tm.player.throwing_hand,
            batting_hand: tm.player.batting_hand,
            squad: squad_status,
            position: tm.player.position, # Add player position
            player_types: tm.player.player_types.pluck([ :name ]), # Add player types
            selected_cost_type: tm.selected_cost_type, # Add selected cost type
            cost: tm.player.cost_players.find { |pc| pc.cost_id == current_cost_list.id }.send(tm.selected_cost_type), # Assuming player has cost methods
            # Add cooldown information if applicable
            cooldown_until: cooldown_info[:cooldown_until],
            same_day_exempt: cooldown_info[:same_day_exempt],
            is_outside_world: tm.player.player_types.any? { |pt| pt.category == "outside_world" },
            **absence_info_for(tm, target_date)
          }
        end

        render json: {
          season_id: season.id,
          current_date: target_date,
          season_start_date: start_date, # Assuming season has schedule association
          key_player_id: season.key_player_id,
          roster: roster_data
        }, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Team or Season not found" }, status: :not_found
      rescue ArgumentError
        render json: { error: "Invalid date format" }, status: :bad_request
      end

      def create
        team = Team.find(params[:team_id])
        season = team.season
        if season.nil?
          render json: { error: "Season not initialized for this team" }, status: :bad_request
          return
        end

        @current_cost_list = Cost.current_cost

        # Expects an array of { team_membership_id: id, squad: 'first' | 'second' }
        roster_updates = params[:roster_updates]
        target_date = Date.parse(params[:target_date]) # Date for which the roster is being set
        season_start_date = season.season_schedules.minimum(:date) # Calculate season start date once

        ActiveRecord::Base.transaction do
          # Phase 1: Apply all squad changes (cooldown check only, no cost validation yet)
          roster_updates.each do |update|
            team_membership = team.team_memberships.find(update[:team_membership_id])
            new_squad = update[:squad]

            if team_membership.squad == "first" && new_squad == "second"
              team_membership.update!(squad: new_squad)
              SeasonRoster.create!(
                season: season,
                team_membership: team_membership,
                squad: new_squad,
                registered_on: target_date
              )
            elsif team_membership.squad == "second" && new_squad == "first"
              # Check cooldown (per-player constraint, unaffected by batch order)
              # Same-day promotion+demotion is exempt from cooldown
              cooldown_info = calculate_cooldown_info(team_membership, target_date)
              if cooldown_info[:cooldown_until] && !cooldown_info[:same_day_exempt]
                raise "Player #{team_membership.player.name} is on cooldown until #{cooldown_info[:cooldown_until]}"
              end

              team_membership.update!(squad: new_squad)
              SeasonRoster.create!(
                season: season,
                team_membership: team_membership,
                squad: new_squad,
                registered_on: target_date
              )
            end
          end

          # Phase 2: Validate final state of 1st squad after all changes
          final_first_squad = team.team_memberships.reload.select { |tm| tm.squad == "first" }
          validate_first_squad_constraints(final_first_squad, target_date, season, season_start_date)

          # Phase 3: Validate outside world constraints
          team.reload
          team.errors.clear
          unless team.validate_outside_world_limit
            raise team.errors.full_messages.first
          end
          team.errors.clear
          unless team.validate_outside_world_balance
            raise team.errors.full_messages.first
          end
        end

        # Collect warnings for absent players being promoted
        warnings = collect_absence_warnings(team, target_date, roster_updates)

        render json: { message: "Roster updated successfully", warnings: warnings }, status: :ok
      rescue ActiveRecord::RecordNotFound => e
        render json: { error: e.message }, status: :not_found
      rescue => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      # Helper to get current squad for a given date
      def get_current_squad_for_date(team, squad_name, date)
        team.team_memberships.map do |tm|
          latest_roster_entry = tm.season_rosters
                                  .where("registered_on <= ?", date)
                                  .order(registered_on: :desc, created_at: :desc)
                                  .first
          if latest_roster_entry && latest_roster_entry.squad == squad_name
            tm
          else
            nil
          end
        end.compact
      end

      # Rule 3: Cooldown calculation with same-day exemption info
      # Returns { cooldown_until: Date|nil, same_day_exempt: boolean }
      def calculate_cooldown_info(team_membership, current_date)
        last_demotion = team_membership.season_rosters
                          .where(squad: "second")
                          .order(registered_on: :desc, created_at: :desc)
                          .first

        return { cooldown_until: nil, same_day_exempt: false } unless last_demotion

        # Find the most recent promotion before this demotion (including same-day entries)
        previous_promotion = team_membership.season_rosters
                               .where(squad: "first")
                               .where(
                                 "registered_on < :date OR (registered_on = :date AND created_at < :cat)",
                                 date: last_demotion.registered_on, cat: last_demotion.created_at
                               )
                               .order(registered_on: :desc, created_at: :desc)
                               .first

        return { cooldown_until: nil, same_day_exempt: false } unless previous_promotion

        cooldown_end_date = last_demotion.registered_on + 10.days
        return { cooldown_until: nil, same_day_exempt: false } unless current_date < cooldown_end_date

        same_day = previous_promotion.registered_on == last_demotion.registered_on
        { cooldown_until: cooldown_end_date, same_day_exempt: same_day }
      end

      # Check if a team_membership has an active absence at the given date
      def absence_info_for(team_membership, target_date)
        active_absence = team_membership.player_absences.find do |pa|
          end_date = pa.effective_end_date
          if end_date
            target_date >= pa.start_date && target_date < end_date
          else
            target_date >= pa.start_date
          end
        end

        if active_absence
          {
            is_absent: true,
            absence_info: {
              absence_type: active_absence.absence_type,
              reason: active_absence.reason,
              effective_end_date: active_absence.effective_end_date&.to_s,
              remaining_days: active_absence.effective_end_date ? (active_absence.effective_end_date - target_date).to_i : nil,
              duration_unit: active_absence.duration_unit
            }
          }
        else
          { is_absent: false, absence_info: nil }
        end
      end

      # Collect warnings for absent players being promoted to first squad
      def collect_absence_warnings(team, target_date, roster_updates)
        warnings = []
        roster_updates.each do |update|
          next unless update[:squad] == "first"
          tm = team.team_memberships.preload(:player_absences).find_by(id: update[:team_membership_id])
          next unless tm
          info = absence_info_for(tm, target_date)
          next unless info[:is_absent]
          warnings << {
            type: "player_absent",
            player_id: tm.player_id,
            player_name: tm.player.name,
            message: "#{tm.player.name}は現在離脱中です（#{I18n.t("enums.player_absence.absence_type.#{info[:absence_info][:absence_type]}", default: info[:absence_info][:absence_type])}）"
          }
        end
        warnings
      end

      # Rule 4 & 5: Validate 1st team constraints
      def validate_first_squad_constraints(first_squad_memberships, target_date, season, season_start_date)
        player_count = first_squad_memberships.count
        total_cost = first_squad_memberships.sum { |tm| tm.player.cost_players.find { |pc| pc.cost_id == @current_cost_list.id }.send(tm.selected_cost_type) }

        max_players = 29
        minimum_players = Team.first_squad_minimum_players

        # Check if target_date is a game day
        is_game_day = season.season_schedules.exists?(date: target_date, date_type: "game_day")

        # Check if it's the very first day of the season AND it's a game day
        is_first_game_day_of_season = is_game_day && (target_date == season_start_date)

        if is_game_day
          if is_first_game_day_of_season && player_count < minimum_players
            # Do not raise error for minimum player count on the first game day during initial setup
          elsif player_count < minimum_players
            raise "試合日には1軍に最低#{minimum_players}人を登録する必要があります。"
          end
        end

        if player_count > max_players
          raise "1軍に登録できる選手の最大数（#{max_players}人）を超えています。"
        end

        # 1軍コスト上限: 人数別段階制（config/cost_limits.yml）
        max_cost = Team.first_squad_cost_limit_for_count(player_count)
        if max_cost && total_cost > max_cost
          raise "1軍に登録されている選手の合計コストが上限（#{max_cost}）を超えています。"
        end
      end
    end
  end
end
