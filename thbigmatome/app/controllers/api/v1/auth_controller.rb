# app/controllers/api/v1/auth_controller.rb
class Api::V1::AuthController < ApplicationController
  # ログインとログアウトは認証不要
  # ログインアクション (例: create) ではCSRF保護をスキップ
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!, only: [:login, :logout], raise: false

  def login
    user = User.find_by(name: params[:name])

    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      render json: { user: user.slice(:id, :name), message: 'ログイン成功' }
    else
      render json: { error: 'メールアドレスまたはパスワードが間違っています' }, status: :unauthorized
    end
  end

  def logout
    session[:user_id] = nil
    session.clear
    reset_session
    render json: { message: 'ログアウトしました' }
  end

  # メソッド名を変更して競合を回避
  def show_current_user
    if current_user
      render json: { user: current_user.slice(:id, :name) }
    else
      render json: { error: 'ログインしていません' }, status: :unauthorized
    end
  end
end