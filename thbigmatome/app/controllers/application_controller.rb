class ApplicationController < ActionController::API
  # CSRF保護を有効にする
  include ActionController::RequestForgeryProtection
  protect_from_forgery with: :exception # 例外を発生させる

  # フロントエンドにCSRFトークンを送信するためのメソッド (Ajax通信用)
  # これにより、Railsのセッションクッキーが送信されると同時に、
  # X-CSRF-Token ヘッダーにトークンがセットされる
  before_action :set_csrf_token_header

  include ActionController::Cookies

  private

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end

  def authenticate_user!
    render json: { error: 'ログインが必要です' }, status: :unauthorized unless current_user
  end

  def set_csrf_token_header
    if protect_against_forgery?
      # ヘッダーにX-CSRF-Tokenとしてトークンをセット
      # このトークンは、フォーム送信時やAjaxリクエスト時に
      # フロントエンドがリクエストヘッダーに含める必要がある
      response.set_header('X-CSRF-Token', form_authenticity_token)
    end
  end
end
