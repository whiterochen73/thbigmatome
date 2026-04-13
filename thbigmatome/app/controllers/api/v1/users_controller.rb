module Api
  module V1
    class UsersController < Api::V1::BaseController
      before_action :check_commissioner
      before_action :set_user, only: [ :reset_password, :update_role ]
      skip_before_action :check_commissioner, only: [ :my_teams, :change_password ]

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
          render json: { errors: user.errors.full_messages }, status: :unprocessable_content
        end
      end

      # GET /api/v1/users/me/teams
      def my_teams
        # user_id紐づきのチーム
        owned_teams = current_user.teams

        # Manager.user_id（文字列）で紐付けられたチーム（director/coach所属チーム）
        manager = Manager.find_by(user_id: current_user.id.to_s)
        managed_teams = manager ? Team.joins(:team_managers).where(team_managers: { manager_id: manager.id }) : Team.none

        teams = Team.where(id: (owned_teams.pluck(:id) + managed_teams.pluck(:id)).uniq)
                    .order(is_active: :desc, created_at: :asc)
        render json: teams.as_json(only: [ :id, :name, :is_active, :user_id, :short_name, :team_type ])
      end

      # POST /api/v1/users/change_password
      def change_password
        unless current_user.authenticate(params[:current_password])
          return render json: { error: "現在のパスワードが正しくありません" }, status: :unprocessable_content
        end

        if current_user.update(password: params[:password], password_confirmation: params[:password_confirmation])
          render json: { message: "パスワードを変更しました" }
        else
          render json: { errors: current_user.errors.full_messages }, status: :unprocessable_content
        end
      end

      # PATCH /api/v1/users/:id/update_role
      def update_role
        if current_user.id == @user.id
          return render json: { error: "自分自身のロールは変更できません" }, status: :unprocessable_content
        end

        if @user.commissioner? && User.where(role: :commissioner).count == 1 && params[:role] == "player"
          return render json: { error: "ラストコミッショナーのロールは変更できません" }, status: :unprocessable_content
        end

        if @user.update(role: params[:role])
          render json: @user.slice(:id, :name, :display_name, :role)
        else
          render json: { errors: @user.errors.full_messages }, status: :unprocessable_content
        end
      end

      # PATCH /api/v1/users/:id/reset_password
      def reset_password
        if @user.update(password: params[:password])
          render json: { message: "パスワードをリセットしました" }
        else
          render json: { errors: @user.errors.full_messages }, status: :unprocessable_content
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
