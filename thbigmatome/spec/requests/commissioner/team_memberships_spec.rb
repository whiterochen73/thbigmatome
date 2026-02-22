require 'rails_helper'

RSpec.describe 'Commissioner::TeamMemberships', type: :request do
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
    "/api/v1/commissioner/leagues/#{league.id}/teams/#{team.id}/team_memberships"
  end

  describe 'GET /api/v1/commissioner/leagues/:league_id/teams/:team_id/team_memberships' do
    context 'commissionerユーザーの場合' do
      before { login_as(commissioner_user) }

      it '200を返す' do
        get base_path
        expect(response).to have_http_status(:ok)
      end

      it 'チームのメンバーシップ一覧を返す' do
        player1 = create(:player)
        player2 = create(:player)
        create(:team_membership, team: team, player: player1)
        create(:team_membership, team: team, player: player2)

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

  describe 'PATCH /api/v1/commissioner/leagues/:league_id/teams/:team_id/team_memberships/:id' do
    let!(:team_membership) { create(:team_membership, team: team) }
    let(:update_params) { { team_membership: { squad: 'first' } } }

    context 'commissionerユーザーの場合' do
      before { login_as(commissioner_user) }

      it '200を返しメンバーシップを更新する' do
        patch "#{base_path}/#{team_membership.id}", params: update_params, as: :json
        expect(response).to have_http_status(:ok)
        expect(team_membership.reload.squad).to eq('first')
      end
    end

    context '一般ユーザーの場合' do
      before { login_as(player_user) }

      it '403を返す' do
        patch "#{base_path}/#{team_membership.id}", params: update_params, as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end

    context '未認証の場合' do
      it '401を返す' do
        patch "#{base_path}/#{team_membership.id}", params: update_params, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/commissioner/leagues/:league_id/teams/:team_id/team_memberships/:id' do
    let!(:team_membership) { create(:team_membership, team: team) }

    context 'commissionerユーザーの場合' do
      before { login_as(commissioner_user) }

      it '204を返しメンバーシップを削除する' do
        expect {
          delete "#{base_path}/#{team_membership.id}"
        }.to change(TeamMembership, :count).by(-1)
        expect(response).to have_http_status(:no_content)
      end
    end

    context '一般ユーザーの場合' do
      before { login_as(player_user) }

      it '403を返す' do
        delete "#{base_path}/#{team_membership.id}"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context '未認証の場合' do
      it '401を返す' do
        delete "#{base_path}/#{team_membership.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
