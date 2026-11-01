require "rails_helper"

# Test Basis: cmd_1784 段4。日程マスタにも種別 no_game は作らない（ノーゲームは真偽値）
RSpec.describe ScheduleDetail do
  let(:schedule) { Schedule.create!(name: "マスタ", start_date: Date.new(2026, 4, 1), end_date: Date.new(2026, 4, 30)) }

  it "種別 no_game は断り、ほかの種別は通す" do
    expect(ScheduleDetail.new(schedule: schedule, date: Date.new(2026, 4, 1), date_type: "no_game")).not_to be_valid
    expect(ScheduleDetail.new(schedule: schedule, date: Date.new(2026, 4, 1), date_type: "reserve_day")).to be_valid
  end

  it "種別を変える時だけ検査する: 既に no_game のマスタ行も、種別以外の列の保存は止めない。種別を no_game へ変えるのは断る" do
    detail = schedule.schedule_details.create!(date: Date.new(2026, 4, 2), date_type: "game_day")
    expect(detail.update(date_type: "no_game")).to be false
    detail.update_columns(date_type: "no_game") # 移行前に混ざっていたマスタ行
    expect(detail.update(priority: 3)).to be true
  end
end
