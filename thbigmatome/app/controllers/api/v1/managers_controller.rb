module Api
  module V1
    class ManagersController < ApplicationController
      before_action :set_manager, only: [:show, :update, :destroy]

      # GET /api/v1/managers
      def index
        @managers = Manager.all.includes(:teams).order(:id)
        render json: @managers, include: :teams
      end

      # GET /api/v1/managers/:id
      def show
        render json: @manager, include: :teams # Manager詳細時に紐づくTeamも返す
      end

      # POST /api/v1/managers
      def create
        @manager = Manager.new(manager_params)
        if @manager.save
          render json: @manager, status: :created
        else
          render json: @manager.errors, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/managers/:id
      def update
        if @manager.update(manager_params)
          render json: @manager
        else
          render json: @manager.errors, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/managers/:id
      def destroy
        @manager.destroy
        head :no_content # 成功したが返すコンテンツがない場合
      end

      private

      def set_manager
        @manager = Manager.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Manager not found' }, status: :not_found
      end

      def manager_params
        params.require(:manager).permit(:name, :short_name, :irc_name, :user_id)
      end
    end
  end
end