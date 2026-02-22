class Api::V1::GameLineupEntriesController < Api::V1::BaseController
  before_action :set_game

  # GET /api/v1/games/:game_id/lineup
  def show
    lineup = @game.game_lineup_entries.includes(player_card: :player)
    render json: { lineup: lineup.map { |e| GameLineupEntrySerializer.new(e).as_json } }
  end

  # POST /api/v1/games/:game_id/lineup
  def create
    result = save_lineup
    if result[:success]
      render json: { lineup: result[:lineup] }, status: :created
    else
      render json: { errors: result[:errors] }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/games/:game_id/lineup
  def update
    result = save_lineup
    if result[:success]
      render json: { lineup: result[:lineup] }, status: :ok
    else
      render json: { errors: result[:errors] }, status: :unprocessable_entity
    end
  end

  private

  def set_game
    @game = Game.find(params[:game_id])
  end

  def save_lineup
    entries_params = params.require(:lineup).map do |entry|
      entry.permit(:player_card_id, :role, :batting_order, :position, :is_dh_pitcher, :is_reliever)
    end

    saved_lineup = nil
    GameLineupEntry.transaction do
      @game.game_lineup_entries.destroy_all
      entries = entries_params.map do |ep|
        @game.game_lineup_entries.build(ep.to_h.symbolize_keys)
      end
      entries.each(&:save!)
      saved_lineup = @game.game_lineup_entries.includes(player_card: :player).reload
    end

    { success: true, lineup: saved_lineup.map { |e| GameLineupEntrySerializer.new(e).as_json } }
  rescue ActiveRecord::RecordInvalid => e
    { success: false, errors: [ e.message ] }
  end
end
