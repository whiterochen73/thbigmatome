module Api
  module V1
    class PlayersController < ApplicationController
      before_action :set_player, only: %i[show update destroy]

      def index
        @players = Player.includes(:player_batting_skills, :player_player_types, :player_biorhythms, :player_pitching_skills, :catchers_players, :partner_pitchers_players).all.order(:id)
        render json: @players.as_json(methods: [:batting_skill_ids, :player_type_ids, :biorhythm_ids, :pitching_skill_ids, :catcher_ids, :partner_pitcher_ids])
      end

      def show
        render json: @player.as_json(methods: [:batting_skill_ids, :player_type_ids, :biorhythm_ids, :pitching_skill_ids, :catcher_ids, :partner_pitcher_ids])
      end

      def create
        @player = Player.new(player_params)
        if @player.save
          render json: @player.as_json(methods: [:batting_skill_ids, :player_type_ids, :biorhythm_ids]), status: :created
        else
          render json: { errors: @player.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @player.update(player_params)
          render json: @player.as_json(methods: [:batting_skill_ids, :player_type_ids, :biorhythm_ids])
        else
          render json: { errors: @player.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @player.destroy
        head :no_content
      end

      private

      def set_player
        @player = Player.find(params[:id])
      end

      def player_params
        params.require(:player).permit(
          :name, :short_name, :number, :position, :throwing_hand, :batting_hand,
          :injury_rate, :batting_style_id, :batting_style_description,
          :bunt, :steal_start, :steal_end, :speed, :batting_style_id,
          :defense_p, :defense_c, :throwing_c, :defense_1b, :defense_2b,
          :defense_3b, :defense_ss, :defense_of, :throwing_of, :defense_lf,
          :throwing_lf, :defense_cf, :throwing_cf, :defense_rf, :throwing_rf,
          :is_pitcher, :special_defense_c, :special_throwing_c,
          :starter_stamina, :relief_stamina, :is_relief_only, :pitching_style_id,
          :pitching_style_description,
          :pinch_pitching_style_id, :catcher_pitching_style_id,
          batting_skill_ids: [], player_type_ids: [], biorhythm_ids: [],
          pitching_skill_ids: [], catcher_ids: [], partner_pitcher_ids: []
        )
      end
    end
  end
end
