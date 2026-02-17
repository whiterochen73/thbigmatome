module Api
  module V1
    class PlayerAbsencesController < Api::V1::BaseController
      before_action :set_player_absence, only: [ :update, :destroy ]

      # GET /api/v1/player_absences
      def index
        if params[:season_id].blank?
          render json: { error: "season_id is required" }, status: :bad_request
          return
        end

        @player_absences = PlayerAbsence.where(season_id: params[:season_id]).includes(team_membership: :player)
        render json: @player_absences
      end

      # POST /api/v1/player_absences
      def create
        @player_absence = PlayerAbsence.new(player_absence_params)

        if @player_absence.save
          render json: @player_absence, status: :created
        else
          render json: @player_absence.errors, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/player_absences/:id
      def update
        if @player_absence.update(player_absence_params)
          render json: @player_absence
        else
          render json: @player_absence.errors, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/player_absences/:id
      def destroy
        @player_absence.destroy
        head :no_content
      end

      private

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
          :duration_unit
        )
      end
    end
  end
end
