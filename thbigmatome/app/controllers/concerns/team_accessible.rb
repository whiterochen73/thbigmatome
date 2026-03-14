module TeamAccessible
  extend ActiveSupport::Concern

  private

  def authorize_team_access!
    team_id = params[:team_id].presence || params[:id]
    team = Team.find_by(id: team_id)
    unless team
      render json: { errors: [ "Team not found" ] }, status: :not_found
      return
    end
    unless current_user.commissioner? || team.user_id == current_user.id
      render json: { errors: [ "Forbidden" ] }, status: :forbidden
    end
  end
end
