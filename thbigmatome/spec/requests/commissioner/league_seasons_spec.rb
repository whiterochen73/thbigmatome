require 'rails_helper'

RSpec.describe 'Commissioner::LeagueSeasons', type: :request do
  let(:password) { 'password123' }
  let(:commissioner_user) { create(:user, :commissioner, password: password) }
  let(:player_user) { create(:user, password: password) }
  let!(:league) { create(:league) }

  def login_as(user)
    post '/api/v1/auth/login', params: { name: user.name, password: password }, as: :json
  end

  def base_path
    "/api/v1/commissioner/leagues/#{league.id}/league_seasons"
  end

  describe 'GET /api/v1/commissioner/leagues/:league_id/league_seasons' do
    context 'commissionerユーザーの場合' do
      before { login_as(commissioner_user) }

      it '200を返す' do
        get base_path
        expect(response).to have_http_status(:ok)
      end

      it 'リーグに紐づくシーズン一覧を返す' do
        season1 = create(:league_season, league: league)
        season2 = create(:league_season, league: league)
        other_league_season = create(:league_season)

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

  describe 'GET /api/v1/commissioner/leagues/:league_id/league_seasons/:id' do
    let!(:league_season) { create(:league_season, league: league) }

    context 'commissionerユーザーの場合' do
      before { login_as(commissioner_user) }

      it '200を返す' do
        get "#{base_path}/#{league_season.id}"
        expect(response).to have_http_status(:ok)
      end
    end

    context '一般ユーザーの場合' do
      before { login_as(player_user) }

      it '403を返す' do
        get "#{base_path}/#{league_season.id}"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context '未認証の場合' do
      it '401を返す' do
        get "#{base_path}/#{league_season.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/commissioner/leagues/:league_id/league_seasons' do
    let(:valid_params) do
      {
        league_season: {
          name: 'テストシーズン',
          start_date: Date.current.to_s,
          end_date: (Date.current + 30.days).to_s,
          status: 'pending'
        }
      }
    end

    context 'commissionerユーザーの場合' do
      before { login_as(commissioner_user) }

      it '201を返しシーズンを作成する' do
        expect {
          post base_path, params: valid_params, as: :json
        }.to change(LeagueSeason, :count).by(1)
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

  describe 'PATCH /api/v1/commissioner/leagues/:league_id/league_seasons/:id' do
    let!(:league_season) { create(:league_season, league: league) }
    let(:update_params) { { league_season: { name: '更新シーズン名' } } }

    context 'commissionerユーザーの場合' do
      before { login_as(commissioner_user) }

      it '200を返しシーズンを更新する' do
        patch "#{base_path}/#{league_season.id}", params: update_params, as: :json
        expect(response).to have_http_status(:ok)
        expect(league_season.reload.name).to eq('更新シーズン名')
      end
    end

    context '一般ユーザーの場合' do
      before { login_as(player_user) }

      it '403を返す' do
        patch "#{base_path}/#{league_season.id}", params: update_params, as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end

    context '未認証の場合' do
      it '401を返す' do
        patch "#{base_path}/#{league_season.id}", params: update_params, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/commissioner/leagues/:league_id/league_seasons/:id' do
    let!(:league_season) { create(:league_season, league: league) }

    context 'commissionerユーザーの場合' do
      before { login_as(commissioner_user) }

      it '204を返しシーズンを削除する' do
        expect {
          delete "#{base_path}/#{league_season.id}"
        }.to change(LeagueSeason, :count).by(-1)
        expect(response).to have_http_status(:no_content)
      end
    end

    context '一般ユーザーの場合' do
      before { login_as(player_user) }

      it '403を返す' do
        delete "#{base_path}/#{league_season.id}"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context '未認証の場合' do
      it '401を返す' do
        delete "#{base_path}/#{league_season.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/commissioner/leagues/:league_id/league_seasons/:id/generate_schedule' do
    let!(:league_season) { create(:league_season, league: league) }

    context 'commissionerユーザーの場合' do
      before { login_as(commissioner_user) }

      it '200を返す' do
        post "#{base_path}/#{league_season.id}/generate_schedule"
        expect(response).to have_http_status(:ok)
      end
    end

    context '一般ユーザーの場合' do
      before { login_as(player_user) }

      it '403を返す' do
        post "#{base_path}/#{league_season.id}/generate_schedule"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context '未認証の場合' do
      it '401を返す' do
        post "#{base_path}/#{league_season.id}/generate_schedule"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
