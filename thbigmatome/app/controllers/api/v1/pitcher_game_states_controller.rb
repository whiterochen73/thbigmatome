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

      # GET /teams/:team_id/pitcher_game_states/fatigue_summary
      def fatigue_summary
        target_date = params[:date]&.to_date || Date.today

        pitcher_memberships = @team.team_memberships
          .joins(player: :player_cards)
          .where(squad: "first")
          .where(player_cards: { card_type: "pitcher" })
          .select("team_memberships.player_id, players.name AS player_name")
          .distinct

        pitcher_ids = pitcher_memberships.map(&:player_id)
        name_map = pitcher_memberships.each_with_object({}) { |tm, h| h[tm.player_id] = tm.player_name }

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
          last_result_category = nil
          consecutive_short_rest_count = 0

          if last_app
            last_date = last_app.schedule_date.to_date
            rest_days = (target_date - last_date).to_i - 1
            last_role = last_app.role
            last_result_category = last_app.result_category
            consecutive_short_rest_count = last_app.consecutive_short_rest_count || 0

            if %w[reliever opener].include?(last_role)
              cumulative_innings = compute_cumulative_innings(player_id, target_date)
            end
          end

          is_injured = injured_ids.include?(player_id)
          is_unavailable = !is_injured && last_role == "starter" && rest_days != nil && rest_days <= 2

          projected = calculate_projected_status(
            last_role, rest_days, last_result_category,
            cumulative_innings, is_injured, consecutive_short_rest_count
          )

          {
            player_id: player_id,
            player_name: name_map[player_id],
            last_role: last_role,
            rest_days: last_role == "starter" ? rest_days : nil,
            cumulative_innings: %w[reliever opener].include?(last_role) ? cumulative_innings : nil,
            last_result_category: last_result_category,
            is_injured: is_injured,
            is_unavailable: is_unavailable,
            projected_status: projected
          }
        end

        render json: result
      end

      private

      def set_team
        @team = Team.find(params[:team_id])
      end

      def build_injured_set(pitcher_ids, target_date)
        tm_map = @team.team_memberships
          .where(player_id: pitcher_ids)
          .each_with_object({}) { |tm, h| h[tm.id] = tm.player_id }

        return Set.new if tm_map.empty?

        PlayerAbsence
          .where(team_membership_id: tm_map.keys)
          .select { |pa|
            start = pa.start_date&.to_date
            end_d = pa.respond_to?(:effective_end_date) ? pa.effective_end_date&.to_date : pa.end_date&.to_date
            next false unless start && start <= target_date
            end_d.nil? || end_d >= target_date
          }
          .map { |pa| tm_map[pa.team_membership_id] }
          .compact
          .to_set
      end

      # projected_status: 今日登板した場合の疲労ステータス予測
      # 戻り値: "full" / "reduced_N" / "injury_check" / "unavailable" / "injured"
      def calculate_projected_status(last_role, rest_days, last_result_category, cumulative_innings, is_injured, consecutive_short_rest_count)
        return "injured" if is_injured
        return "full" if last_role.nil?

        if last_role == "starter"
          return "full" if rest_days.nil?
          return "unavailable" if rest_days <= 2

          cat = last_result_category || "normal"
          case cat
          when "ko", "no_game"
            rest_days == 3 ? "reduced_3" : "full"
          when "long_loss"
            case rest_days
            when 3 then "injury_check"
            when 4 then "reduced_4"
            when 5 then "reduced_2"
            when 6 then "reduced_1"
            else "full"
            end
          else # normal
            case rest_days
            when 3 then "injury_check"
            when 4
              consecutive_short_rest_count >= 1 ? "injury_check" : "reduced_3"
            when 5 then "reduced_1"
            else "full"
            end
          end
        else # reliever / opener
          case cumulative_innings
          when 0 then "full"
          when 1 then "reduced_0"
          when 2 then "reduced_0"
          else "injury_check"
          end
        end
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
