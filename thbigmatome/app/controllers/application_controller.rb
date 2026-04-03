class ApplicationController < ActionController::API
  # CSRF保護: APIモードではnull_sessionを使用する
  # (CORS設定でorigin制限済み。CSRF失敗時はセッションを無効化してauthenticate_user!が401を返す)
  include ActionController::RequestForgeryProtection
  protect_from_forgery with: :null_session

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
    render json: { error: "ログインが必要です" }, status: :unauthorized unless current_user
  end

  def set_csrf_token_header
    if protect_against_forgery?
      # ヘッダーにX-CSRF-Tokenとしてトークンをセット
      # このトークンは、フォーム送信時やAjaxリクエスト時に
      # フロントエンドがリクエストヘッダーに含める必要がある
      response.set_header("X-CSRF-Token", form_authenticity_token)
    end
  end
end
