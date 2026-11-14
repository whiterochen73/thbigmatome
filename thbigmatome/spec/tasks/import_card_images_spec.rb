require "rails_helper"
require "rake"
require "csv"
require "tmpdir"

# Test Basis: cmd_1898 subtask_1898b §2。画像 rake が、添え字つきの行（基の Player に variant で付いたカード）に漏れず・取り違えず付き、
# CARD_CSV_PATH の既定が db/import/player_cards.csv であること。画像は 1x1 の PNG を使う（当て先の判定を見る）。
RSpec.describe "import:card_images" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("import:card_images")
  end

  let(:png) { Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==") }
  let!(:pm2027) { create(:card_set, name: "PM2027", set_type: "pm2027") }

  before { PlayerCardLocator.clear_cache! }

  def run_task(name, env = {})
    task = Rake::Task[name]
    task.reenable
    old = env.keys.to_h { |k| [ k, ENV[k] ] }
    env.each { |k, v| ENV[k] = v }
    out = StringIO.new
    original = $stdout
    $stdout = out
    begin
      task.invoke
    ensure
      $stdout = original
      old.each { |k, v| ENV[k] = v }
    end
    out.string
  end

  it "添え字つきの行は variant で基の Player のカードに付く。同じ種別の別 variant には付かない" do
    base = create(:player, name: "八雲 紫")
    wanted = create(:player_card, player: base, card_set: pm2027, variant: "筑紫野")
    other = create(:player_card, player: base, card_set: pm2027, variant: "飯能")

    Dir.mktmpdir do |dir|
      csv_path = File.join(dir, "player_cards.csv")
      CSV.open(csv_path, "w") do |csv|
        csv << %w[card_seq name card_source card_type variant base_player_name]
        csv << [ 433, "八雲 紫 (筑紫野)", "PM2027", "batter", "筑紫野", "八雲 紫" ]
      end
      FileUtils.mkdir_p(File.join(dir, "img", "PM2027", "trimmed"))
      File.binwrite(File.join(dir, "img", "PM2027", "trimmed", "p1_c1.png"), png)

      out = run_task("import:card_images", "CARD_IMAGE_DIR" => File.join(dir, "img"), "CARD_CSV_PATH" => csv_path)

      expect(out).to include("Attached:   1")
      expect(wanted.reload.card_image).to be_attached
      expect(other.reload.card_image).not_to be_attached
    end
  end

  it "CARD_CSV_PATH の既定は db/import/player_cards.csv（取り込みと同じ CSV）" do
    source = File.read(Rails.root.join("lib/tasks/import_card_images.rake"))

    expect(source).to include('Rails.root.join("db/import/player_cards.csv")')
    expect(source).not_to include("thbig-irc-parser/data/import")
  end

  it "import:card_image_targets は画像ファイル無しで全行の当て先を数える" do
    player = create(:player, name: "あ")
    create(:player_card, player: player, card_set: pm2027, irc_macro_name: "1")

    Dir.mktmpdir do |dir|
      csv_path = File.join(dir, "player_cards.csv")
      CSV.open(csv_path, "w") do |csv|
        csv << %w[card_seq name card_source card_type irc_macro_name speed bunt steal_start steal_end injury_rate]
        csv << [ 1, "あ", "PM2027", "batter", "1", 3, 5, 10, 10, 3 ]
        csv << [ 2, "いない", "PM2027", "batter", "2", 3, 5, 10, 10, 3 ]
      end

      out = run_task("import:card_image_targets", "CARD_CSV_PATH" => csv_path)

      expect(out).to include("rows=2 matched=1 missing=1 mismatched=0 collisions=0")
      expect(out).to include("MISSING card_seq=2")
    end
  end
end
