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
    types = [ "normal_cost" ]

    loaded_cards = player_cards.loaded? ? player_cards : player_cards.to_a
    pitcher_cards = loaded_cards.select(&:is_pitcher)
    fielder_cards = loaded_cards.reject(&:is_pitcher)

    # リリーフ契約: 疲労Pに「R」がついていないリリーフ選手 またはスラッシュ投手(is_dual_wielder=true)
    if pitcher_cards.any? { |c| (!c.is_relief_only && c.relief_stamina.present?) || c.is_dual_wielder }
      types << "relief_only_cost"
    end

    # 二刀流: 投手カードと野手カード両方を持つ
    if pitcher_cards.any? && fielder_cards.any?
      types << "two_way_cost"
    end

    # 投手専念/野手専念: 二刀流条件 + 特定東方選手
    if (pitcher_cards.any? && fielder_cards.any?) || SPECIAL_PITCHER_FIELDER_PLAYER_IDS.include?(id)
      types << "pitcher_only_cost"
      types << "fielder_only_cost"
    end

    types
  end

  # バリエーションカード個別のコスト種別判定
  def available_cost_types_for_card(card)
    types = [ "normal_cost" ]

    loaded_cards = player_cards.loaded? ? player_cards : player_cards.to_a

    # リリーフ契約: このカード固有の投手特性で判定
    if card.is_pitcher && ((!card.is_relief_only && card.relief_stamina.present?) || card.is_dual_wielder)
      types << "relief_only_cost"
    end

    # 二刀流/投手専念/野手専念: 選手全体で投手・野手カード両方を持つ場合
    has_pitcher = loaded_cards.any?(&:is_pitcher)
    has_fielder = loaded_cards.any? { |c| !c.is_pitcher }

    if (has_pitcher && has_fielder) || SPECIAL_PITCHER_FIELDER_PLAYER_IDS.include?(id)
      types << "two_way_cost"
      types << "pitcher_only_cost"
      types << "fielder_only_cost"
    end

    types
  end
end
