class Api::V1::PlayersController < Api::V1::BaseController
  def index
    players = Player.all.order(:id)
    render json: players, each_serializer: PlayerDetailSerializer
  end

  def show
    player = Player.includes(player_cards: :card_set).find(params[:id])
    render json: player, serializer: PlayerDetailSerializer
  end

  def create
    player = Player.new(player_params)
    if player.save
      render json: player, status: :created
    else
      render json: { errors: player.errors.full_messages }, status: :unprocessable_content
    end
  end

  def update
    player = Player.find(params[:id])
    if player.update(player_params)
      render json: player
    else
      render json: { errors: player.errors.full_messages }, status: :unprocessable_content
    end
  end

  def destroy
    player = Player.find(params[:id])
    player.destroy
    head :no_content
  end

  private

  def player_params
    params.require(:player).permit(
      :name, :number, :short_name
    )
  end
end
