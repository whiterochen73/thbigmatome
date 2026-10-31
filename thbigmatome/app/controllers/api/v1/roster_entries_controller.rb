module Api
  module V1
    # 昇降格の変更記録（season_rosters）の取り消し（cmd_1784 段1）。
    # 消したあと、その時点以降の人数・コスト・外の世界枠・クールダウンを検査し直す（RosterWriter#destroy!）。
    # コミッショナー以外は、違反が生じる削除を止めて違反した日付を返す。コミッショナーは警告つきで消す。
    class RosterEntriesController < BaseController
      include TeamAccessible

      before_action :authorize_team_access!

      # DELETE /teams/:team_id/roster_entries/:id
      def destroy
        team = Team.find(params[:team_id])
        entry = SeasonRoster.joins(:team_membership).where(team_memberships: { team_id: team.id }).find(params[:id])

        writer = RosterWriter.new(team: team, user: current_user, commissioner: current_user.commissioner?)
        result = writer.destroy!(entry)

        render json: { message: "Roster entry deleted successfully", warnings: result.warnings }, status: :ok
      rescue ActiveRecord::RecordNotFound => e
        render json: { error: e.message }, status: :not_found
      rescue RosterWriter::Rejected => e
        render json: { error: e.message, violations: e.violations.map(&:to_h) }, status: :unprocessable_content
      end
    end
  end
end
