require "rails_helper"

# Test Basis: AMB-11（context/thbig-bench-rule-adjudications.md、Operator 裁定 2026-09-12）「通常 143 試合という総数は、日程の完全性チェック
# （試合日が 143 あるか）に使える」。cmd_1802 で日程マスタが 144 のまま作成時から気づかれなかった事実を受けた検算。
RSpec.describe ScheduleMasterCheck do
  def schedule_with(types)
    Schedule.create!(name: "検算用", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 12, 31)).tap do |s|
      types.each_with_index { |type, i| s.schedule_details.create!(date: Date.new(2026, 1, 1) + i, date_type: type) }
    end
  end

  it "規定は 143（通常 125 + 交流戦 18）" do
    expect(described_class::EXPECTED_REGULAR_GAME_DAYS).to eq(143)
  end

  it "レギュラー（通常・交流戦）の試合日だけ数える。予備日・交流戦予備日・移動日・休日・プレーオフ日は数えない" do
    s = schedule_with(%w[game_day interleague_game_day reserve_day interleague_reserve_day travel_day no_game_day playoff_day])

    expect(described_class.regular_game_days(s)).to eq(2)
  end

  it "ちょうど 143 なら警告なし・verify! も通る" do
    s = schedule_with(Array.new(125, "game_day") + Array.new(18, "interleague_game_day") + %w[reserve_day playoff_day])

    expect(described_class.warnings(s)).to eq([])
    expect { described_class.verify!(s) }.not_to raise_error
  end

  it "142 でも 144 でも警告を出し、verify! は止める" do
    [ 142, 144 ].each do |n|
      s = schedule_with(Array.new(n, "game_day")).tap { |x| x.update!(name: "検算用#{n}") }

      expect(described_class.warnings(s).first).to include("#{n} 日", "規定は 143 日", "検算用#{n}")
      expect { described_class.verify!(s) }.to raise_error(described_class::Mismatch, /#{n} 日/)
    end
  end

  it "日程表が空（0 日）でも警告" do
    expect(described_class.warnings(schedule_with([])).first).to include("0 日")
  end
end
