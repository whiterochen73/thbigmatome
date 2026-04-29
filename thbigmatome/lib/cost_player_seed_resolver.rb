module CostPlayerSeedResolver
  Resolution = Struct.new(:player, :player_card, :variant, keyword_init: true)

  COST_ATTRIBUTES = %w[
    normal_cost
    relief_only_cost
    pitcher_only_cost
    fielder_only_cost
    two_way_cost
  ].freeze

  VARIANT_ALIASES = {
    "AP" => [ "エイプリル" ],
    "妖精帝國" => [ "妖精" ],
    "幽冥楼閣" => [ "幽冥" ]
  }.freeze

  module_function

  def resolve(raw_name)
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
    resolution = resolve(row["player_name"])
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
