require "csv"

# cost_players_seed.csv の 1 行を Player（と PlayerCard）に当てる。
#
# 行の指し方は 2 通り。
#   - player_name 列（従来）: 選手名。「名前（variant）」なら持ち主の Player の variant カード（player_card_id つき）、そうでなければ名前の Player（player_card_id なし）
#   - card_seq 列（任意。空なら従来どおり）: db/import/player_cards.csv の card_seq。そのカード 1 枚のコスト（常に player_card_id つき）。
#     年度版・ハチナイなど他のカードと持ち主の Player を共有する PM のカードが、年度版と別の行を持つ時に使う。名前では持ち主のコストと見分けが付かない。
#     card_seq の行では player_name は読む人のための表記で、当て先は card_seq だけで決まる
module CostPlayerSeedResolver
  Resolution = Struct.new(:player, :player_card, :variant, keyword_init: true)

  COST_ATTRIBUTES = %w[
    normal_cost
    relief_only_cost
    pitcher_only_cost
    fielder_only_cost
    two_way_cost
  ].freeze

  # player_cards.csv の card_source → card_sets.name（db/seeds/import_cards.rb の card_set_defs と同じ対応）
  CARD_SET_NAMES = {
    "hachinai6.1" => "ハチナイ6.1",
    "tamayomi2" => "球詠2"
  }.freeze

  VARIANT_ALIASES = {
    "AP" => [ "エイプリル" ],
    "妖精帝國" => [ "妖精" ],
    "幽冥楼閣" => [ "幽冥" ]
  }.freeze

  PLAYER_CARDS_CSV = "db/import/player_cards.csv".freeze

  module_function

  def resolve(raw_name, card_seq: nil)
    return resolve_card_seq(card_seq) if card_seq.present?

    parsed = parse_variant(raw_name)

    if parsed
      base_player = find_player_by_name(parsed[:base_name])
      player_card = find_variant_card(base_player, parsed[:variant]) if base_player
      return Resolution.new(player: base_player, player_card: player_card, variant: parsed[:variant]) if player_card
    end

    exact_player = find_player_by_name(raw_name)
    return Resolution.new(player: exact_player, player_card: nil, variant: parsed&.fetch(:variant)) if exact_player

    Resolution.new(player: nil, player_card: nil, variant: parsed&.fetch(:variant))
  end

  def assign!(cost, row)
    resolution = resolve(row["player_name"], card_seq: row["card_seq"])
    return unless resolution.player

    cp = CostPlayer.find_or_initialize_by(
      cost: cost,
      player: resolution.player,
      player_card: resolution.player_card
    )
    COST_ATTRIBUTES.each do |attribute|
      cp.public_send("#{attribute}=", row[attribute].presence&.to_i)
    end
    cp.cost_exempt = row["cost_exempt"] == "true"
    cp.save!
    cp
  end

  def clear_cache!
    @players = nil
    @card_rows = nil
  end

  # card_seq のカード（取り込み済みの PlayerCard）に当てる。取り込んでいなければ player を nil にして読み飛ばしにする。
  # カードの引き方は import_cards.rb の find_or_create_by! と同じ（出典のセット・持ち主・種別・variant。持ち主は variant つきなら base_player_name の選手）
  def resolve_card_seq(card_seq)
    row = card_rows[card_seq.to_s]
    return Resolution.new(player: nil, player_card: nil, variant: nil) unless row

    variant = row["variant"].presence
    owner_name = variant && row["base_player_name"].presence ? row["base_player_name"] : row["name"]
    owner = find_player_by_name(owner_name)
    set = CardSet.find_by(name: CARD_SET_NAMES.fetch(row["card_source"], row["card_source"]))
    return Resolution.new(player: nil, player_card: nil, variant: variant) unless owner && set

    scope = PlayerCard.where(card_set: set, player: owner, card_type: card_type_of(row))
    scope = variant ? scope.where(variant: variant) : scope.where(variant: [ nil, "" ])
    card = scope.first
    Resolution.new(player: card && owner, player_card: card, variant: variant)
  end

  def card_rows
    @card_rows ||= CSV.read(Rails.root.join(PLAYER_CARDS_CSV), headers: true, encoding: "UTF-8").to_h { |r| [ r["card_seq"], r ] }
  end

  def card_type_of(row)
    row["card_type"].presence || (row["is_pitcher"] == "true" ? "pitcher" : "batter")
  end

  def parse_variant(raw_name)
    normalized = raw_name.to_s.strip.unicode_normalize(:nfkc)
    match = normalized.match(/\A(?<base>.+?)[[:space:]　]*[（(](?<variant>[^()（）]+)[）)]\z/)
    return unless match

    {
      base_name: match[:base].strip,
      variant: normalize_variant(match[:variant])
    }
  end

  def find_player_by_name(name)
    normalized = normalize_lookup_name(name)
    players.detect { |player| normalize_lookup_name(player.name) == normalized }
  end

  def find_variant_card(player, variant)
    variants = variant_candidates(variant)
    player.player_cards.detect do |card|
      normalized_card_variant = normalize_variant(card.variant)
      variants.include?(normalized_card_variant)
    end
  end

  def variant_candidates(variant)
    normalized = normalize_variant(variant)
    ([ normalized ] + VARIANT_ALIASES.fetch(normalized, [])).uniq
  end

  def normalize_lookup_name(value)
    value.to_s.unicode_normalize(:nfkc).gsub(/[[:space:]　]+/, "")
  end

  def normalize_variant(value)
    normalize_lookup_name(value)
  end

  def players
    @players ||= Player.includes(:player_cards).to_a
  end
end
