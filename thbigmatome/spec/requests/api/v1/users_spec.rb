require 'rails_helper'

RSpec.describe 'Api::V1::Users', type: :request do
  let(:password) { 'password123' }
  let(:commissioner_user) { create(:user, :commissioner, password: password) }
  let(:player_user) { create(:user, password: password) }

  def login_as(user)
    post '/api/v1/auth/login', params: { name: user.name, password: password }, as: :json
  end

  describe 'GET /api/v1/users' do
    context 'commissionerユーザーの場合' do
      before { login_as(commissioner_user) }

      it '200を返す' do
        get '/api/v1/users'
        expect(response).to have_http_status(:ok)
      end

      it 'ユーザー一覧を返す' do
        create(:user)
        get '/api/v1/users'
        json = JSON.parse(response.body)
        expect(json).to be_an(Array)
        expect(json.size).to be >= 1
      end
    end

    context '一般ユーザーの場合' do
      before { login_as(player_user) }

      it '403を返す' do
        get '/api/v1/users'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context '未認証の場合' do
      it '401を返す' do
        get '/api/v1/users'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/users' do
    let(:valid_params) do
      { user: { name: 'new_user', display_name: '新規ユーザー', password: 'pass1234', role: 'player' } }
    end

    context 'commissionerユーザーの場合' do
      before { login_as(commissioner_user) }

      it '201を返しユーザーを作成する' do
        expect {
          post '/api/v1/users', params: valid_params, as: :json
        }.to change(User, :count).by(1)
        expect(response).to have_http_status(:created)
      end

      it 'バリデーションエラー時は422を返す' do
        post '/api/v1/users', params: { user: { name: '', display_name: '', password: 'x' } }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context '一般ユーザーの場合' do
      before { login_as(player_user) }

      it '403を返す' do
        post '/api/v1/users', params: valid_params, as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end

    context '未認証の場合' do
      it '401を返す' do
        post '/api/v1/users', params: valid_params, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/users/me/teams' do
    context 'commissionerユーザーの場合' do
      let!(:my_team) { create(:team, user_id: commissioner_user.id) }
      let!(:other_team) { create(:team) }

      before { login_as(commissioner_user) }

      it '200を返す' do
        get '/api/v1/users/me/teams'
        expect(response).to have_http_status(:ok)
      end

      it '自分のチームのみ返す' do
        get '/api/v1/users/me/teams'
        json = JSON.parse(response.body)
        expect(json.map { |t| t['id'] }).to include(my_team.id)
        expect(json.map { |t| t['id'] }).not_to include(other_team.id)
      end

      it 'id/name/is_active/user_id/short_nameのフィールドを含む' do
        get '/api/v1/users/me/teams'
        json = JSON.parse(response.body)
        expect(json.first.keys).to match_array(%w[id name is_active user_id short_name])
      end
    end

    context '一般ユーザーの場合' do
      let!(:my_team) { create(:team, user_id: player_user.id) }

      before { login_as(player_user) }

      it '200を返す' do
        get '/api/v1/users/me/teams'
        expect(response).to have_http_status(:ok)
      end

      it '自分のチームのみ返す' do
        get '/api/v1/users/me/teams'
        json = JSON.parse(response.body)
        expect(json.map { |t| t['id'] }).to include(my_team.id)
      end
    end

    context '未認証の場合' do
      it '401を返す' do
        get '/api/v1/users/me/teams'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH /api/v1/users/:id/reset_password' do
    let!(:target_user) { create(:user) }

    context 'commissionerユーザーの場合' do
      before { login_as(commissioner_user) }

      it '200を返しパスワードをリセットする' do
        patch "/api/v1/users/#{target_user.id}/reset_password",
              params: { password: 'newpass456' }, as: :json
        expect(response).to have_http_status(:ok)
      end

      it 'リセット後に新パスワードでログインできる' do
        patch "/api/v1/users/#{target_user.id}/reset_password",
              params: { password: 'newpass456' }, as: :json
        post '/api/v1/auth/logout', as: :json
        post '/api/v1/auth/login', params: { name: target_user.name, password: 'newpass456' }, as: :json
        expect(response).to have_http_status(:ok)
      end
    end

    context '一般ユーザーの場合' do
      before { login_as(player_user) }

      it '403を返す' do
        patch "/api/v1/users/#{target_user.id}/reset_password",
              params: { password: 'newpass456' }, as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end

    context '未認証の場合' do
      it '401を返す' do
        patch "/api/v1/users/#{target_user.id}/reset_password",
              params: { password: 'newpass456' }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
