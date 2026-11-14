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
    PlayerCardLocator.clear_cache!
  end

  # card_seq のカード（取り込み済みの PlayerCard）に当てる。取り込んでいなければ player を nil にして読み飛ばしにする。
  # カードの引き方は取り込みと同じで、PlayerCardLocator（画像の取り込みと共有）が持つ
  def resolve_card_seq(card_seq)
    row = card_rows[card_seq.to_s]
    return Resolution.new(player: nil, player_card: nil, variant: nil) unless row

    result = PlayerCardLocator.locate(row)
    variant = row["variant"].presence
    Resolution.new(player: result.card && result.owner, player_card: result.card, variant: variant)
  end

  def card_rows
    @card_rows ||= CSV.read(Rails.root.join(PLAYER_CARDS_CSV), headers: true, encoding: "UTF-8").to_h { |r| [ r["card_seq"], r ] }
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
    # 同じ variant が PM の版をまたいで複数ある時（PM2026 と PM2027 の 楼閣 など）は id の小さい方（先に取り込まれた版）に固定する。
    # 並びを DB 任せにしない。PM2027 の同 variant には card_seq つきの行で当てる（cost_players_seed.csv）
    player.player_cards.sort_by(&:id).detect do |card|
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
