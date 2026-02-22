module Api
  module V1
    class UsersController < Api::V1::BaseController
      before_action :check_commissioner
      before_action :set_user, only: [ :reset_password ]
      skip_before_action :check_commissioner, only: [ :my_teams ]

      # GET /api/v1/users
      def index
        users = User.all.order(:id)
        render json: users.map { |u| u.slice(:id, :name, :display_name, :role) }
      end

      # POST /api/v1/users
      def create
        user = User.new(user_params)
        if user.save
          render json: user.slice(:id, :name, :display_name, :role), status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/users/me/teams
      def my_teams
        teams = current_user.teams.order(is_active: :desc, created_at: :asc)
        render json: teams.as_json(only: [ :id, :name, :is_active, :user_id, :short_name ])
      end

      # PATCH /api/v1/users/:id/reset_password
      def reset_password
        if @user.update(password: params[:password])
          render json: { message: "パスワードをリセットしました" }
        else
          render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def check_commissioner
        head :forbidden unless current_user.commissioner?
      end

      def set_user
        @user = User.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "User not found" }, status: :not_found
      end

      def user_params
        params.require(:user).permit(:name, :display_name, :password, :role)
      end
    end
  end
end
