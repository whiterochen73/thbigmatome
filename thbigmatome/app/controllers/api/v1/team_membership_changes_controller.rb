module Api
  module V1
    # チーム編成の変更記録（登録・契約の変更・放出）の一覧（cmd_1784 段2）。試合日ページの「その日の登録・契約変更」などの表示用。
    # 書き込みは POST /teams/:team_id/team_players（TeamMembershipWriter）。
    class TeamMembershipChangesController < BaseController
      include TeamAccessible

      before_action :authorize_team_access!

      # GET /teams/:team_id/team_membership_changes?date=YYYY-MM-DD  または  ?from=YYYY-MM-DD&to=YYYY-MM-DD
      # date はその日の記録だけ。from / to は effective_on の範囲（どちらかだけでもよい）。省略すると全件。
      # 並びは時点順（effective_on, 試合前→試合中→試合後, 作成順）。
      def index
        team = Team.find(params[:team_id])
        scope = TeamMembershipChange.joins(:team_membership).where(team_memberships: { team_id: team.id })
                                    .includes(team_membership: :player)
        if params[:date].present?
          scope = scope.where(effective_on: Date.parse(params[:date]))
        else
          scope = scope.where(effective_on: Date.parse(params[:from])..) if params[:from].present?
          scope = scope.where(effective_on: ..Date.parse(params[:to])) if params[:to].present?
        end

        changes = scope.to_a.sort_by do |c|
          [ c.effective_on, SeasonRoster.phase_rank(c.phase), c.created_at, c.id ]
        end

        render json: changes.map { |c| serialize(c) }
      rescue Date::Error
        render json: { error: "Invalid date format" }, status: :bad_request
      end

      private

      def serialize(change)
        player = change.team_membership.player
        {
          id: change.id,
          team_membership_id: change.team_membership_id,
          player_id: player.id,
          player_name: player.name,
          number: player.number,
          kind: change.kind,
          effective_on: change.effective_on,
          phase: change.phase,
          selected_cost_type: change.selected_cost_type,
          player_card_id: change.player_card_id,
          excluded_from_team_total: change.excluded_from_team_total,
          display_name: change.display_name,
          recorded_by_user_id: change.recorded_by_user_id,
          created_at: change.created_at
        }
      end
    end
  end
end
