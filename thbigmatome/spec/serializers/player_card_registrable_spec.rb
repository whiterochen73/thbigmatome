require "rails_helper"

# 選手のカードの一覧（GET /player_cards）が、登録画面で選べるかを判断できる値を返す（cmd_1893/subtask_1893e）
RSpec.describe "PlayerCardSerializer の現行・使用不可の値" do
  it "card_set_current と official_use_prohibited を返す" do
    cur = create(:player_card, card_set: create(:card_set), official_use_prohibited: true)
    old = create(:player_card, card_set: create(:card_set, is_current: false))
    a = PlayerCardSerializer.new(cur).as_json
    b = PlayerCardSerializer.new(old).as_json
    expect(a).to include(card_set_current: true, official_use_prohibited: true)
    expect(b).to include(card_set_current: false, official_use_prohibited: false)
  end
end
