class Api::V1::Commissioner::LeagueMembershipsController < Api::V1::Commissioner::BaseController
  before_action :set_league

  def index
    league_memberships = @league.league_memberships.includes(:team)
    render json: league_memberships, include: :team
  end

  def create
    league_membership = @league.league_memberships.build(league_membership_params)

    if league_membership.save
      render json: league_membership, status: :created
    else
      render json: league_membership.errors, status: :unprocessable_entity
    end
  end

  def destroy
    league_membership = @league.league_memberships.find(params[:id])
    if league_membership.destroy
      head :no_content
    else
      render json: league_membership.errors, status: :unprocessable_entity
    end
  end

  private

  def set_league
    @league = League.find(params[:league_id])
  end

  def league_membership_params
    params.require(:league_membership).permit(:team_id)
  end
end
