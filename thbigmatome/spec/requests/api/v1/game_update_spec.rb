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

  # Test Basis: cmd_1783 subtask_1783j（Operator 2026-10-31）。予告先発・対戦設定で、試合日（実日付）・
  # 大まかな開始時刻（30 分刻み）・開催球場（IRC のチャンネル）を選べる。stadium（ゲーム内の球場）とは別の列
  context "実日付・開始時刻・開催球場（real_date / real_start_time / venue）" do
    def put_game(params)
      put "/api/v1/game/#{schedule.id}", params: params, as: :json
    end

    it "既存の試合日は 3 列とも null で返る" do
      get "/api/v1/game/#{schedule.id}"
      expect(response.parsed_body).to include("real_date" => nil, "real_start_time" => nil, "venue" => nil)
    end

    it "PUT で保存した 3 列が、GET /game/:id で同じ値で返る（stadium とは別に保存される）" do
      put_game(real_date: "2026-11-03", real_start_time: "21:30", venue: "ch3", stadium: "甲子園")
      expect(response).to have_http_status(:ok)
      expect(schedule.reload).to have_attributes(
        real_date: Date.new(2026, 11, 3), real_start_time: "21:30", venue: "ch3", stadium: "甲子園"
      )

      get "/api/v1/game/#{schedule.id}"
      expect(response.parsed_body).to include(
        "real_date" => "2026-11-03", "real_start_time" => "21:30", "venue" => "ch3", "stadium" => "甲子園"
      )
    end

    it "null を送ると null に戻せる" do
      put_game(real_date: "2026-11-03", real_start_time: "21:30", venue: "tlb")
      put_game(real_date: nil, real_start_time: nil, venue: nil)
      expect(response).to have_http_status(:ok)
      expect(schedule.reload).to have_attributes(real_date: nil, real_start_time: nil, venue: nil)
    end

    it "3 列を送らない更新は、保存済みの値を変えない" do
      put_game(real_date: "2026-11-03", real_start_time: "21:30", venue: "ch1")
      put_game(score: 1)
      expect(schedule.reload).to have_attributes(real_date: Date.new(2026, 11, 3), real_start_time: "21:30", venue: "ch1")
    end

    it "実日付の空文字は null として保存する（日付列の既存の挙動）" do
      put_game(real_date: "")
      expect(response).to have_http_status(:ok)
      expect(schedule.reload.real_date).to be_nil
    end

    describe "real_start_time（30 分刻み。分は 00 か 30 のみ）" do
      %w[00:00 00:30 09:30 12:00 21:30 23:30].each do |value|
        it "#{value.inspect} は通る" do
          put_game(real_start_time: value)
          expect(response).to have_http_status(:ok)
          expect(schedule.reload.real_start_time).to eq(value)
        end
      end

      [ "21:15", "24:00", "24:30", "9:30", "21:30:00", "21:3", "2130", "abc", "21:45", "-1:30", " 21:30", "21:30\n" ].each do |value|
        it "#{value.inspect} は 422 で弾き、保存済みの値を変えない" do
          schedule.update!(real_start_time: "20:00")
          put_game(real_start_time: value)
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body["errors"]).not_to be_empty
          expect(schedule.reload.real_start_time).to eq("20:00")
        end
      end

      it "空文字・空白だけは「未選択」として null で保存する（弾かない。日付列が空文字を null にするのと揃える）" do
        schedule.update!(real_start_time: "20:00")
        put_game(real_start_time: "")
        expect(response).to have_http_status(:ok)
        expect(schedule.reload.real_start_time).to be_nil

        schedule.update!(real_start_time: "20:00")
        put_game(real_start_time: "  ")
        expect(response).to have_http_status(:ok)
        expect(schedule.reload.real_start_time).to be_nil
      end
    end

    describe "venue（ch1〜ch5 と tlb）" do
      %w[ch1 ch2 ch3 ch4 ch5 tlb].each do |value|
        it "#{value.inspect} は通る" do
          put_game(venue: value)
          expect(response).to have_http_status(:ok)
          expect(schedule.reload.venue).to eq(value)
        end
      end

      %w[ch0 ch6 TLB Ch1 CH1 ch10 チャンネル1 TLB球場].push(" ch1", "ch1 ").each do |value|
        it "#{value.inspect} は 422 で弾き、保存済みの値を変えない" do
          schedule.update!(venue: "ch2")
          put_game(venue: value)
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body["errors"]).not_to be_empty
          expect(schedule.reload.venue).to eq("ch2")
        end
      end

      it "空文字は「未選択」として null で保存する" do
        schedule.update!(venue: "ch2")
        put_game(venue: "")
        expect(response).to have_http_status(:ok)
        expect(schedule.reload.venue).to be_nil
      end
    end

    it "3 列の更新は投手の判定の作り直しを動かさない（得点・ノーゲームが変わらないため）" do
      stub_rebuild_failure(RuntimeError.new("should not run"))
      put_game(real_date: "2026-11-03", real_start_time: "21:30", venue: "ch3")
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["warnings"]).to eq([])
    end
  end

  # Test Basis: cmd_1783 subtask_1783j 要望 2（Operator 2026-10-31）。試合ログの原文を保存する（解析はしない）。上限 1MB（バイト数）
  context "試合ログ（game_log）" do
    def put_game(params)
      put "/api/v1/game/#{schedule.id}", params: params, as: :json
    end

    let(:limit) { 1_048_576 }

    it "既存の試合日は null で返る" do
      get "/api/v1/game/#{schedule.id}"
      expect(response.parsed_body).to include("game_log" => nil)
    end

    it "PUT で保存したログが、GET /game/:id で改行・日本語ごと同じ内容で返る" do
      log = "[21:30] <ちとせ> 試合開始\r\n[21:31] <芳乃> プレイボール\n"
      put_game(game_log: log)
      expect(response).to have_http_status(:ok)
      expect(schedule.reload.game_log).to eq(log)

      get "/api/v1/game/#{schedule.id}"
      expect(response.parsed_body["game_log"]).to eq(log)
    end

    # 運営（コミッショナー）が試合が正しく行われたかを検証する原文なので、サーバは一切加工しない
    describe "原文のまま保存・返却する（加工しない）" do
      [
        [ "前後の空白", "  [21:30] 試合開始  " ],
        [ "前後の空行", "\n\n[21:30] 試合開始\n\n\n" ],
        [ "タブ", "[21:30]\t<ちとせ>\t試合開始" ],
        [ "全角文字・全角空白", "［２１：３０］　＜芳乃＞　ホームラン！！　東方ＢＩＧ野球" ],
        [ "CRLF と LF の混在", "a\r\nb\nc\r\n" ],
        [ "連続する空白と空行", "a    b\n\n\n\nc" ],
        [ "空白だけ（空文字ではないので null にしない）", "   \n\t " ],
        [ "改行だけ", "\n" ],
        [ "色指定などの制御文字", "\u0003\u0004\e[0m本文" ],
        [ "絵文字・サロゲートペア", "😀 𠮷野家" ],
        [ "NFC/NFD の違う文字（正規化しない）", "ガ".unicode_normalize(:nfd) + "ガ" ]
      ].each do |name, log|
        it "#{name}: PUT したとおりに DB に入り、GET で同じバイト列で返る" do
          put_game(game_log: log)
          expect(response).to have_http_status(:ok)
          expect(schedule.reload.game_log.b).to eq(log.b)

          get "/api/v1/game/#{schedule.id}"
          expect(response.parsed_body["game_log"].b).to eq(log.b)
        end
      end
    end

    it "null を送ると null に戻せる" do
      put_game(game_log: "abc")
      put_game(game_log: nil)
      expect(response).to have_http_status(:ok)
      expect(schedule.reload.game_log).to be_nil
    end

    it "空文字は null として保存する（弾かない）" do
      put_game(game_log: "abc")
      put_game(game_log: "")
      expect(response).to have_http_status(:ok)
      expect(schedule.reload.game_log).to be_nil
    end

    it "ログを送らない更新は、保存済みのログを変えない" do
      put_game(game_log: "abc")
      put_game(score: 1)
      expect(schedule.reload.game_log).to eq("abc")
    end

    it "ちょうど 1_048_576 バイトは通る" do
      log = "a" * limit
      put_game(game_log: log)
      expect(response).to have_http_status(:ok)
      expect(schedule.reload.game_log.bytesize).to eq(limit)
    end

    it "1_048_577 バイトは 422 で弾き、保存済みのログを変えない" do
      schedule.update!(game_log: "元のログ")
      put_game(game_log: "a" * (limit + 1))
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"].join).to include("game_log").or include("バイト")
      expect(schedule.reload.game_log).to eq("元のログ")
    end

    it "上限は文字数ではなくバイト数で数える（日本語 1 文字 = 3 バイト。349_525 文字 = 1_048_575 バイトは通り、349_526 文字 = 1_048_578 バイトは弾く）" do
      put_game(game_log: "あ" * 349_525)
      expect(response).to have_http_status(:ok)

      put_game(game_log: "あ" * 349_526)
      expect(response).to have_http_status(:unprocessable_content)
      expect(schedule.reload.game_log.bytesize).to eq(1_048_575)
    end

    it "ログの更新は投手の判定の作り直しを動かさない" do
      stub_rebuild_failure(RuntimeError.new("should not run"))
      put_game(game_log: "abc")
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["warnings"]).to eq([])
    end
  end
end
