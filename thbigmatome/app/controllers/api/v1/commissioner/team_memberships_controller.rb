class Api::V1::Commissioner::TeamMembershipsController < ApplicationController
  before_action :set_team
  before_action :set_team_membership, only: [:show, :update, :destroy]

  def index
    @team_memberships = @team.team_memberships.includes(:player)
    render json: @team_memberships
  end

  def show
    render json: @team_membership
  end

  def update
    if @team_membership.update(team_membership_params)
      render json: @team_membership
    else
      render json: @team_membership.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @team_membership.destroy
    head :no_content
  end

  private

  def set_team
    @team = Team.find(params[:team_id])
  end

  def set_team_membership
    @team_membership = @team.team_memberships.find(params[:id])
  end

  def team_membership_params
    params.require(:team_membership).permit(:squad, :selected_cost_type)
  end
end
