class PlayerCard < ApplicationRecord
  has_one_attached :card_image

  belongs_to :card_set
  belongs_to :player
  belongs_to :batting_style, optional: true
  belongs_to :pitching_style, optional: true
  belongs_to :pinch_pitching_style, class_name: "PitchingStyle", foreign_key: :pinch_pitching_style_id, optional: true
  belongs_to :catcher_pitching_style, class_name: "PitchingStyle", foreign_key: :catcher_pitching_style_id, optional: true

  has_many :player_card_player_types, dependent: :destroy
  has_many :player_types, through: :player_card_player_types
  has_many :competition_rosters, dependent: :destroy
  has_many :game_lineup_entries, dependent: :destroy
  has_many :player_card_defenses, dependent: :destroy
  has_many :player_card_traits, dependent: :destroy
  has_many :player_card_abilities, dependent: :destroy
  has_many :player_card_exclusive_catchers, dependent: :destroy

  accepts_nested_attributes_for :player_card_defenses, allow_destroy: true
  accepts_nested_attributes_for :player_card_traits, allow_destroy: true
  accepts_nested_attributes_for :player_card_abilities, allow_destroy: true
  has_many :exclusive_catchers, through: :player_card_exclusive_catchers, source: :catcher_player

  validates :card_set_id, :player_id, presence: true
  validates :card_type, presence: true, inclusion: { in: %w[pitcher batter] }
  validates :card_set_id, uniqueness: { scope: [ :player_id, :card_type ] }

  # 投手として使用可能か（能力判定）
  # 判定条件: card_type='pitcher' OR is_pitcher=true OR player_card_defensesに投手(P)ポジションがある
  # player_card_defensesが正典（P守備があれば確実に投手能力あり）。is_pitcherはフォールバック。
  # ※ selected_cost_type='fielder_only_cost'（野手専念）の場合は呼び出し側で除外すること
  def can_pitch?
    card_type == "pitcher" ||
      is_pitcher ||
      player_card_defenses.any? { |d| d.position&.upcase == "P" }
  end

  # スラッシュ選手: 先発もリリーフもできるカード（先発疲労P とリリーフ疲労P の両方があり、リリーフ専門でない）。
  # 先発→リリーフ・リリーフ→先発の休養表（rulebook 08 §8.3.3 / §8.3.4）がスラッシュ用に変わる。
  def slash_pitcher?
    starter_stamina.present? && relief_stamina.present? && !is_relief_only
  end

  # リリーフで投げられるカードか。画面の「リリーフなら」を出す条件と同じ（リリーフ向けの疲労P を持つ、またはリリーフ専門）
  def relief_capable?
    is_relief_only || relief_stamina.present?
  end

  # 「オープナー可」アビリティ（ability_definitions.name。rulebook 08 §8.4.1）。pitcher_game_states.is_opener は登板時のフラグで別物。
  # カードの記載は Dugout に未取込のことがある（2026-10-27 時点で ability_definitions は 0 件）。定義が 1 件も無い間は、
  # リリーフで投げられるカード全員を true にする（Operator 2026-10-27）。定義が 1 件でもあれば、カードの記載どおり。
  # definitions_present: 定義の有無。一覧で投手ごとに引かないよう、呼び出し側が 1 回だけ AbilityDefinition.exists? を渡す。
  # includes(player_card_abilities: :ability_definition) 済みなら追加クエリなし。
  OPENER_ABILITY_NAME = "オープナー可".freeze

  def opener_capable?(definitions_present = AbilityDefinition.exists?)
    return relief_capable? unless definitions_present

    player_card_abilities.any? { |a| a.ability_definition&.name == OPENER_ABILITY_NAME }
  end

  # DB検索用スコープ: 投手能力を持つカード（can_pitch?のDB版）
  # player_card_defensesにP守備がある OR is_pitcher=true OR card_type='pitcher'
  scope :can_pitch, -> {
    where(card_type: "pitcher")
      .or(where(is_pitcher: true))
      .or(
        where(
          "EXISTS (SELECT 1 FROM player_card_defenses pcd WHERE pcd.player_card_id = player_cards.id AND pcd.position = ?)",
          "P"
        )
      )
  }

  validates :speed, presence: true,
            numericality: { only_integer: true },
            inclusion: { in: 1..5 }
  validates :bunt, presence: true,
            numericality: { only_integer: true },
            inclusion: { in: 1..10 }
  validates :steal_start, presence: true,
            numericality: { only_integer: true },
            inclusion: { in: 1..22 }
  validates :steal_end, presence: true,
            numericality: { only_integer: true },
            inclusion: { in: 1..22 }
  validates :injury_rate, presence: true,
            numericality: { only_integer: true },
            inclusion: { in: 0..7 }
  validates :starter_stamina,
            numericality: { only_integer: true },
            inclusion: { in: 4..9 },
            allow_blank: true,
            unless: :is_relief_only
  validates :relief_stamina,
            numericality: { only_integer: true },
            inclusion: { in: 0..3 },
            allow_blank: true
  validates :special_defense_c,
            format: { with: /\A[0-5][A-ES]\z/ },
            allow_blank: true
  validates :special_throwing_c,
            presence: true,
            if: -> { special_defense_c.present? }
  validates :special_throwing_c,
            numericality: { only_integer: true },
            inclusion: { in: -5..5 },
            allow_blank: true

  def cost_value(cost_list)
    player.cost_value_for_card(self, cost_list)
  end
end
