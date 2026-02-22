require 'rails_helper'

RSpec.describe 'Commissioner::TeamManagers', type: :request do
  let(:password) { 'password123' }
  let(:commissioner_user) { create(:user, :commissioner, password: password) }
  let(:player_user) { create(:user, password: password) }
  let!(:league) { create(:league) }
  let!(:team) { create(:team) }
  let!(:league_membership) { create(:league_membership, league: league, team: team) }

  def login_as(user)
    post '/api/v1/auth/login', params: { name: user.name, password: password }, as: :json
  end

  def base_path
    "/api/v1/commissioner/leagues/#{league.id}/teams/#{team.id}/team_managers"
  end

  describe 'GET /api/v1/commissioner/leagues/:league_id/teams/:team_id/team_managers' do
    context 'commissionerユーザーの場合' do
      before { login_as(commissioner_user) }

      it '200を返す' do
        get base_path
        expect(response).to have_http_status(:ok)
      end

      it 'チームの監督一覧を返す' do
        manager1 = create(:manager)
        manager2 = create(:manager)
        create(:team_manager, team: team, manager: manager1, role: :director)
        create(:team_manager, team: team, manager: manager2, role: :coach)

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

  describe 'POST /api/v1/commissioner/leagues/:league_id/teams/:team_id/team_managers' do
    let!(:manager) { create(:manager) }
    let(:valid_params) { { team_manager: { manager_id: manager.id, role: 'director' } } }

    context 'commissionerユーザーの場合' do
      before { login_as(commissioner_user) }

      it '201を返し監督を割り当てる' do
        expect {
          post base_path, params: valid_params, as: :json
        }.to change(TeamManager, :count).by(1)
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

  describe 'PATCH /api/v1/commissioner/leagues/:league_id/teams/:team_id/team_managers/:id' do
    let!(:team_manager) { create(:team_manager, team: team, role: :director) }
    let(:update_params) { { team_manager: { role: 'coach' } } }

    context 'commissionerユーザーの場合' do
      before { login_as(commissioner_user) }

      it '200を返し監督情報を更新する' do
        patch "#{base_path}/#{team_manager.id}", params: update_params, as: :json
        expect(response).to have_http_status(:ok)
        expect(team_manager.reload.role).to eq('coach')
      end
    end

    context '一般ユーザーの場合' do
      before { login_as(player_user) }

      it '403を返す' do
        patch "#{base_path}/#{team_manager.id}", params: update_params, as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end

    context '未認証の場合' do
      it '401を返す' do
        patch "#{base_path}/#{team_manager.id}", params: update_params, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/commissioner/leagues/:league_id/teams/:team_id/team_managers/:id' do
    let!(:team_manager) { create(:team_manager, team: team) }

    context 'commissionerユーザーの場合' do
      before { login_as(commissioner_user) }

      it '204を返し監督を削除する' do
        expect {
          delete "#{base_path}/#{team_manager.id}"
        }.to change(TeamManager, :count).by(-1)
        expect(response).to have_http_status(:no_content)
      end
    end

    context '一般ユーザーの場合' do
      before { login_as(player_user) }

      it '403を返す' do
        delete "#{base_path}/#{team_manager.id}"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context '未認証の場合' do
      it '401を返す' do
        delete "#{base_path}/#{team_manager.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
