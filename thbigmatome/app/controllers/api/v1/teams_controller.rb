module Api
  module V1
    class TeamsController < ApplicationController
      before_action :set_team, only: [:show, :update, :destroy]
      before_action :set_manager_for_nested, only: [:index, :create] # ネストされたルーティング用

      # GET /api/v1/teams または /api/v1/managers/:manager_id/teams
      def index
        if @manager # Managerに紐づくTeamを取得
          @teams = @manager.teams
        else # 全てのTeamを取得 (必要であれば)
          @teams = Team.preload(:manager, :season).all
        end
        render json: @teams
      end

      # GET /api/v1/teams/:id
      def show
        render json: @team
      end

      # POST /api/v1/teams または /api/v1/managers/:manager_id/teams
      def create
        # Managerが指定されていれば、そのManagerに紐づける
        team_params_with_manager = team_params
        if @manager
          team_params_with_manager[:manager_id] = @manager.id
        end

        @team = Team.new(team_params_with_manager)

        if @team.save
          render json: @team, status: :created
        else
          render json: @team.errors, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/teams/:id
      def update
        if @team.update(team_params)
          render json: @team
        else
          render json: @team.errors, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/teams/:id
      def destroy
        @team.destroy
        head :no_content
      end

      private

      def set_team
        @team = Team.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Team not found' }, status: :not_found
      end

      def set_manager_for_nested
        # params[:manager_id] があればManagerをセット
        if params[:manager_id].present?
          @manager = Manager.find(params[:manager_id])
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Manager not found' }, status: :not_found
      end

      def team_params
        params.require(:team).permit(:name, :short_name, :is_active, :manager_id)
      end
    end
  end
end