class Api::V1::CardSetsController < Api::V1::BaseController
  def index
    card_sets = CardSet.all.order(:id)
    render json: card_sets, each_serializer: CardSetSerializer
  end

  def show
    card_set = CardSet.find(params[:id])
    render json: card_set, serializer: CardSetSerializer
  end
end
