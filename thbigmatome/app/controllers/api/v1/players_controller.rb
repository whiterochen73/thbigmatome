class Api::V1::PlayersController < Api::V1::BaseController
  def index
    players = Player.eager_load(:player_batting_skills, :player_player_types, :player_biorhythms, :player_pitching_skills, :catchers_players, :partner_pitchers_players).all.order(:id)
    render json: players, each_serializer: PlayerDetailSerializer
  end

  def show
    player = Player.find(params[:id])
    render json: player, serializer: PlayerDetailSerializer
  end

  def create
    player = Player.new(player_params)
    if player.save
      render json: player, status: :created
    else
      render json: { errors: player.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    player = Player.find(params[:id])
    if player.update(player_params)
      render json: player
    else
      render json: { errors: player.errors.full_messages }, status: :unprocessable_entity
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
      :name, :number, :short_name, :position, :throwing_hand, :batting_hand, :bunt, :steal_start, :steal_end, :speed,
      :defense_p, :defense_c, :defense_1b, :defense_2b, :defense_3b, :defense_ss, :defense_of,
      :defense_lf, :defense_cf, :defense_rf, :special_defense_c,
      :throwing_c, :special_throwing_c, :throwing_of, :throwing_lf, :throwing_cf, :throwing_rf,
      :starter_stamina, :relief_stamina, :is_relief_only,
      :injury_rate, :batting_style_id, :pitching_style_id, :pinch_pitching_style_id, :catcher_pitching_style_id,
      batting_skill_ids: [], pitching_skill_ids: [], player_type_ids: [], biorhythm_ids: [], catcher_ids: [], partner_pitcher_ids: []
    )
  end
end
