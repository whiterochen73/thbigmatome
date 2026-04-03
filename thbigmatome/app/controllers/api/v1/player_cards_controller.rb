class Api::V1::PlayerCardsController < Api::V1::BaseController
  def index
    player_cards = PlayerCard.includes({ player: :cost_players }, :card_set, :player_card_defenses, :card_image_attachment, :card_image_blob).order(:id)
    player_cards = player_cards.where(card_set_id: params[:card_set_id]) if params[:card_set_id].present?
    player_cards = player_cards.where(card_type: params[:card_type]) if params[:card_type].present?
    player_cards = player_cards.where(player_id: params[:player_id]) if params[:player_id].present?
    if params[:name].present?
      player_cards = player_cards.joins(:player).where("players.name ILIKE ?", "%#{params[:name]}%")
    end

    total = player_cards.count
    page = [ (params[:page] || 1).to_i, 1 ].max
    per_page = [ (params[:per_page] || 50).to_i, 100 ].min
    player_cards = player_cards.offset((page - 1) * per_page).limit(per_page)

    render json: {
      player_cards: ActiveModelSerializers::SerializableResource.new(player_cards, each_serializer: PlayerCardSerializer).as_json,
      meta: { total: total, page: page, per_page: per_page }
    }
  end

  def show
    player_card = PlayerCard.includes(
      { player: :cost_players }, :card_set,
      :player_card_defenses,
      { player_card_traits: [ :trait_definition, :condition ] },
      { player_card_abilities: [ :ability_definition, :condition ] }
    ).find(params[:id])
    render json: player_card, serializer: PlayerCardDetailSerializer
  end

  def update
    player_card = PlayerCard.find(params[:id])
    if player_card.update(player_card_params)
      player_card = PlayerCard.includes(
        { player: :cost_players }, :card_set,
        :player_card_defenses,
        { player_card_traits: [ :trait_definition, :condition ] },
        { player_card_abilities: [ :ability_definition, :condition ] }
      ).find(player_card.id)
      render json: player_card, serializer: PlayerCardDetailSerializer
    else
      render json: { errors: player_card.errors.full_messages }, status: :unprocessable_content
    end
  end

  private

  def player_card_params
    params.require(:player_card).permit(
      :card_type, :handedness, :speed, :bunt,
      :steal_start, :steal_end, :injury_rate,
      :is_relief_only, :is_closer, :is_switch_hitter, :is_dual_wielder,
      :starter_stamina, :relief_stamina,
      :biorhythm_period,
      :unique_traits, :injury_traits,
      player_card_defenses_attributes: [
        :id, :position, :range_value, :error_rank, :throwing, :condition_id, :_destroy
      ],
      player_card_traits_attributes: [
        :id, :trait_definition_id, :role, :sort_order, :condition_id, :_destroy
      ],
      player_card_abilities_attributes: [
        :id, :ability_definition_id, :role, :sort_order, :condition_id, :_destroy
      ]
    )
  end
end
