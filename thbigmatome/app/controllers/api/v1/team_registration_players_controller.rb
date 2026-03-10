class Api::V1::TeamRegistrationPlayersController < Api::V1::BaseController
  def index
    # cost_list_idによるフィルタリングはフロントエンドで行うため、ここではすべての選手を返す
    players = Player.eager_load(:cost_players, player_cards: :player_card_defenses).all
    render json: players, each_serializer: PlayerSerializer
  end
end
