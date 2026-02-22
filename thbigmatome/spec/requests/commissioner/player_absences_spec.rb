require 'rails_helper'

RSpec.describe 'Commissioner::PlayerAbsences', type: :request do
  let(:password) { 'password123' }
  let(:commissioner_user) { create(:user, :commissioner, password: password) }
  let(:player_user) { create(:user, password: password) }
  let!(:league) { create(:league) }
  let!(:team) { create(:team) }
  let!(:league_membership) { create(:league_membership, league: league, team: team) }
  let!(:player) { create(:player) }
  let!(:team_membership) { create(:team_membership, team: team, player: player) }
  let!(:season) { create(:season, team: team) }

  def login_as(user)
    post '/api/v1/auth/login', params: { name: user.name, password: password }, as: :json
  end

  def base_path
    "/api/v1/commissioner/leagues/#{league.id}/teams/#{team.id}/team_memberships/#{team_membership.id}/player_absences"
  end

  describe 'GET /api/v1/commissioner/.../player_absences' do
    context 'commissionerユーザーの場合' do
      before { login_as(commissioner_user) }

      it '200を返す' do
        get base_path
        expect(response).to have_http_status(:ok)
      end

      it 'メンバーの離脱一覧を返す' do
        create(:player_absence, team_membership: team_membership, season: season)
        create(:player_absence, team_membership: team_membership, season: season)

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

  describe 'POST /api/v1/commissioner/.../player_absences' do
    let(:valid_params) do
      {
        player_absence: {
          season_id: season.id,
          absence_type: 'injury',
          start_date: Date.current.to_s,
          duration: 5,
          duration_unit: 'days'
        }
      }
    end

    context 'commissionerユーザーの場合' do
      before { login_as(commissioner_user) }

      it '201を返し離脱を作成する' do
        expect {
          post base_path, params: valid_params, as: :json
        }.to change(PlayerAbsence, :count).by(1)
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

  describe 'PATCH /api/v1/commissioner/.../player_absences/:id' do
    let!(:player_absence) { create(:player_absence, team_membership: team_membership, season: season) }
    let(:update_params) { { player_absence: { duration: 10 } } }

    context 'commissionerユーザーの場合' do
      before { login_as(commissioner_user) }

      it '200を返し離脱を更新する' do
        patch "#{base_path}/#{player_absence.id}", params: update_params, as: :json
        expect(response).to have_http_status(:ok)
        expect(player_absence.reload.duration).to eq(10)
      end
    end

    context '一般ユーザーの場合' do
      before { login_as(player_user) }

      it '403を返す' do
        patch "#{base_path}/#{player_absence.id}", params: update_params, as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end

    context '未認証の場合' do
      it '401を返す' do
        patch "#{base_path}/#{player_absence.id}", params: update_params, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/commissioner/.../player_absences/:id' do
    let!(:player_absence) { create(:player_absence, team_membership: team_membership, season: season) }

    context 'commissionerユーザーの場合' do
      before { login_as(commissioner_user) }

      it '204を返し離脱を削除する' do
        expect {
          delete "#{base_path}/#{player_absence.id}"
        }.to change(PlayerAbsence, :count).by(-1)
        expect(response).to have_http_status(:no_content)
      end
    end

    context '一般ユーザーの場合' do
      before { login_as(player_user) }

      it '403を返す' do
        delete "#{base_path}/#{player_absence.id}"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context '未認証の場合' do
      it '401を返す' do
        delete "#{base_path}/#{player_absence.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
