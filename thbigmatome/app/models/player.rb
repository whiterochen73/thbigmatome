class Player < ApplicationRecord
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

  # ハチナイ二刀流選手判定: ハチナイ6.1カードセット保有 かつ 背番号39以下（片方カードのみでも二刀流扱い）
  # ハチナイ背番号40以上は投手+野手両方のカードを保有している場合のみ二刀流
  # このルールはハチナイ固有。他作品チーム（東方等）には適用しない。
  def hachinai_two_way?
    return false unless player_cards.joins(:card_set).where(card_sets: { set_type: "hachinai61" }).exists?
    if number.present? && number.to_i <= 39
      true
    else
      loaded = player_cards.loaded? ? player_cards : player_cards.to_a
      loaded.any?(&:is_pitcher) && loaded.any? { |c| !c.is_pitcher }
    end
  end
end
