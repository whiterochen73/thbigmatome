class Api::V1::PlayerCardsController < Api::V1::BaseController
  def index
    player_cards = PlayerCard.all.order(:id)
    player_cards = player_cards.where(card_set_id: params[:card_set_id]) if params[:card_set_id].present?
    player_cards = player_cards.where(player_id: params[:player_id]) if params[:player_id].present?
    render json: player_cards, each_serializer: PlayerCardSerializer
  end

  def show
    player_card = PlayerCard.find(params[:id])
    render json: player_card, serializer: PlayerCardSerializer
  end
end
