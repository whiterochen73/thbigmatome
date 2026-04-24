require "rails_helper"
require "rake"
require "tmpdir"
require "csv"

RSpec.describe "thbigmatome:export_players" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("thbigmatome:export_players")
  end

  let(:tmp_dir) { Dir.mktmpdir }

  before do
    Rake::Task["thbigmatome:export_players"].reenable
    SharedSyncLog.delete_all if defined?(SharedSyncLog)
  end

  after do
    FileUtils.rm_rf(tmp_dir)
  end

  it "exports players, card_sets, and player_cards CSVs and records sync logs" do
    player = Player.create!(name: "博麗 霊夢", number: "06", series: "touhou", short_name: "霊夢")
    card_set = CardSet.create!(name: "2025THBIG", year: 2025, set_type: "annual", series: "touhou")
    PlayerCard.create!(
      player: player,
      card_set: card_set,
      card_type: "pitcher",
      is_pitcher: true,
      is_relief_only: false,
      is_closer: false,
      speed: 1,
      bunt: 7,
      steal_start: 1,
      steal_end: 1,
      injury_rate: 5,
      starter_stamina: 6,
      relief_stamina: 1,
      batting_table: [],
      pitching_table: [],
      irc_macro_name: "reimu",
      irc_display_name: "霊夢"
    )

    expect {
      Rake::Task["thbigmatome:export_players"].invoke(tmp_dir)
    }.to change(SharedSyncLog, :count).by(3)

    players_csv = File.join(tmp_dir, "players.csv")
    card_sets_csv = File.join(tmp_dir, "card_sets.csv")
    player_cards_csv = File.join(tmp_dir, "player_cards.csv")

    expect(File).to exist(players_csv)
    expect(File).to exist(card_sets_csv)
    expect(File).to exist(player_cards_csv)

    expect(CSV.read(players_csv, headers: true).length).to eq(1)
    expect(CSV.read(card_sets_csv, headers: true).length).to eq(1)
    expect(CSV.read(player_cards_csv, headers: true).length).to eq(1)

    expect(SharedSyncLog.where(resource_type: "players", status: "success").count).to eq(1)
    expect(SharedSyncLog.where(resource_type: "card_sets", status: "success").count).to eq(1)
    expect(SharedSyncLog.where(resource_type: "player_cards", status: "success").count).to eq(1)
  end
end
