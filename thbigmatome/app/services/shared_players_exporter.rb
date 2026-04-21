require "csv"
require "fileutils"
require "json"

class SharedPlayersExporter
  PLAYER_HEADERS = %w[id name number series short_name created_at updated_at].freeze
  CARD_SET_HEADERS = %w[id name year set_type series is_outside_world created_at updated_at].freeze
  PLAYER_CARD_HEADERS = %w[
    id
    player_id
    card_set_id
    card_type
    is_pitcher
    is_relief_only
    is_closer
    handedness
    speed
    bunt
    steal_start
    steal_end
    injury_rate
    starter_stamina
    relief_stamina
    batting_table
    pitching_table
    unique_traits
    irc_macro_name
    irc_display_name
    card_label
    variant
    created_at
    updated_at
  ].freeze

  def self.default_output_dir
    Rails.root.parent.join("thbig-clubhouse", "db", "import", "shared_players")
  end

  attr_reader :output_dir

  def initialize(output_dir = nil)
    @output_dir = Pathname.new(output_dir.presence || self.class.default_output_dir)
  end

  def call
    FileUtils.mkdir_p(output_dir)

    {
      "players" => export_players,
      "card_sets" => export_card_sets,
      "player_cards" => export_player_cards
    }
  end

  private

  def export_players
    write_resource("players", PLAYER_HEADERS, output_dir.join("players.csv")) do |csv|
      Player.order(:id).find_each do |player|
        csv << [
          player.id,
          player.name,
          player.number,
          player.series,
          player.short_name,
          iso8601(player.created_at),
          iso8601(player.updated_at)
        ]
      end
    end
  end

  def export_card_sets
    write_resource("card_sets", CARD_SET_HEADERS, output_dir.join("card_sets.csv")) do |csv|
      CardSet.order(:id).find_each do |card_set|
        csv << [
          card_set.id,
          card_set.name,
          card_set.year,
          card_set.set_type,
          card_set.series,
          card_set.is_outside_world,
          iso8601(card_set.created_at),
          iso8601(card_set.updated_at)
        ]
      end
    end
  end

  def export_player_cards
    write_resource("player_cards", PLAYER_CARD_HEADERS, output_dir.join("player_cards.csv")) do |csv|
      PlayerCard.includes(:player, :card_set).order(:id).find_each do |player_card|
        csv << [
          player_card.id,
          player_card.player_id,
          player_card.card_set_id,
          player_card.card_type,
          player_card.is_pitcher,
          player_card.is_relief_only,
          player_card.is_closer,
          player_card.handedness,
          player_card.speed,
          player_card.bunt,
          player_card.steal_start,
          player_card.steal_end,
          player_card.injury_rate,
          player_card.starter_stamina,
          player_card.relief_stamina,
          JSON.generate(player_card.batting_table || {}),
          JSON.generate(player_card.pitching_table || {}),
          player_card.unique_traits,
          player_card.irc_macro_name,
          player_card.irc_display_name,
          player_card.card_label,
          optional_value(player_card, :variant),
          iso8601(player_card.created_at),
          iso8601(player_card.updated_at)
        ]
      end
    end
  end

  def write_resource(resource_type, headers, path)
    count = 0

    CSV.open(path, "w", write_headers: true, headers: headers) do |csv|
      yield csv
    end

    count = csv_row_count(path)
    SharedSyncLog.create!(
      resource_type: resource_type,
      synced_count: count,
      status: "success",
      synced_at: Time.current,
      notes: "export_path=#{path}"
    )
    count
  rescue StandardError => e
    SharedSyncLog.create!(
      resource_type: resource_type,
      synced_count: count,
      status: "failed",
      synced_at: Time.current,
      notes: "export_path=#{path}; error=#{e.message}"
    )
    raise
  end

  def csv_row_count(path)
    count = 0
    CSV.foreach(path, headers: true) { |_| count += 1 }
    count
  end

  def iso8601(value)
    value&.iso8601
  end

  def optional_value(record, attribute)
    record.respond_to?(attribute) ? record.public_send(attribute) : nil
  end
end
