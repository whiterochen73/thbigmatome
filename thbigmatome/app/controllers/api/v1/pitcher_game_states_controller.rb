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
          # 投手能力を持つカード（can_pitchスコープ）かつ野手専念契約でない選手のみ投手として扱う（#5 #6）
          @team.team_memberships
               .where.not(selected_cost_type: "fielder_only_cost")
               .joins(:player_card)
               .merge(PlayerCard.can_pitch)
               .distinct
               .pluck(:player_id)
        end

        injured_ids = build_injured_set(pitcher_ids, target_date)
        absence_map = preload_pitcher_absences(pitcher_ids)

        result = pitcher_ids.map do |player_id|
          last_app = PitcherGameState
            .where(pitcher_id: player_id, team_id: @team.id)
            .where("schedule_date < ?", target_date.to_s)
            .order(schedule_date: :desc)
            .first

          rest_days = nil
          cumulative_innings = 0
          last_role = nil
          absences = absence_map[player_id] || []

          if last_app
            last_date = last_app.schedule_date.to_date
            last_role = last_app.role

            if full_recovery_absence?(absences, last_date, target_date)
              rest_days = nil
            else
              raw_rest_days = (target_date - last_date).to_i - 1
              absent_days = absence_days_in_range(absences, last_date + 1, target_date - 1)
              rest_days = raw_rest_days - absent_days
            end

            if %w[reliever opener].include?(last_role)
              cumulative_innings = compute_cumulative_innings(player_id, target_date, absences)
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

        # season_rostersベースでtarget_date時点の1軍メンバーを取得（現在のsquadではなく登録履歴で判定）
        # 投手能力を持つカード（can_pitchスコープ）かつ野手専念契約でない選手のみ（#5 #6）
        all_pitcher_memberships = @team.team_memberships
          .where.not(selected_cost_type: "fielder_only_cost")
          .joins(:player_card)
          .merge(PlayerCard.can_pitch)
          .includes(:player)
          .distinct

        pitcher_memberships = all_pitcher_memberships.select do |tm|
          latest_roster = tm.season_rosters
                            .where("registered_on <= ?", target_date)
                            .order(registered_on: :desc, created_at: :desc)
                            .first
          latest_roster && latest_roster.squad == "first"
        end

        pitcher_ids = pitcher_memberships.map(&:player_id)
        name_map = pitcher_memberships.each_with_object({}) { |tm, h| h[tm.player_id] = tm.player.name }

        injured_ids = build_injured_set(pitcher_ids, target_date)
        absence_map = preload_pitcher_absences(pitcher_ids)

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
          absences = absence_map[player_id] || []

          if last_app
            last_date = last_app.schedule_date.to_date
            last_role = last_app.role
            last_result_category = last_app.result_category
            consecutive_short_rest_count = last_app.consecutive_short_rest_count || 0

            if full_recovery_absence?(absences, last_date, target_date)
              rest_days = nil
            else
              raw_rest_days = (target_date - last_date).to_i - 1
              absent_days = absence_days_in_range(absences, last_date + 1, target_date - 1)
              rest_days = raw_rest_days - absent_days
            end

            if %w[reliever opener].include?(last_role)
              cumulative_innings = compute_cumulative_innings(player_id, target_date, absences)
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
            end_d.nil? || end_d > target_date
          }
          .map { |pa| tm_map[pa.team_membership_id] }
          .compact
          .to_set
      end

      # 複数投手の離脱期間を一括取得
      # 戻り値: { player_id => [{start_date:, end_date:}, ...] }
      # end_date は復帰可能日（排他的）。nil は無期限離脱。
      def preload_pitcher_absences(pitcher_ids)
        tm_map = @team.team_memberships
          .where(player_id: pitcher_ids)
          .each_with_object({}) { |tm, h| h[tm.id] = tm.player_id }

        return {} if tm_map.empty?

        result = {}
        PlayerAbsence.where(team_membership_id: tm_map.keys).each do |pa|
          player_id = tm_map[pa.team_membership_id]
          next unless player_id
          result[player_id] ||= []
          result[player_id] << { start_date: pa.start_date.to_date, end_date: pa.effective_end_date&.to_date }
        end
        result
      end

      def absence_days_in_range(absences, from_date, to_date)
        PitcherRestStatus.absence_days_in_range(absences, from_date, to_date)
      end

      def full_recovery_absence?(absences, after_date, target_date)
        PitcherRestStatus.full_recovery_absence?(absences, after_date, target_date)
      end

      # 判定表は PitcherRestStatus に集約（先発の試合前疲労P計算と共有）
      def calculate_projected_status(*args)
        PitcherRestStatus.calculate_projected_status(*args)
      end

      def compute_cumulative_innings(pitcher_id, target_date, absences = [])
        PitcherRestStatus.cumulative_innings(@team.id, pitcher_id, target_date, absences)
      end
    end
  end
end
