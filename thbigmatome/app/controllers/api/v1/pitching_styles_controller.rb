module Api
  module V1
    class PitchingStylesController < ApplicationController
      before_action :authenticate_user!
      before_action :set_pitching_style, only: [ :update, :destroy ]

      # GET /api/v1/pitching-styles
      def index
        @pitching_styles = PitchingStyle.all.order(:id)
        render json: @pitching_styles.to_json
      end

      # POST /api/v1/pitching-styles
      def create
        @pitching_style = PitchingStyle.new(pitching_style_params)
        if @pitching_style.save
          render json: @pitching_style, status: :created
        else
          render json: { errors: @pitching_style.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/pitching-styles/:id
      def update
        if @pitching_style.update(pitching_style_params)
          render json: @pitching_style
        else
          render json: { errors: @pitching_style.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/pitching-styles/:id
      def destroy
        @pitching_style.destroy
        head :no_content
      end

      private

      def set_pitching_style
        @pitching_style = PitchingStyle.find(params[:id])
      end

      def pitching_style_params
        params.require(:pitching_style).permit(:name, :description)
      end
    end
  end
end
