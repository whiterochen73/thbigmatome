module Api
  module V1
    class ManagersController < Api::V1::BaseController
      before_action :set_manager, only: [ :show, :update, :destroy ]

      # GET /api/v1/managers
      def index
        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 25).to_i

        # パラメータのバリデーション
        page = 1 if page < 1
        per_page = 25 if per_page < 1 || per_page > 100

        offset = (page - 1) * per_page

        @managers = Manager.all.includes(teams: :season).order(:id).limit(per_page).offset(offset)
        total_count = Manager.count
        total_pages = (total_count.to_f / per_page).ceil

        render json: {
          data: @managers.as_json(include: { teams: { methods: [ :has_season ] } }),
          meta: {
            total_count: total_count,
            per_page: per_page,
            current_page: page,
            total_pages: total_pages
          }
        }
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
        render json: { error: "Manager not found" }, status: :not_found
      end

      def manager_params
        params.require(:manager).permit(:name, :short_name, :irc_name, :user_id)
      end
    end
  end
end
