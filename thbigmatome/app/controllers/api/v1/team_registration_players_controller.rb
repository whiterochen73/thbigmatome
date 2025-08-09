class Api::V1::TeamRegistrationPlayersController < ApplicationController
  def index
    # cost_list_idによるフィルタリングはフロントエンドで行うため、ここではすべての選手を返す
    players = Player.eager_load(:cost_players, :player_player_types).all
    render json: players, each_serializer: PlayerSerializer
  end
end