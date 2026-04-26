class Api::V1::Commissioner::TeamManagersController < Api::V1::Commissioner::BaseController
  include DirectorSiblingCheck

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

    if @team_manager.director?
      begin
        check_director_sibling_overlap!(@team, @team_manager.manager_id)
      rescue DirectorSiblingCheck::OverlapError => e
        render json: { error: e.message }, status: :unprocessable_entity
        return
      end
    end

    if @team_manager.save
      render json: @team_manager, status: :created
    else
      render json: @team_manager.errors, status: :unprocessable_content
    end
  end

  def update
    new_role = team_manager_params[:role]&.to_s
    new_manager_id = team_manager_params[:manager_id]&.to_i

    effective_role = new_role.presence || @team_manager.role.to_s
    effective_manager_id = new_manager_id.presence || @team_manager.manager_id

    role_changing = new_role.present? && new_role != @team_manager.role.to_s
    manager_changing = new_manager_id.present? && new_manager_id != @team_manager.manager_id

    if effective_role == "director" && (role_changing || manager_changing)
      begin
        check_director_sibling_overlap!(@team, effective_manager_id)
      rescue DirectorSiblingCheck::OverlapError => e
        render json: { error: e.message }, status: :unprocessable_entity
        return
      end
    end

    if @team_manager.update(team_manager_params)
      render json: @team_manager
    else
      render json: @team_manager.errors, status: :unprocessable_content
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
