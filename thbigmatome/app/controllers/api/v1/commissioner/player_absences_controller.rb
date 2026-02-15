class Api::V1::Commissioner::PlayerAbsencesController < Api::V1::Commissioner::BaseController
  before_action :set_team_membership
  before_action :set_player_absence, only: [ :show, :update, :destroy ]

  def index
    @player_absences = @team_membership.player_absences
    render json: @player_absences
  end

  def show
    render json: @player_absence
  end

  def create
    @player_absence = @team_membership.player_absences.build(player_absence_params)

    if @player_absence.save
      render json: @player_absence, status: :created
    else
      render json: @player_absence.errors, status: :unprocessable_entity
    end
  end

  def update
    if @player_absence.update(player_absence_params)
      render json: @player_absence
    else
      render json: @player_absence.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @player_absence.destroy
    head :no_content
  end

  private

  def set_team_membership
    @team_membership = TeamMembership.find(params[:team_membership_id])
  end

  def set_player_absence
    @player_absence = @team_membership.player_absences.find(params[:id])
  end

  def player_absence_params
    params.require(:player_absence).permit(:season_id, :absence_type, :start_date, :duration, :duration_unit)
  end
end
