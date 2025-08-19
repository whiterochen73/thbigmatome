module Api
  module V1
    class TeamRostersController < ApplicationController
      def show
        team = Team.find(params[:team_id])
        season = team.season
        if season.nil?
          render json: { error: 'Season not initialized for this team' }, status: :not_found
          return
        end

        current_cost_list = Cost.current_cost

        # Get the date from params, default to season's current_date if not provided
        target_date = season.current_date

        # Fetch all team memberships for the team
        team_memberships = team.team_memberships.preload(:season_rosters, player: [:cost_players, :player_types])
        start_date = season.season_schedules.minimum(:date)

        # Determine current squad for each player based on the latest SeasonRoster entry
        roster_data = team_memberships.map do |tm|
          latest_roster_entry = tm.season_rosters
                                  .where('registered_on <= ?', target_date)
                                  .order(registered_on: :desc, created_at: :desc)
                                  .first

          squad_status = latest_roster_entry ? latest_roster_entry.squad : tm.squad # Fallback to default squad from team_membership

          {
            team_membership_id: tm.id,
            player_id: tm.player.id,
            number: tm.player.number,
            player_name: tm.player.short_name,
            throwing_hand: tm.player.throwing_hand,
            batting_hand: tm.player.batting_hand,
            squad: squad_status,
            position: tm.player.position, # Add player position
            player_types: tm.player.player_types.pluck([:name]), # Add player types
            selected_cost_type: tm.selected_cost_type, # Add selected cost type
            cost: tm.player.cost_players.find { |pc| pc.cost_id == current_cost_list.id }.send(tm.selected_cost_type), # Assuming player has cost methods
            # Add cooldown information if applicable
            cooldown_until: calculate_cooldown(tm, target_date)
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
        render json: { error: 'Team or Season not found' }, status: :not_found
      rescue ArgumentError
        render json: { error: 'Invalid date format' }, status: :bad_request
      end

      def create
        team = Team.find(params[:team_id])
        season = team.season
        if season.nil?
          render json: { error: 'Season not initialized for this team' }, status: :bad_request
          return
        end

        @current_cost_list = Cost.current_cost

        # Expects an array of { team_membership_id: id, squad: 'first' | 'second' }
        roster_updates = params[:roster_updates]
        target_date = Date.parse(params[:target_date]) # Date for which the roster is being set
        season_start_date = season.season_schedules.minimum(:date) # Calculate season start date once

        ActiveRecord::Base.transaction do
          roster_updates.each do |update|
            team_membership = team.team_memberships.find(update[:team_membership_id])
            new_squad = update[:squad]

            # Apply business rules
            # Rule 3: 1st -> 2nd always possible. 2nd -> 1st has cooldown.
            if team_membership.squad == 'first' && new_squad == 'second'
              # Player moved from first to second, record cooldown start
              # This cooldown logic needs to be stored somewhere, maybe on SeasonRoster or TeamMembership
              # For now, just update the squad
              team_membership.update!(squad: new_squad)
              SeasonRoster.create!(
                season: season,
                team_membership: team_membership,
                squad: new_squad,
                registered_on: target_date
              )
            elsif team_membership.squad == 'second' && new_squad == 'first'
              # Check cooldown
              cooldown_until = calculate_cooldown(team_membership, target_date)
              if cooldown_until && target_date < cooldown_until
                raise "Player #{team_membership.player.name} is on cooldown until #{cooldown_until.to_s}"
              end

              # Check 1st team constraints (max players, max cost)
              # This requires getting the current first squad for the target_date
              current_first_squad_memberships = get_current_squad_for_date(team, 'first', target_date)

              # Add the player to the list for validation
              proposed_first_squad_memberships = current_first_squad_memberships + [team_membership]

              validate_first_squad_constraints(proposed_first_squad_memberships, target_date, season, season_start_date)

              team_membership.update!(squad: new_squad)
              SeasonRoster.create!(
                season: season,
                team_membership: team_membership,
                squad: new_squad,
                registered_on: target_date
              )
            end
          end
        end

        render json: { message: 'Roster updated successfully' }, status: :ok
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
                                  .where('registered_on <= ?', date)
                                  .order(registered_on: :desc, created_at: :desc)
                                  .first
          if latest_roster_entry && latest_roster_entry.squad == squad_name
            tm
          else
            nil
          end
        end.compact
      end

      # Rule 3: Cooldown calculation
      def calculate_cooldown(team_membership, current_date)
        last_moved_from_first_to_second = team_membership.season_rosters
                                            .where(squad: 'second') # Moved to second
                                            .order(registered_on: :desc, created_at: :desc)
                                            .first

        if last_moved_from_first_to_second
          # Check if the player was previously in first squad before moving to second
          previous_entry = team_membership.season_rosters
                                .where('registered_on < ?', last_moved_from_first_to_second.registered_on)
                                .order(registered_on: :desc, created_at: :desc)
                                .first
          if previous_entry && previous_entry.squad == 'first'
            cooldown_end_date = last_moved_from_first_to_second.registered_on + 10.days
            return cooldown_end_date if current_date < cooldown_end_date
          end
        end
        nil
      end

      # Rule 4 & 5: Validate 1st team constraints
      def validate_first_squad_constraints(first_squad_memberships, target_date, season, season_start_date)
        player_count = first_squad_memberships.count
        total_cost = first_squad_memberships.sum { |tm| tm.player.cost_players.find { |pc| pc.cost_id == @current_cost_list.id }.send(tm.selected_cost_type) } # Assuming player has cost methods

        max_players = 29
        max_cost = 120

        # Check if target_date is a game day
        is_game_day = season.season_schedules.exists?(date: target_date, date_type: 'game_day')

        # Check if it's the very first day of the season AND it's a game day
        is_first_game_day_of_season = is_game_day && (target_date == season_start_date)

        if is_game_day
          # Special rules for game day
          Rails.logger.debug(player_count)
          # If it's the first game day of the season, and we are in the process of initial registration (player_count < 25),
          # we should allow it to proceed until max_players (29) is reached.
          # This assumes that the user is trying to register a full squad on the first game day.
          if is_first_game_day_of_season && player_count < 25
            # Do not raise error for minimum player count on the first game day during initial setup
            # We will still enforce max_players and max_cost
          elsif player_count < 25
            raise "試合日には1軍に最低25人を登録する必要があります。"
          end

          max_cost = case player_count
                     when 25 then 114
                     when 26 then 117
                     when 27 then 119
                     else         120 # For 28, 29 players
                     end
        end

        if player_count > max_players
          raise "1軍に登録できる選手の最大数（#{max_players}人）を超えています。"
        end

        if total_cost > max_cost
          raise "1軍に登録されている選手の合計コストが上限（#{max_cost}）を超えています。"
        end
      end
    end
  end
end
