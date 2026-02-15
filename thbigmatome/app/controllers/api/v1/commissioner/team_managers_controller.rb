class Api::V1::Commissioner::TeamManagersController < Api::V1::Commissioner::BaseController
  before_action :set_team
  before_action :set_team_manager, only: [ :show, :update, :destroy ]

  def index
    @team_managers = @team.team_managers.includes(:manager)
    render json: @team_managers
  end

  def show
    render json: @team_manager
  end

  def create
    @team_manager = @team.team_managers.build(team_manager_params)

    if @team_manager.save
      render json: @team_manager, status: :created
    else
      render json: @team_manager.errors, status: :unprocessable_entity
    end
  end

  def update
    if @team_manager.update(team_manager_params)
      render json: @team_manager
    else
      render json: @team_manager.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @team_manager.destroy
    head :no_content
  end

  private

  def set_team
    @team = Team.find(params[:team_id])
  end

  def set_team_manager
    @team_manager = @team.team_managers.find(params[:id])
  end

  def team_manager_params
    params.require(:team_manager).permit(:manager_id, :role)
  end
end
