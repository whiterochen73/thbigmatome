module Api
  module V1
    class CompetitionRostersController < Api::V1::BaseController
      before_action :set_competition_entry

      def index
        first_squad = roster_players(@competition_entry.competition_rosters.first_squad)
        second_squad = roster_players(@competition_entry.competition_rosters.second_squad)

        render json: { first_squad: first_squad, second_squad: second_squad }, status: :ok
      end

      def add_player
        player_card = PlayerCard.find(params[:player_card_id])
        squad = params[:squad]

        # 既存チェック
        existing = @competition_entry.competition_rosters.find_by(player_card_id: player_card.id)
        if existing
          render json: { errors: [ "この選手カードは既にロスターに追加されています" ] }, status: :unprocessable_entity
          return
        end

        roster = @competition_entry.competition_rosters.build(
          player_card: player_card,
          squad: squad
        )

        unless roster.valid?
          render json: { errors: roster.errors.full_messages }, status: :unprocessable_entity
          return
        end

        # 仮保存してコスト検証
        begin
          roster.save!
        rescue ActiveRecord::RecordNotUnique
          render json: { error: "選手は既にロスターに登録されています" }, status: :unprocessable_entity
          return
        end

        validation = CostValidator.new(@competition_entry.id).validate

        unless validation[:valid]
          roster.destroy
          render json: { errors: validation[:errors] }, status: :unprocessable_entity
          return
        end

        render json: roster_player_json(roster), status: :created
      end

      def remove_player
        roster = @competition_entry.competition_rosters.find_by!(player_card_id: params[:player_card_id])
        roster.destroy
        head :no_content
      end

      def cost_check
        result = CostValidator.new(@competition_entry.id).validate
        render json: result, status: :ok
      end

      private

      def set_competition_entry
        @competition_entry = CompetitionEntry.find_by!(
          competition_id: params[:competition_id],
          team_id: params[:team_id]
        )
        unless current_user_owns_team?(@competition_entry.team_id)
          render json: { error: "Forbidden" }, status: :forbidden
          nil
        end
      rescue ActiveRecord::RecordNotFound
        render json: { errors: [ "大会エントリーが見つかりません" ] }, status: :not_found
      end

      def current_user_owns_team?(team_id)
        current_user.commissioner?
      end

      def roster_players(rosters)
        rosters.includes(player_card: { player: :cost_players }).map do |r|
          roster_player_json(r)
        end
      end

      def roster_player_json(roster)
        pc = roster.player_card
        {
          player_card_id: pc.id,
          player_name: pc.player.short_name,
          squad: roster.squad,
          is_reliever: pc.is_relief_only,
          cost: player_cost(pc)
        }
      end

      def player_cost(player_card)
        current_cost = Cost.current_cost
        return 0 unless current_cost

        cost_player = player_card.player.cost_players.find { |cp| cp.cost_id == current_cost.id }
        return 0 unless cost_player

        if player_card.is_relief_only
          cost_player.relief_only_cost || cost_player.normal_cost || 0
        elsif player_card.is_pitcher
          cost_player.pitcher_only_cost || cost_player.normal_cost || 0
        else
          cost_player.fielder_only_cost || cost_player.normal_cost || 0
        end
      end
    end
  end
end
