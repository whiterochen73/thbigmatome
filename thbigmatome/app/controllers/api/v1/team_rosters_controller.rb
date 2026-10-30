module Api
  module V1
    class TeamRostersController < Api::V1::BaseController
      include TeamAccessible
      before_action :authorize_team_access!

      # GET /teams/:team_id/roster?target_date=YYYY-MM-DD&phase=pre_game|in_game|post_game
      # 省略時は現在日カーソル・pre_game。1軍/2軍は昇降格の変更記録から導く（RosterState。記録が無い選手は 2軍）
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
        phase = RosterState.parse_phase(params[:phase])

        # Fetch all team memberships for the team
        team_memberships = team.team_memberships.preload(:season_rosters, :player_absences, player: [ :cost_players ], player_card: [ :card_set, :player_card_defenses ])
        start_date = season.season_schedules.minimum(:date)

        state = RosterState.new(team, memberships: team_memberships.to_a)
        entries = state.at(target_date, phase)

        native_series = Team::NATIVE_SERIES[team.team_type] || Team::NATIVE_SERIES["normal"]
        roster_data = state.memberships.map do |tm|
          entry = entries.fetch(tm.id)

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
            squad: entry.squad,
            player_types: [],
            selected_cost_type: tm.selected_cost_type,
            cost: membership_cost(tm, current_cost_list),
            cooldown_until: entry.cooldown_until,
            same_day_exempt: entry.same_day_exempt,
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
      rescue Date::Error
        render json: { error: "Invalid date format" }, status: :bad_request
      rescue ArgumentError => e
        render json: { error: e.message.start_with?("invalid phase") ? "Invalid phase" : "Invalid date format" }, status: :bad_request
      end

      # POST /teams/:team_id/roster
      # params: roster_updates: [{ team_membership_id:, squad: "first"|"second" }], target_date（省略時は現在日カーソル）, phase（省略時は pre_game）
      # 昇降格の変更記録を足し、その時点以降の各時点を検査し直す（RosterWriter）。写し（team_memberships.squad）は毎回作り直す。
      def create
        team = Team.find(params[:team_id])
        season = team.season
        if season.nil?
          render json: { error: "Season not initialized for this team" }, status: :bad_request
          return
        end

        target_date = params[:target_date].present? ? Date.parse(params[:target_date]) : season.current_date
        phase = RosterState.parse_phase(params[:phase])

        writer = RosterWriter.new(team: team, user: current_user, commissioner: current_user.commissioner?)
        result = writer.update!(params[:roster_updates], date: target_date, phase: phase)

        # Collect warnings for absent players being promoted
        warnings = collect_absence_warnings(team, target_date, Array(params[:roster_updates]))
        warnings.concat(result.warnings)

        render json: { message: "Roster updated successfully", warnings: warnings }, status: :ok
      rescue ActiveRecord::RecordNotFound => e
        render json: { error: e.message }, status: :not_found
      rescue RosterWriter::Rejected => e
        render json: { error: e.message, violations: e.violations.map(&:to_h) }, status: :unprocessable_content
      rescue => e
        render json: { error: e.message }, status: :unprocessable_content
      end

      private

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

      def membership_cost(team_membership, cost_list)
        team_membership.selected_cost_value(cost_list)
      end
    end
  end
end
