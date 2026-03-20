module Api
  module V1
    class PitcherGameStatesController < BaseController
      include TeamAccessible

      before_action :set_team
      before_action :authorize_team_access!

      # GET /teams/:team_id/pitcher_game_states?date=YYYY-MM-DD&player_ids[]=1&player_ids[]=2
      def index
        target_date = params[:date]&.to_date || Date.today
        player_ids = params[:player_ids]&.map(&:to_i)

        pitcher_ids = if player_ids.present?
          player_ids
        else
          @team.team_memberships
               .joins(:player)
               .where(players: { position: "pitcher" })
               .pluck(:player_id)
        end

        injured_ids = build_injured_set(pitcher_ids, target_date)

        result = pitcher_ids.map do |player_id|
          last_app = PitcherGameState
            .where(pitcher_id: player_id, team_id: @team.id)
            .where("schedule_date < ?", target_date.to_s)
            .order(schedule_date: :desc)
            .first

          rest_days = nil
          cumulative_innings = 0
          last_role = nil

          if last_app
            last_date = last_app.schedule_date.to_date
            rest_days = (target_date - last_date).to_i - 1
            last_role = last_app.role

            if %w[reliever opener].include?(last_role)
              cumulative_innings = compute_cumulative_innings(player_id, target_date)
            end
          end

          {
            player_id: player_id,
            rest_days: rest_days,
            cumulative_innings: cumulative_innings,
            last_role: last_role,
            is_injured: injured_ids.include?(player_id)
          }
        end

        render json: result
      end

      private

      def set_team
        @team = Team.find(params[:team_id])
      end

      def build_injured_set(pitcher_ids, target_date)
        PlayerAbsence
          .where(player_id: pitcher_ids, team_id: @team.id)
          .select { |pa|
            start = pa.start_date&.to_date
            end_d = pa.respond_to?(:effective_end_date) ? pa.effective_end_date&.to_date : pa.end_date&.to_date
            next false unless start && start <= target_date
            end_d.nil? || end_d >= target_date
          }
          .map(&:player_id)
          .to_set
      end

      def compute_cumulative_innings(pitcher_id, target_date)
        appearances = PitcherGameState
          .where(pitcher_id: pitcher_id, team_id: @team.id, role: %w[reliever opener])
          .where("schedule_date <= ?", target_date.to_s)
          .order(schedule_date: :asc)

        cumulative = 0
        prev_date = nil

        appearances.each do |app|
          if prev_date
            rest_days = (app.schedule_date.to_date - prev_date).to_i - 1
            rest_days.times do
              cumulative = cumulative <= 3 ? [ cumulative - 2, 0 ].max : cumulative - 1
            end
          end
          cumulative += 1
          prev_date = app.schedule_date.to_date
        end

        # Decay from last appearance to target_date
        if prev_date && prev_date < target_date
          idle_days = (target_date - prev_date).to_i - 1
          idle_days.times do
            cumulative = cumulative <= 3 ? [ cumulative - 2, 0 ].max : cumulative - 1
          end
        end

        [ cumulative, 0 ].max
      end
    end
  end
end
