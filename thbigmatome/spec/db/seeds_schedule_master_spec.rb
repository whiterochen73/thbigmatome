require "rails_helper"

# Test Basis: cmd_1802 段3。db/seeds.rb のペナント日程表（schedule_id: 1 の 222 行）はレギュラーの試合日が 143 で、2016-09-26 は予備日。
# seed の本体は他の表（ユーザー・チーム等）も書くので、ここでは seeds.rb の日程の定数だけを読んで数える。
RSpec.describe "db/seeds.rb のペナント日程表" do
  let(:details) do
    File.read(Rails.root.join("db/seeds.rb")).scan(/\{ schedule_id: 1, date: '(\d{4}-\d{2}-\d{2})', date_type: '(\w+)'/).to_h
  end

  it "222 日分ある（2016-03-25〜2016-11-01）" do
    expect(details.size).to eq(222)
    expect(details.keys.min).to eq("2016-03-25")
    expect(details.keys.max).to eq("2016-11-01")
  end

  it "レギュラー（通常・交流戦）の試合日が 143 日（通常 125 + 交流戦 18）" do
    counts = details.values.tally

    expect(counts["game_day"]).to eq(125)
    expect(counts["interleague_game_day"]).to eq(18)
    expect(details.values.count { |t| SeasonGameProgress::REGULAR_DATE_TYPES.include?(t) }).to eq(ScheduleMasterCheck::EXPECTED_REGULAR_GAME_DAYS)
  end

  it "2016-09-26 は予備日（余分だった最後の通常試合日）" do
    expect(details["2016-09-26"]).to eq("reserve_day")
  end

  it "seed が検算を呼ぶ（合わなければ止まる）" do
    expect(File.read(Rails.root.join("db/seeds.rb"))).to include("ScheduleMasterCheck.verify!")
  end
end
