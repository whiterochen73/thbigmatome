require 'rails_helper'

RSpec.describe 'Api::V1::AuthController', type: :request do
  let(:password) { 'password123' }
  let(:user) { create(:user, password: password) }

  describe 'POST /api/v1/auth/login' do
    context '正しい認証情報の場合' do
      it '200を返し、ユーザー情報とセッションが設定される' do
        post '/api/v1/auth/login', params: { name: user.name, password: password }, as: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['user']['id']).to eq(user.id)
        expect(json['user']['name']).to eq(user.name)
        expect(json['message']).to eq('ログイン成功')
      end

      it 'ログイン後にcurrent_userが取得できる' do
        post '/api/v1/auth/login', params: { name: user.name, password: password }, as: :json
        get '/api/v1/auth/current_user'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['user']['id']).to eq(user.id)
      end
    end

    context '不正なパスワードの場合' do
      it '401を返す' do
        post '/api/v1/auth/login', params: { name: user.name, password: 'wrong_password' }, as: :json

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json['error']).to be_present
      end
    end

    context '存在しないユーザーの場合' do
      it '401を返す' do
        post '/api/v1/auth/login', params: { name: 'nonexistent_user', password: password }, as: :json

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json['error']).to be_present
      end
    end
  end

  describe 'POST /api/v1/auth/logout' do
    context 'ログイン済みの場合' do
      before do
        post '/api/v1/auth/login', params: { name: user.name, password: password }, as: :json
      end

      it 'ログアウトに成功する' do
        post '/api/v1/auth/logout', as: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['message']).to eq('ログアウトしました')
      end

      it 'ログアウト後にcurrent_userが取得できなくなる' do
        post '/api/v1/auth/logout', as: :json
        get '/api/v1/auth/current_user'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/auth/current_user' do
    context '認証済みの場合' do
      before do
        post '/api/v1/auth/login', params: { name: user.name, password: password }, as: :json
      end

      it 'ユーザー情報を返す' do
        get '/api/v1/auth/current_user'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['user']['id']).to eq(user.id)
        expect(json['user']['name']).to eq(user.name)
        expect(json['user']['role']).to eq('general')
      end
    end

    context 'commissionerユーザーの場合' do
      let(:commissioner_user) { create(:user, :commissioner, password: password) }

      before do
        post '/api/v1/auth/login', params: { name: commissioner_user.name, password: password }, as: :json
      end

      it 'roleがcommissionerとして返される' do
        get '/api/v1/auth/current_user'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['user']['role']).to eq('commissioner')
      end
    end

    context '未認証の場合' do
      it '401を返す' do
        get '/api/v1/auth/current_user'

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json['error']).to be_present
      end
    end
  end
end
