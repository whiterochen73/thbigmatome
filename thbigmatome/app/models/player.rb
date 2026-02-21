class Player < ApplicationRecord
  has_many :team_memberships, dependent: :destroy
  has_many :teams, through: :team_memberships

  belongs_to :batting_style, optional: true
  has_many :player_batting_skills, dependent: :destroy
  has_many :batting_skills, through: :player_batting_skills
  belongs_to :pitching_style, optional: true
  belongs_to :pinch_pitching_style, class_name: "PitchingStyle", foreign_key: :pinch_pitching_style_id, optional: true
  has_many :player_pitching_skills, dependent: :destroy
  has_many :pitching_skills, through: :player_pitching_skills

  has_many :player_player_types, dependent: :destroy
  has_many :player_types, through: :player_player_types
  has_many :player_biorhythms, dependent: :destroy
  has_many :cost_players, dependent: :destroy

  has_many :biorhythms, through: :player_biorhythms

  has_many :catchers_players, dependent: :destroy
  has_many :catchers, through: :catchers_players, source: :catcher

  has_many :partner_pitchers_players, class_name: "CatchersPlayer", foreign_key: "catcher_id"
  has_many :partner_pitchers, through: :partner_pitchers_players, source: :player, dependent: :destroy

  has_many :player_cards, dependent: :destroy
  has_many :at_bats_as_batter, class_name: "AtBat", foreign_key: :batter_id, dependent: :destroy, inverse_of: :batter
  has_many :at_bats_as_pitcher, class_name: "AtBat", foreign_key: :pitcher_id, dependent: :destroy, inverse_of: :pitcher
  has_many :pitcher_game_states, foreign_key: :pitcher_id, dependent: :destroy, inverse_of: :pitcher
  has_many :imported_stats, dependent: :destroy

  belongs_to :catcher_pitching_style, class_name: "PitchingStyle", foreign_key: :catcher_pitching_style_id, optional: true

  # ポジションをenumで定義
  enum :position, { pitcher: "pitcher", catcher: "catcher", infielder: "infielder", outfielder: "outfielder" }

  # 投打をenumで定義
  enum :throwing_hand, { right_throw: "right_throw", left_throw: "left_throw" }
  enum :batting_hand, { right_bat: "right_bat", left_bat: "left_bat", switch_hitter: "switch_hitter" }

  # 守備力フォーマットの正規表現

  DEFENSE_RATING_FORMAT = /\A[0-5][A-E|S]\z/.freeze
  DEFENSE_ATTRIBUTES = %i[
    defense_p defense_c defense_1b defense_2b defense_3b defense_ss
    defense_of defense_lf defense_cf defense_rf special_defense_c
  ].freeze

  validates(*DEFENSE_ATTRIBUTES,
            format: { with: DEFENSE_RATING_FORMAT, message: :invalid_format },
            allow_blank: true)

  # 捕手の送球値
  validates :throwing_c,
            presence: { message: :required_when_defense_c_present },
            if: -> { defense_c.present? }
  validates :throwing_c,
            numericality: { only_integer: true, message: :not_an_integer },
            inclusion: { in: -5..5, message: :out_of_range },
            allow_blank: true
  validates :special_throwing_c,
            presence: { message: :required_when_special_defense_c_present },
            if: -> { special_defense_c.present? }
  validates :special_throwing_c,
            numericality: { only_integer: true, message: :not_an_integer },
            inclusion: { in: -5..5, message: :out_of_range },
            allow_blank: true

  # 外野手の送球値
  OUTFIELDER_THROWING_ATTRIBUTES = %i[throwing_of throwing_lf throwing_cf throwing_rf].freeze
  OUTFIELDER_THROWING_VALUES = %w[S A B C].freeze

  validates(*OUTFIELDER_THROWING_ATTRIBUTES,
            inclusion: { in: OUTFIELDER_THROWING_VALUES, message: :must_be_s_a_b_or_c },
            allow_blank: true)

  # 疲労P(先発)
  validates :starter_stamina,
            numericality: { only_integer: true, message: :not_an_integer },
            inclusion: { in: 4..9, message: :out_of_range },
            allow_blank: true,
            unless: :is_relief_only
  # 疲労P(リリーフ)
  validates :relief_stamina,
            numericality: { only_integer: true, message: :not_an_integer },
            inclusion: { in: 0..3, message: :out_of_range },
            allow_blank: true

  {
    defense_of: :throwing_of, defense_lf: :throwing_lf, defense_cf: :throwing_cf, defense_rf: :throwing_rf
  }.each do |defense_attr, throwing_attr|
    validates throwing_attr, presence: { message: :required_when_defense_present }, if: -> { send(defense_attr).present? }
  end

  # 外野守備の排他性バリデーション
  validate :defense_of_exclusivity

  # 走力・バント・盗塁値
  validates :speed, presence: true, numericality: { only_integer: true, message: :not_an_integer }, inclusion: { in: 1..5, message: :out_of_range }
  validates :bunt, presence: true, numericality: { only_integer: true, message: :not_an_integer }, inclusion: { in: 1..10, message: :out_of_range }
  validates :steal_start, presence: true, numericality: { only_integer: true, message: :not_an_integer }, inclusion: { in: 1..22, message: :out_of_range }
  validates :steal_end, presence: true, numericality: { only_integer: true, message: :not_an_integer }, inclusion: { in: 1..22, message: :out_of_range }

  def batting_skill_ids
    player_batting_skills.map(&:batting_skill_id)
  end

  def player_type_ids
    player_player_types.map(&:player_type_id)
  end

  def biorhythm_ids
    player_biorhythms.map(&:biorhythm_id)
  end

  def pitching_skill_ids
    player_pitching_skills.map(&:pitching_skill_id)
  end

  def catcher_ids
    catchers_players.map(&:catcher_id)
  end

  def partner_pitcher_ids
    partner_pitchers_players.map(&:player_id)
  end

  # 怪我特徴
  validates :injury_rate, presence: true, numericality: { only_integer: true, message: :not_an_integer }, inclusion: { in: 1..7, message: :out_of_range }

  private

  def defense_of_exclusivity
    has_of = defense_of.present?
    has_individual = [ defense_lf, defense_cf, defense_rf ].any?(&:present?)
    if has_of && has_individual
      errors.add(:base, :of_and_individual_exclusive)
    end
  end
end
