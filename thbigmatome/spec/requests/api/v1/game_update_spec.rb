require "rails_helper"

# Test Basis: cmd_1775 第1段 QC の残り(2)（得点保存時の判定作り直しが落ちても、得点の保存ごと取り消さない）
RSpec.describe "PUT /api/v1/game/:id（得点保存と投手判定の作り直し）", type: :request, pitcher_fatigue: true do
  include_context "authenticated user"

  let(:team_and_season) { create_team_with_season }
  let(:team) { team_and_season[0] }
  let(:season) { team_and_season[1] }
  let!(:pitcher) { create_card_pitcher(team: team, starter_stamina: 7)[0] }
  let!(:schedule) { create_schedule(season, "2026-06-10", score: 2, opponent_score: 5) }
  let!(:state) { create_start(team: team, pitcher: pitcher, date: "2026-06-10", innings: 9.0, category: "long_loss") }

  def stub_rebuild_failure(error)
    rebuilder = instance_double(PitcherResultCategoryRebuilder)
    allow(rebuilder).to receive(:rebuild_for_schedule).and_raise(error)
    allow(PitcherResultCategoryRebuilder).to receive(:new).and_return(rebuilder)
  end

  context "作り直しが成功する通常ケース" do
    it "警告なし（warnings は空配列）で、得点も判定も更新される" do
      put "/api/v1/game/#{schedule.id}", params: { score: 6, opponent_score: 5 }, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["warnings"]).to eq([])
      expect(schedule.reload.score).to eq(6)
      expect(state.reload.result_category).to eq("normal")
    end
  end

  context "作り直しが想定外のエラーで落ちた時" do
    before { stub_rebuild_failure(RuntimeError.new("boom")) }

    it "得点は保存される（200）" do
      put "/api/v1/game/#{schedule.id}", params: { score: 6, opponent_score: 5 }, as: :json
      expect(response).to have_http_status(:ok)
      expect(schedule.reload).to have_attributes(score: 6, opponent_score: 5)
    end

    it "応答の warnings に、判定の作り直しに失敗した旨と後で作り直しが必要な旨を含める" do
      put "/api/v1/game/#{schedule.id}", params: { score: 6, opponent_score: 5 }, as: :json
      warnings = response.parsed_body["warnings"]
      expect(warnings.size).to eq(1)
      expect(warnings.first).to include("判定の作り直しに失敗")
      expect(warnings.first).to include("後で作り直し")
    end

    it "失敗はログに残す（試合概要 id・例外クラス・メッセージ）" do
      allow(Rails.logger).to receive(:error)
      put "/api/v1/game/#{schedule.id}", params: { score: 6, opponent_score: 5 }, as: :json
      expect(Rails.logger).to have_received(:error).with(/PitcherResultCategoryRebuilder.*season_schedule_id=#{schedule.id}.*RuntimeError.*boom/m)
    end

    it "投手の登板記録は作り直されないまま残る（古い区分のまま。後で rake で直せる）" do
      put "/api/v1/game/#{schedule.id}", params: { score: 6, opponent_score: 5 }, as: :json
      expect(state.reload.result_category).to eq("long_loss")
    end
  end

  context "作り直しの途中で DB エラーが起きた時（PostgreSQL はトランザクションが中断状態になる）" do
    it "得点の保存は取り消されず、応答も 200 + 警告になる。作り直しの途中の書き込みは戻る" do
      rebuilder = instance_double(PitcherResultCategoryRebuilder)
      allow(rebuilder).to receive(:rebuild_for_schedule) do
        state.update_columns(result_category: "ko")
        ActiveRecord::Base.connection.execute("SELECT * FROM table_that_does_not_exist")
      end
      allow(PitcherResultCategoryRebuilder).to receive(:new).and_return(rebuilder)

      put "/api/v1/game/#{schedule.id}", params: { score: 6, opponent_score: 5 }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["warnings"].first).to include("判定の作り直しに失敗")
      expect(schedule.reload.score).to eq(6)
      expect(state.reload.result_category).to eq("long_loss")
    end
  end

  context "得点以外の更新" do
    it "判定の作り直しは動かない（失敗の警告も出ない）" do
      stub_rebuild_failure(RuntimeError.new("should not run"))
      put "/api/v1/game/#{schedule.id}", params: { stadium: "どこか" }, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["warnings"]).to eq([])
    end
  end

  context "モデル直接" do
    it "失敗時は pitcher_rebuild_error に例外を持ち、保存は成功扱い（save が true）" do
      stub_rebuild_failure(RuntimeError.new("boom"))
      expect(schedule.update(score: 6)).to be(true)
      expect(schedule.pitcher_rebuild_error).to be_a(RuntimeError)
    end
  end

  # Test Basis: cmd_1775 第3段 E12。試合結果でノーゲームを選べる（GameResult.vue → PUT /game/:id）
  context "ノーゲーム（no_game）" do
    it "PUT で no_game を保存し、GET /game/:id が返す（既定は false）" do
      get "/api/v1/game/#{schedule.id}"
      expect(response.parsed_body["no_game"]).to be(false)

      put "/api/v1/game/#{schedule.id}", params: { no_game: true }, as: :json
      expect(response).to have_http_status(:ok)
      expect(schedule.reload.no_game).to be(true)

      get "/api/v1/game/#{schedule.id}"
      expect(response.parsed_body["no_game"]).to be(true)
    end

    it "ノーゲームにすると、登板記録の区分が no_game に作り直される（得点は変えなくてよい）" do
      expect(state.result_category).to eq("long_loss")
      put "/api/v1/game/#{schedule.id}", params: { no_game: true }, as: :json
      expect(response.parsed_body["warnings"]).to eq([])
      expect(state.reload.result_category).to eq("no_game")
      expect(state.fatigue_p_used).to be_nil
    end

    it "ノーゲームを外すと、得点から区分を作り直す（負け・長いイニングなら long_loss に戻る）" do
      put "/api/v1/game/#{schedule.id}", params: { no_game: true }, as: :json
      put "/api/v1/game/#{schedule.id}", params: { no_game: false }, as: :json
      expect(state.reload.result_category).to eq("long_loss")
    end

    it "no_game の保存は得点の保存と同時でもよい（得点は残り、区分は no_game）" do
      put "/api/v1/game/#{schedule.id}", params: { score: 6, opponent_score: 5, no_game: true }, as: :json
      expect(schedule.reload).to have_attributes(score: 6, opponent_score: 5, no_game: true)
      expect(state.reload.result_category).to eq("no_game")
    end
  end
end
