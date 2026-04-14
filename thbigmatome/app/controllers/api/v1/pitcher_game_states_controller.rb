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
          # 登録カードが投手カードかつ野手専念契約でない選手のみ投手として扱う（#5 #6）
          @team.team_memberships
               .where.not(selected_cost_type: "fielder_only_cost")
               .joins(:player_card)
               .where(player_cards: { is_pitcher: true })
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
        # is_pitcher=trueの選手（野手カードでも投手能力持ちを含む）かつ野手専念契約でない選手のみ（#5 #6）
        all_pitcher_memberships = @team.team_memberships
          .where.not(selected_cost_type: "fielder_only_cost")
          .joins(:player_card)
          .where(player_cards: { is_pitcher: true })
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
            end_d.nil? || end_d >= target_date
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

      # [from_date, to_date] (両端含む) 内の離脱日数合計を返す
      # end_date は排他的（復帰可能日）
      def absence_days_in_range(absences, from_date, to_date)
        return 0 if absences.empty? || from_date > to_date
        absences.sum do |pa|
          i_start = [ pa[:start_date], from_date ].max
          i_end_excl = pa[:end_date] ? pa[:end_date] : to_date + 1
          i_end_clamped = [ i_end_excl, to_date + 1 ].min
          days = (i_end_clamped - i_start).to_i
          days > 0 ? days : 0
        end
      end

      # after_date より後に開始し、target_date 以前に終了する、
      # 10日を超える（> 10日）の離脱があるか（中10日全快判定）
      def full_recovery_absence?(absences, after_date, target_date)
        absences.any? do |pa|
          pa[:start_date] > after_date &&
            pa[:end_date] &&
            pa[:end_date] <= target_date &&
            (pa[:end_date] - pa[:start_date]).to_i > 10
        end
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

      def compute_cumulative_innings(pitcher_id, target_date, absences = [])
        appearances = PitcherGameState
          .where(pitcher_id: pitcher_id, team_id: @team.id, role: %w[reliever opener])
          .where("schedule_date < ?", target_date.to_s)
          .order(schedule_date: :asc)

        cumulative = 0
        prev_date = nil

        appearances.each do |app|
          if prev_date
            app_date = app.schedule_date.to_date
            if full_recovery_absence?(absences, prev_date, app_date)
              # 中10日以上の離脱 → 全快（累積リセット）
              cumulative = 0
            else
              from = prev_date + 1
              to = app_date - 1
              idle_days = (app_date - prev_date).to_i - 1
              absent_days = absence_days_in_range(absences, from, to)
              effective_idle = [ idle_days - absent_days, 0 ].max
              effective_idle.times do
                cumulative = cumulative <= 3 ? [ cumulative - 2, 0 ].max : cumulative - 1
              end
            end
          end
          ip = app.innings_pitched.to_f
          my_outs = ip.floor * 3 + ((ip * 10).round % 10)
          prior_outs = PitcherGameState
            .where(game_id: app.game_id, team_id: app.team_id)
            .where("appearance_order < ?", app.appearance_order)
            .pluck(:innings_pitched)
            .sum { |s| s.to_f.then { |f| f.floor * 3 + ((f * 10).round % 10) } }
          involvement = if my_outs == 0
            1
          else
            start_inning = prior_outs / 3 + 1
            end_inning = (prior_outs + my_outs - 1) / 3 + 1
            (end_inning - start_inning + 1) + (app.no_out_exit ? 1 : 0)
          end
          cumulative += [ involvement, 1 ].max
          prev_date = app.schedule_date.to_date
        end

        # Decay from last appearance to target_date
        if prev_date && prev_date < target_date
          if full_recovery_absence?(absences, prev_date, target_date)
            cumulative = 0
          else
            from = prev_date + 1
            to = target_date - 1
            idle_days = (target_date - prev_date).to_i - 1
            absent_days = absence_days_in_range(absences, from, to)
            effective_idle = [ idle_days - absent_days, 0 ].max
            effective_idle.times do
              cumulative = cumulative <= 3 ? [ cumulative - 2, 0 ].max : cumulative - 1
            end
          end
        end

        [ cumulative, 0 ].max
      end
    end
  end
end
