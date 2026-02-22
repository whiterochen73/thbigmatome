require 'rails_helper'

RSpec.describe 'Commissioner::LeagueGames', type: :request do
  let(:password) { 'password123' }
  let(:commissioner_user) { create(:user, :commissioner, password: password) }
  let(:player_user) { create(:user, password: password) }
  let!(:league) { create(:league) }
  let!(:league_season) { create(:league_season, league: league) }

  def login_as(user)
    post '/api/v1/auth/login', params: { name: user.name, password: password }, as: :json
  end

  def base_path
    "/api/v1/commissioner/leagues/#{league.id}/league_seasons/#{league_season.id}/league_games"
  end

  describe 'GET /api/v1/commissioner/leagues/:league_id/league_seasons/:league_season_id/league_games' do
    context 'commissionerユーザーの場合' do
      before { login_as(commissioner_user) }

      it '200を返す' do
        get base_path
        expect(response).to have_http_status(:ok)
      end

      it 'シーズンに紐づく試合一覧を返す' do
        game1 = create(:league_game, league_season: league_season)
        game2 = create(:league_game, league_season: league_season)
        other_game = create(:league_game)

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

  describe 'GET /api/v1/commissioner/leagues/:league_id/league_seasons/:league_season_id/league_games/:id' do
    let!(:league_game) { create(:league_game, league_season: league_season) }

    context 'commissionerユーザーの場合' do
      before { login_as(commissioner_user) }

      it '200を返す' do
        get "#{base_path}/#{league_game.id}"
        expect(response).to have_http_status(:ok)
      end
    end

    context '一般ユーザーの場合' do
      before { login_as(player_user) }

      it '403を返す' do
        get "#{base_path}/#{league_game.id}"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context '未認証の場合' do
      it '401を返す' do
        get "#{base_path}/#{league_game.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
