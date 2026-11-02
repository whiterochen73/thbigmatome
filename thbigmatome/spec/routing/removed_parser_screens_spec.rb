require "rails_helper"

# Test Basis: cmd_1795（Operator 決定 2026-11-01）。パーサー経由の画面（レビュー・試合記録・試合詳細・オーダー確認・
#   成績集計・旧ホーム）と、それだけが使う API・集計クラスを削除した。復活させる変更が入ったらここが落ちる。
#   DB の表（game_records・at_bat_records など）と、Clubhouse が読む GET /games・/games/:id・internal export は残す。
RSpec.describe "削除したパーサー経由の画面の API とクラス" do
  def recognizes?(path, method)
    Rails.application.routes.recognize_path(path, method: method)
    true
  rescue ActionController::RoutingError
    false
  end

  describe "route" do
    [
      [ :get, "/api/v1/home/summary" ],
      [ :get, "/api/v1/stats/batting" ],
      [ :get, "/api/v1/stats/pitching" ],
      [ :get, "/api/v1/stats/team" ],
      [ :get, "/api/v1/game_records" ],
      [ :get, "/api/v1/game_records/1" ],
      [ :post, "/api/v1/game_records/1/confirm" ],
      [ :patch, "/api/v1/at_bat_records/1" ],
      [ :put, "/api/v1/at_bat_records/1" ],
      [ :post, "/api/v1/games" ],
      [ :post, "/api/v1/games/1/confirm" ],
      [ :get, "/api/v1/games/1/lineup" ],
      [ :post, "/api/v1/games/1/lineup" ],
      [ :patch, "/api/v1/games/1/lineup" ]
    ].each do |method, path|
      it "#{method.to_s.upcase} #{path} は存在しない" do
        expect(recognizes?(path, method)).to be(false)
      end
    end

    # 遷移先のコントローラが無くても recognize_path は失敗するので、route 表そのものも見る
    it "route 表に home・stats・game_records・at_bat_records・オーダーのコントローラを向く行が無い" do
      controllers = Rails.application.routes.routes.filter_map { |r| r.defaults[:controller] }.uniq
      removed = %w[api/v1/home api/v1/stats api/v1/game_records api/v1/at_bat_records api/v1/game_lineup_entries]
      expect(controllers & removed).to eq([])
    end

    it "games の route は index と show だけ" do
      actions = Rails.application.routes.routes
                     .select { |r| r.defaults[:controller] == "api/v1/games" }
                     .map { |r| r.defaults[:action] }
      expect(actions).to contain_exactly("index", "show")
    end

    # 全部が false になる壊れ方（prefix の取り違えなど）を見逃さないための対照
    [
      [ :get, "/api/v1/games" ],
      [ :get, "/api/v1/games/1" ],
      [ :get, "/api/v1/internal/games" ]
    ].each do |method, path|
      it "#{method.to_s.upcase} #{path} は残っている（Clubhouse が読む）" do
        expect(recognizes?(path, method)).to be(true)
      end
    end
  end

  describe "クラス" do
    %w[
      Api::V1::HomeController
      Api::V1::StatsController
      Api::V1::GameRecordsController
      Api::V1::AtBatRecordsController
      Api::V1::GameLineupEntriesController
      BattingStatsCalculator
      PitchingStatsCalculator
      TeamStatsCalculator
      GameLineupEntrySerializer
    ].each do |name|
      it "#{name} は存在しない" do
        expect { name.constantize }.to raise_error(NameError)
      end
    end
  end
end
