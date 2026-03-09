require 'rails_helper'

RSpec.describe '認証・認可チェーン', type: :request do
  let(:password) { 'password123' }
  let(:player_user) { create(:user, password: password) }
  let(:commissioner_user) { create(:user, :commissioner, password: password) }

  # ログインヘルパー
  def login_as(user)
    post '/api/v1/auth/login', params: { name: user.name, password: password }, as: :json
  end

  describe '認証チェーン（Api::V1::BaseController）' do
    context '未認証の場合' do
      it 'GET /api/v1/teams で401を返す' do
        get '/api/v1/teams'

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('ログインが必要です')
      end

      it 'GET /api/v1/players で401を返す' do
        get '/api/v1/players'

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('ログインが必要です')
      end

      it 'GET /api/v1/managers で401を返す' do
        get '/api/v1/managers'

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('ログインが必要です')
      end
    end

    context '認証済みの場合' do
      before { login_as(player_user) }

      it 'GET /api/v1/teams で200を返す' do
        get '/api/v1/teams'

        expect(response).to have_http_status(:ok)
      end

      it 'GET /api/v1/players で200を返す' do
        get '/api/v1/players'

        expect(response).to have_http_status(:ok)
      end

      it 'GET /api/v1/managers で200を返す' do
        get '/api/v1/managers'

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe '認証チェーンの一貫性' do
    context 'ログイン→ログアウト→再アクセス' do
      it 'ログアウト後はAPIにアクセスできなくなる' do
        login_as(player_user)
        get '/api/v1/teams'
        expect(response).to have_http_status(:ok)

        post '/api/v1/auth/logout', as: :json
        expect(response).to have_http_status(:ok)

        get '/api/v1/teams'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
