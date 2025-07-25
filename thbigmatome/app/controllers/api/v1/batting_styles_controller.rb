module Api
  module V1
    class BattingStylesController < ApplicationController
      before_action :set_batting_style, only: [:update, :destroy]

      # GET /api/v1/batting-styles
      def index
        @batting_styles = BattingStyle.all.order(:id)
        render json: @batting_styles
      end

      # POST /api/v1/batting-styles
      def create
        @batting_style = BattingStyle.new(batting_style_params)
        if @batting_style.save
          render json: @batting_style, status: :created
        else
          render json: { errors: @batting_style.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/batting-styles/:id
      def update
        if @batting_style.update(batting_style_params)
          render json: @batting_style
        else
          render json: { errors: @batting_style.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/batting-styles/:id
      def destroy
        @batting_style.destroy
        head :no_content
      end

      private

      def set_batting_style
        @batting_style = BattingStyle.find(params[:id])
      end

      def batting_style_params
        params.require(:batting_style).permit(:name, :description)
      end
    end
  end
end