module Api
  module V1
    class TeamRostersController < Api::V1::BaseController
      include CooldownCalculable
      include TeamAccessible
      before_action :authorize_team_access!

      def show
        team = Team.find(params[:team_id])
        season = team.season
        if season.nil?
          render json: { error: "Season not initialized for this team" }, status: :not_found
          return
        end

        current_cost_list = Cost.current_cost

        # Get the date from params, default to season's current_date if not provided
        target_date = params[:target_date].present? ? Date.parse(params[:target_date]) : season.current_date

        # Fetch all team memberships for the team
        team_memberships = team.team_memberships.preload(:season_rosters, :player_absences, player: [ :cost_players ], player_card: [ :card_set, :player_card_defenses ])
        start_date = season.season_schedules.minimum(:date)

        # Determine current squad for each player based on the latest SeasonRoster entry
        native_series = Team::NATIVE_SERIES[team.team_type] || Team::NATIVE_SERIES["normal"]
        roster_data = team_memberships.map do |tm|
          latest_roster_entry = tm.season_rosters
                                  .where("registered_on <= ?", target_date)
                                  .order(registered_on: :desc, created_at: :desc)
                                  .first

          squad_status = latest_roster_entry ? latest_roster_entry.squad : tm.squad # Fallback to default squad from team_membership

          cooldown_info = calculate_cooldown_info(tm, target_date)

          # 登録カード（player_card）を優先し、未設定の場合はplayer.seriesにフォールバック
          pc = tm.player_card
          effective_series = pc&.card_set&.series.presence || tm.player.series

          {
            team_membership_id: tm.id,
            player_id: tm.player.id,
            number: tm.player.number,
            player_name: tm.player.short_name.presence || tm.player.name,
            handedness: pc&.handedness,
            position: tm.roster_position,
            squad: squad_status,
            player_types: [],
            selected_cost_type: tm.selected_cost_type,
            cost: membership_cost(tm, current_cost_list),
            cooldown_until: cooldown_info[:cooldown_until],
            same_day_exempt: cooldown_info[:same_day_exempt],
            is_outside_world: effective_series.present? && !native_series.include?(effective_series),
            is_pitcher: tm.pitcher_role?,
            is_starter_pitcher: tm.starter_pitcher_role?,
            is_relief_only: tm.relief_only_role?,
            **absence_info_for(tm, target_date)
          }
        end

        previous_game_date = season.season_schedules
          .where("date < ?", target_date)
          .order(date: :desc)
          .limit(1)
          .pick(:date)

        render json: {
          season_id: season.id,
          current_date: target_date,
          season_start_date: start_date, # Assuming season has schedule association
          key_player_id: season.key_player_id,
          previous_game_date: previous_game_date,
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
        roster_updates = Array(params[:roster_updates])
        target_date = Date.parse(params[:target_date]) # Date for which the roster is being set
        season_start_date = season.season_schedules.minimum(:date) # Calculate season start date once

        duplicate_membership_ids = duplicate_roster_update_membership_ids(roster_updates)
        if duplicate_membership_ids.any?
          render json: { error: "Duplicate team_membership_id in roster_updates: #{duplicate_membership_ids.join(', ')}" }, status: :unprocessable_content
          return
        end

        is_commissioner = current_user.commissioner?
        commissioner_warnings = []

        ActiveRecord::Base.transaction do
          roster_state = roster_state_for(team, target_date)

          # Phase 1: Apply all squad changes (cooldown check only, no cost validation yet)
          roster_updates.each do |update|
            team_membership = team.team_memberships.find(update[:team_membership_id])
            new_squad = update[:squad]
            current_squad = roster_state.fetch(team_membership.id, team_membership.squad)

            if current_squad == "first" && new_squad == "second"
              team_membership.update!(squad: new_squad) if target_date == season.current_date
              SeasonRoster.create!(
                season: season,
                team_membership: team_membership,
                squad: new_squad,
                registered_on: target_date
              )
              roster_state[team_membership.id] = new_squad
            elsif current_squad == "second" && new_squad == "first"
              # Check reconditioning: block promotion for reconditioning players (even commissioners)
              absence = absence_info_for(team_membership, target_date)
              if absence[:is_absent] && absence[:absence_info][:absence_type] == "reconditioning"
                raise "#{team_membership.player.name}は再調整中のため1軍登録できません。"
              end

              # Check cooldown (per-player constraint, unaffected by batch order)
              # Same-day promotion+demotion is exempt from cooldown
              cooldown_info = calculate_cooldown_info(team_membership, target_date)
              if cooldown_info[:cooldown_until] && !cooldown_info[:same_day_exempt]
                raise "Player #{team_membership.player.name} is on cooldown until #{cooldown_info[:cooldown_until]}"
              end

              team_membership.update!(squad: new_squad) if target_date == season.current_date
              SeasonRoster.create!(
                season: season,
                team_membership: team_membership,
                squad: new_squad,
                registered_on: target_date
              )
              roster_state[team_membership.id] = new_squad
            end
          end

          # Phase 2: Validate final state of 1st squad after all changes
          final_first_squad = team.team_memberships.reload.select { |tm| roster_state.fetch(tm.id, tm.squad) == "first" }
          validate_first_squad_constraints(final_first_squad, target_date, season, season_start_date,
            commissioner_mode: is_commissioner, commissioner_warnings: commissioner_warnings)

          # Phase 3: Validate outside world constraints
          team.reload
          team.errors.clear
          unless team.validate_outside_world_limit(final_first_squad)
            msg = team.errors.full_messages.first
            if is_commissioner
              commissioner_warnings << msg
            else
              raise msg
            end
          end
          team.errors.clear
          unless team.validate_outside_world_balance(final_first_squad)
            msg = team.errors.full_messages.first
            if is_commissioner
              commissioner_warnings << msg
            else
              raise msg
            end
          end
        end

        # Collect warnings for absent players being promoted
        warnings = collect_absence_warnings(team, target_date, roster_updates)
        warnings.concat(commissioner_warnings.map { |msg| { type: "commissioner_override", message: msg } })

        render json: { message: "Roster updated successfully", warnings: warnings }, status: :ok
      rescue ActiveRecord::RecordNotFound => e
        render json: { error: e.message }, status: :not_found
      rescue => e
        render json: { error: e.message }, status: :unprocessable_content
      end

      private

      def duplicate_roster_update_membership_ids(roster_updates)
        membership_ids = roster_updates.map { |update| update[:team_membership_id].to_s.presence }.compact
        membership_ids.tally.select { |_id, count| count > 1 }.keys
      end

      def roster_state_for(team, date)
        team.team_memberships.each_with_object({}) do |tm, state|
          state[tm.id] = current_squad_for_membership(tm, date)
        end
      end

      def current_squad_for_membership(team_membership, date)
        latest_roster_entry = team_membership.season_rosters
                                                .where("registered_on <= ?", date)
                                                .order(registered_on: :desc, created_at: :desc)
                                                .first
        latest_roster_entry ? latest_roster_entry.squad : team_membership.squad
      end

      # Helper to get current squad for a given date
      def get_current_squad_for_date(team, squad_name, date)
        team.team_memberships.map do |tm|
          if current_squad_for_membership(tm, date) == squad_name
            tm
          else
            nil
          end
        end.compact
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
      def validate_first_squad_constraints(first_squad_memberships, target_date, season, season_start_date, commissioner_mode: false, commissioner_warnings: [])
        player_count = first_squad_memberships.count
        total_cost = first_squad_memberships.sum { |tm| membership_cost(tm, @current_cost_list) }

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
            msg = "試合日には1軍に最低#{minimum_players}人を登録する必要があります。"
            commissioner_mode ? (commissioner_warnings << msg) : raise(msg)
          end
        end

        if player_count > max_players
          msg = "1軍に登録できる選手の最大数（#{max_players}人）を超えています。"
          commissioner_mode ? (commissioner_warnings << msg) : raise(msg)
        end

        # 1軍コスト上限: 人数別段階制（config/cost_limits.yml）
        max_cost = Team.first_squad_cost_limit_for_count(player_count)
        if max_cost && total_cost > max_cost
          msg = "1軍に登録されている選手の合計コストが上限（#{max_cost}）を超えています。"
          commissioner_mode ? (commissioner_warnings << msg) : raise(msg)
        end
      end

      def membership_cost(team_membership, cost_list)
        team_membership.selected_cost_value(cost_list)
      end
    end
  end
end
