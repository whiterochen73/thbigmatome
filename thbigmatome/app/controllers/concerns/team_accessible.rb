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
    return if current_user.commissioner?
    return if team.user_id == current_user.id

    # Manager.user_id（文字列）でユーザーとマネージャーを紐付け、
    # このチームのdirector/coachであればアクセスを許可する
    manager = Manager.find_by(user_id: current_user.id.to_s)
    return if manager && team.team_managers.exists?(manager_id: manager.id)

    render json: { errors: [ "Forbidden" ] }, status: :forbidden
  end
end
