require "rails_helper"

# シーズンに題は付けない。列 name は NOT NULL のまま残すので、作る時にチーム名を入れる
RSpec.describe Season, type: :model do
  describe "name の既定値" do
    let(:team) { create(:team, name: "豊玉シャークス") }

    it "name を渡さずに作ると、チーム名が入る" do
      season = Season.create!(team: team, current_date: Date.new(2026, 4, 1))

      expect(season.name).to eq("豊玉シャークス")
    end

    it "name が空文字でも、チーム名が入る" do
      season = Season.create!(team: team, name: "", current_date: Date.new(2026, 4, 1))

      expect(season.name).to eq("豊玉シャークス")
    end

    it "既に入っている name は上書きしない" do
      season = Season.create!(team: team, name: "既存の題", current_date: Date.new(2026, 4, 1))

      expect(season.name).to eq("既存の題")
    end

    it "作った後にチーム名が変わっても、既存のシーズンの name は書き換えない" do
      season = Season.create!(team: team, current_date: Date.new(2026, 4, 1))
      team.update!(name: "改名後")

      expect(season.reload.name).to eq("豊玉シャークス")
      expect(season.valid?).to be(true)
    end

    it "name を空にして保存しても検証は通る（題は必須ではない）" do
      season = Season.create!(team: team, current_date: Date.new(2026, 4, 1))
      season.name = ""

      expect(season).to be_valid
    end
  end
end
