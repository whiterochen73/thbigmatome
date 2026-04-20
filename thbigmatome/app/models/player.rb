class Player < ApplicationRecord
  PM2026_SET_TYPE = "pm2026".freeze
  HACHINAI61_SET_TYPE = "hachinai61".freeze
  NAME_SUFFIX_PATTERN = /[[:space:]　]*[（(][^()（）]+[）)]\z/.freeze

  validates :name, presence: true

  has_many :team_memberships, dependent: :destroy
  has_many :teams, through: :team_memberships

  has_many :cost_players, dependent: :destroy

  has_many :player_cards, dependent: :destroy
  has_many :at_bats_as_batter, class_name: "AtBat", foreign_key: :batter_id, dependent: :destroy, inverse_of: :batter
  has_many :at_bats_as_pitcher, class_name: "AtBat", foreign_key: :pitcher_id, dependent: :destroy, inverse_of: :pitcher
  has_many :pitcher_game_states, foreign_key: :pitcher_id, dependent: :destroy, inverse_of: :pitcher
  has_many :imported_stats, dependent: :destroy

  # 魔理沙/千亦/天子/飯綱丸: 東方選手で投手・野手両専念コスト対象
  SPECIAL_PITCHER_FIELDER_PLAYER_IDS = [ 3, 20, 29, 33 ].freeze

  def available_cost_types
    types = []
    two_way = hachinai_two_way?
    # ハチナイ二刀流選手は「通常」コスト不可
    types << "normal_cost" unless two_way

    loaded_cards = player_cards.loaded? ? player_cards : player_cards.to_a
    pitcher_cards = loaded_cards.select(&:is_pitcher)
    fielder_cards = loaded_cards.reject(&:is_pitcher)

    # リリーフ契約: 疲労Pに「R」がついていないリリーフ選手 またはスラッシュ投手(is_dual_wielder=true)
    if pitcher_cards.any? { |c| (!c.is_relief_only && c.relief_stamina.present?) || c.is_dual_wielder }
      types << "relief_only_cost"
    end

    # 二刀流: 投手カードと野手カード両方を持つ、またはハチナイ二刀流（片方カードのみでも可）
    if (pitcher_cards.any? && fielder_cards.any?) || two_way
      types << "two_way_cost"
    end

    # 投手専念/野手専念: 二刀流条件 + 特定東方選手
    if (pitcher_cards.any? && fielder_cards.any?) || two_way || SPECIAL_PITCHER_FIELDER_PLAYER_IDS.include?(id)
      types << "pitcher_only_cost"
      types << "fielder_only_cost"
    end

    types
  end

  # バリエーションカード個別のコスト種別判定
  def available_cost_types_for_card(card)
    types = []
    two_way = hachinai_two_way?
    # ハチナイ二刀流選手は「通常」コスト不可
    types << "normal_cost" unless two_way

    loaded_cards = player_cards.loaded? ? player_cards : player_cards.to_a

    # リリーフ契約: このカード固有の投手特性で判定
    if card.is_pitcher && ((!card.is_relief_only && card.relief_stamina.present?) || card.is_dual_wielder)
      types << "relief_only_cost"
    end

    # 二刀流/投手専念/野手専念: 選手全体で投手・野手カード両方を持つ、またはハチナイ二刀流（片方カードのみでも可）
    has_pitcher = loaded_cards.any?(&:is_pitcher)
    has_fielder = loaded_cards.any? { |c| !c.is_pitcher }

    if (has_pitcher && has_fielder) || two_way
      types << "two_way_cost"
    end

    if (has_pitcher && has_fielder) || two_way || SPECIAL_PITCHER_FIELDER_PLAYER_IDS.include?(id)
      types << "pitcher_only_cost"
      types << "fielder_only_cost"
    end

    types
  end

  def cost_value_for_types(cost_types, cost_list, exact_player_card_id: nil)
    cost_list_id = extract_cost_list_id(cost_list)
    return 0 unless cost_list_id

    Array(cost_types).each do |cost_type|
      value = lookup_cost_value(cost_type, cost_list_id, exact_player_card_id: exact_player_card_id)
      return value if value.present?
    end

    0
  end

  def cost_value_for_card(card, cost_list)
    cost_types =
      if card.is_relief_only
        %w[relief_only_cost pitcher_only_cost two_way_cost fielder_only_cost normal_cost]
      elsif card.can_pitch?
        %w[pitcher_only_cost two_way_cost fielder_only_cost normal_cost]
      else
        %w[fielder_only_cost two_way_cost pitcher_only_cost normal_cost]
      end

    cost_value_for_types(cost_types, cost_list, exact_player_card_id: card.id)
  end

  def cost_lookup_players
    [ self, fallback_hachinai_player ].compact.uniq(&:id)
  end

  # ハチナイ二刀流選手判定: ハチナイ6.1カードセット保有 かつ 背番号39以下（片方カードのみでも二刀流扱い）
  # ハチナイ背番号40以上は投手+野手両方のカードを保有している場合のみ二刀流
  # このルールはハチナイ固有。他作品チーム（東方等）には適用しない。
  def hachinai_two_way?
    direct_hachinai_two_way? || fallback_hachinai_player&.direct_hachinai_two_way? || false
  end

  def direct_hachinai_two_way?
    return false unless has_hachinai61_card?

    if number.present? && number.to_i <= 39
      true
    else
      loaded = player_cards.loaded? ? player_cards : player_cards.to_a
      loaded.any?(&:is_pitcher) && loaded.any? { |c| !c.is_pitcher }
    end
  end

  def has_hachinai61_card?
    loaded_cards = player_cards.loaded? ? player_cards : player_cards.includes(:card_set).to_a
    loaded_cards.any? { |card| card.card_set&.set_type == HACHINAI61_SET_TYPE }
  end

  private

  def lookup_cost_value(cost_type, cost_list_id, exact_player_card_id: nil)
    exact = lookup_cost_players.find do |cp|
      cp.cost_id == cost_list_id && cp.player_card_id == exact_player_card_id
    end
    return exact.public_send(cost_type) if exact&.public_send(cost_type).present?

    base = lookup_cost_players.find do |cp|
      cp.cost_id == cost_list_id && cp.player_card_id.nil?
    end
    base&.public_send(cost_type)
  end

  def lookup_cost_players
    @lookup_cost_players ||= cost_lookup_players.flat_map do |candidate|
      candidate.cost_players.loaded? ? candidate.cost_players : candidate.cost_players.to_a
    end
  end

  def fallback_hachinai_player
    return @fallback_hachinai_player if defined?(@fallback_hachinai_player)
    return @fallback_hachinai_player = nil if direct_hachinai_two_way?
    return @fallback_hachinai_player = nil unless has_pm2026_card?

    normalized_name = normalized_lookup_name
    return @fallback_hachinai_player = nil if normalized_name.blank?

    @fallback_hachinai_player =
      Player.includes(:cost_players, player_cards: :card_set)
            .where.not(id: id)
            .where("REPLACE(REPLACE(name, ' ', ''), '　', '') = ?", normalized_name)
            .detect { |candidate| candidate.has_hachinai61_card? }
  end

  def has_pm2026_card?
    loaded_cards = player_cards.loaded? ? player_cards : player_cards.includes(:card_set).to_a
    loaded_cards.any? { |card| card.card_set&.set_type == PM2026_SET_TYPE }
  end

  def normalized_lookup_name
    @normalized_lookup_name ||= name.to_s.sub(NAME_SUFFIX_PATTERN, "").gsub(/[[:space:]　]+/, "")
  end

  def extract_cost_list_id(cost_list)
    return cost_list.id if cost_list.respond_to?(:id)
    return cost_list if cost_list.is_a?(Integer)

    nil
  end
end
