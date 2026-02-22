require 'rails_helper'

RSpec.describe 'Commissioner::LeaguePoolPlayers', type: :request do
  let(:password) { 'password123' }
  let(:commissioner_user) { create(:user, :commissioner, password: password) }
  let(:player_user) { create(:user, password: password) }
  let!(:league) { create(:league) }
  let!(:league_season) { create(:league_season, league: league) }

  def login_as(user)
    post '/api/v1/auth/login', params: { name: user.name, password: password }, as: :json
  end

  def base_path
    "/api/v1/commissioner/leagues/#{league.id}/league_seasons/#{league_season.id}/league_pool_players"
  end

  describe 'GET /api/v1/commissioner/.../league_pool_players' do
    context 'commissionerユーザーの場合' do
      before { login_as(commissioner_user) }

      it '200を返す' do
        get base_path
        expect(response).to have_http_status(:ok)
      end

      it 'シーズンのプール選手一覧を返す' do
        player1 = create(:player)
        player2 = create(:player)
        create(:league_pool_player, league_season: league_season, player: player1)
        create(:league_pool_player, league_season: league_season, player: player2)

        get base_path
        json = JSON.parse(response.body)
        expect(json.size).to eq(2)
      end
    end

    context '一般ユーザーの場合' do
      before { login_as(player_user) }

      it '403を返す' do
        get base_path
        expect(response).to have_http_status(:forbidden)
      end
    end

    context '未認証の場合' do
      it '401を返す' do
        get base_path
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/commissioner/.../league_pool_players' do
    let!(:player) { create(:player) }
    let(:valid_params) { { league_pool_player: { player_id: player.id } } }

    context 'commissionerユーザーの場合' do
      before { login_as(commissioner_user) }

      it '201を返しプール選手を追加する' do
        expect {
          post base_path, params: valid_params, as: :json
        }.to change(LeaguePoolPlayer, :count).by(1)
        expect(response).to have_http_status(:created)
      end
    end

    context '一般ユーザーの場合' do
      before { login_as(player_user) }

      it '403を返す' do
        post base_path, params: valid_params, as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end

    context '未認証の場合' do
      it '401を返す' do
        post base_path, params: valid_params, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/commissioner/.../league_pool_players/:id' do
    let!(:league_pool_player) { create(:league_pool_player, league_season: league_season) }

    context 'commissionerユーザーの場合' do
      before { login_as(commissioner_user) }

      it '204を返しプール選手を削除する' do
        expect {
          delete "#{base_path}/#{league_pool_player.id}"
        }.to change(LeaguePoolPlayer, :count).by(-1)
        expect(response).to have_http_status(:no_content)
      end
    end

    context '一般ユーザーの場合' do
      before { login_as(player_user) }

      it '403を返す' do
        delete "#{base_path}/#{league_pool_player.id}"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context '未認証の場合' do
      it '401を返す' do
        delete "#{base_path}/#{league_pool_player.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
