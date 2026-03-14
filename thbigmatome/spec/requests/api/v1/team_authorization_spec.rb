require "rails_helper"

RSpec.describe "TeamAccessible 認可チェック", type: :request do
  let(:password) { "password123" }
  let(:owner) { create(:user, password: password) }
  let(:other_user) { create(:user, password: password) }
  let(:commissioner) { create(:user, :commissioner, password: password) }
  let(:team) { create(:team, user: owner) }

  def login_as(user)
    post "/api/v1/auth/login", params: { name: user.name, password: password }, as: :json
  end

  shared_examples "自チーム監督はアクセス可" do |method, url_proc|
    it "自チーム監督: 200（またはエラーなし403）" do
      login_as(owner)
      send(method, instance_exec(&url_proc), as: :json)
      expect(response).not_to have_http_status(:forbidden)
    end
  end

  shared_examples "コミッショナーはアクセス可" do |method, url_proc|
    it "コミッショナー: 200（またはエラーなし403）" do
      login_as(commissioner)
      send(method, instance_exec(&url_proc), as: :json)
      expect(response).not_to have_http_status(:forbidden)
    end
  end

  shared_examples "他チームユーザーは403" do |method, url_proc|
    it "他チームユーザー: 403" do
      login_as(other_user)
      send(method, instance_exec(&url_proc), as: :json)
      expect(response).to have_http_status(:forbidden)
    end
  end

  shared_examples "未認証は401" do |method, url_proc|
    it "未認証: 401" do
      send(method, instance_exec(&url_proc), as: :json)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  shared_examples "チームアクセス認可" do |method, url_proc|
    include_examples "自チーム監督はアクセス可", method, url_proc
    include_examples "コミッショナーはアクセス可", method, url_proc
    include_examples "他チームユーザーは403", method, url_proc
    include_examples "未認証は401", method, url_proc
  end

  describe "TeamsController" do
    describe "GET /api/v1/teams/:id" do
      include_examples "チームアクセス認可", :get, -> { "/api/v1/teams/#{team.id}" }
    end

    describe "PATCH /api/v1/teams/:id" do
      include_examples "チームアクセス認可", :patch, -> { "/api/v1/teams/#{team.id}" }
    end
  end

  describe "TeamSeasonsController" do
    describe "GET /api/v1/teams/:team_id/season" do
      include_examples "チームアクセス認可", :get, -> { "/api/v1/teams/#{team.id}/season" }
    end
  end

  describe "TeamMembershipsController" do
    describe "GET /api/v1/teams/:team_id/team_memberships" do
      include_examples "チームアクセス認可", :get, -> { "/api/v1/teams/#{team.id}/team_memberships" }
    end
  end

  describe "LineupTemplatesController" do
    describe "GET /api/v1/teams/:team_id/lineup_templates" do
      include_examples "チームアクセス認可", :get, -> { "/api/v1/teams/#{team.id}/lineup_templates" }
    end
  end

  describe "GameLineupsController" do
    describe "GET /api/v1/teams/:team_id/game_lineup" do
      include_examples "チームアクセス認可", :get, -> { "/api/v1/teams/#{team.id}/game_lineup" }
    end
  end

  describe "SquadTextSettingsController" do
    describe "GET /api/v1/teams/:team_id/squad_text_settings" do
      include_examples "チームアクセス認可", :get, -> { "/api/v1/teams/#{team.id}/squad_text_settings" }
    end
  end

  describe "RosterChangesController" do
    describe "GET /api/v1/teams/:team_id/roster_changes" do
      include_examples "自チーム監督はアクセス可", :get, -> { "/api/v1/teams/#{team.id}/roster_changes?since=2025-01-01&season_id=999" }
      include_examples "コミッショナーはアクセス可", :get, -> { "/api/v1/teams/#{team.id}/roster_changes?since=2025-01-01&season_id=999" }
      include_examples "他チームユーザーは403", :get, -> { "/api/v1/teams/#{team.id}/roster_changes?since=2025-01-01&season_id=999" }
      include_examples "未認証は401", :get, -> { "/api/v1/teams/#{team.id}/roster_changes?since=2025-01-01&season_id=999" }
    end
  end

  describe "TeamPlayersController" do
    describe "GET /api/v1/teams/:team_id/team_players" do
      include_examples "チームアクセス認可", :get, -> { "/api/v1/teams/#{team.id}/team_players" }
    end
  end
end
