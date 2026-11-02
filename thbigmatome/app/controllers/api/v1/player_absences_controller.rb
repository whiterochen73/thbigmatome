module Api
  module V1
    class PlayerAbsencesController < Api::V1::BaseController
      before_action :set_player_absence, only: [ :update, :destroy ]

      # GET /api/v1/player_absences
      def index
        if params[:season_id].present?
          @player_absences = PlayerAbsence.where(season_id: params[:season_id]).includes(team_membership: :player)
        elsif params[:team_id].present?
          team = Team.find(params[:team_id])
          season = team.season
          if season.nil?
            render json: { error: "team has no season" }, status: :unprocessable_entity
            return
          end
          @player_absences = PlayerAbsence
            .where(season_id: season.id)
            .joins(team_membership: :team)
            .where(team_memberships: { team_id: team.id })
            .includes(team_membership: :player)
        else
          render json: { error: "season_id or team_id is required" }, status: :bad_request
          return
        end

        render json: @player_absences
      end

      # POST /api/v1/player_absences
      def create
        @player_absence = PlayerAbsence.new(player_absence_params)

        if @player_absence.save
          warnings = rebuild_pitcher_history([ [ @player_absence.team_membership_id, @player_absence.start_date ] ])
          render json: with_warnings(@player_absence, warnings), status: :created
        else
          render json: @player_absence.errors, status: :unprocessable_content
        end
      end

      # PATCH/PUT /api/v1/player_absences/:id
      def update
        before = [ @player_absence.team_membership_id, @player_absence.start_date ]
        if @player_absence.update(player_absence_params)
          # 開始日や選手を変えた時は、変更前の開始日からも作り直す（早い方から）
          warnings = rebuild_pitcher_history([ before, [ @player_absence.team_membership_id, @player_absence.start_date ] ])
          render json: with_warnings(@player_absence, warnings)
        else
          render json: @player_absence.errors, status: :unprocessable_content
        end
      end

      # DELETE /api/v1/player_absences/:id
      def destroy
        @player_absence.destroy
        rebuild_pitcher_history([ [ @player_absence.team_membership_id, @player_absence.start_date ] ])
        head :no_content
      end

      private

      # 離脱の作成・変更・削除で、その選手の登板の保存値（疲労P・連続中4日回数ほか）を、離脱の開始日（変更前の開始日の早い方）から作り直す
      # （PitcherHistoryRebuild。設計書 §4.5）。野手など登板の無い選手では何も動かない。失敗しても離脱の保存は取り消さず、警告にする。
      # changes: [[team_membership_id, 開始日], ...]
      def rebuild_pitcher_history(changes)
        warnings = []
        changes.group_by(&:first).each do |membership_id, rows|
          membership = TeamMembership.find_by(id: membership_id)
          next if membership.nil?

          outcome = PitcherHistoryRebuild.guarded(team_id: membership.team_id, date: rows.map(&:last).min, pitcher_ids: [ membership.player_id ])
          warnings << PitcherHistoryRebuild.failure_message(outcome.error) unless outcome.ok?
        end
        warnings
      end

      # 作り直しが失敗した時だけ warnings を足す（普段の応答の形は変えない）
      def with_warnings(absence, warnings)
        warnings.empty? ? absence : absence.as_json.merge("warnings" => warnings)
      end

      def set_player_absence
        @player_absence = PlayerAbsence.find(params[:id])
      end

      def player_absence_params
        params.require(:player_absence).permit(
          :team_membership_id,
          :season_id,
          :absence_type,
          :reason,
          :start_date,
          :duration,
          :duration_unit,
          :phase
        )
      end
    end
  end
end
