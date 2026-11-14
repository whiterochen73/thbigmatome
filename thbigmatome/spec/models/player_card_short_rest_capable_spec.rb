require "rails_helper"

# 【中4日可】の固有特徴（unique_traits の文面）。Operator 2026-11-14: 中4日で先発できる＝連続中4日のペナルティを受けない。
RSpec.describe PlayerCard, "#short_rest_capable?" do
  it "unique_traits に【中4日可】を含むカードは true" do
    expect(build(:player_card, unique_traits: "【中4日可】").short_rest_capable?).to be true
    expect(build(:player_card, unique_traits: "【他の特徴】\n【中4日可】").short_rest_capable?).to be true
  end

  it "含まない・空・nil は false" do
    expect(build(:player_card, unique_traits: "【オープナー可】").short_rest_capable?).to be false
    expect(build(:player_card, unique_traits: "").short_rest_capable?).to be false
    expect(build(:player_card, unique_traits: nil).short_rest_capable?).to be false
  end

  it "括弧なしの「中4日可」だけでは false（特徴の記法【】に限る）" do
    expect(build(:player_card, unique_traits: "中4日可").short_rest_capable?).to be false
  end
end
