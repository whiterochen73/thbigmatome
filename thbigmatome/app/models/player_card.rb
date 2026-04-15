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

  # 投手として使用可能か（card_type='pitcher' または is_pitcher=true）
  def can_pitch?
    card_type == "pitcher" || is_pitcher
  end

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
end
