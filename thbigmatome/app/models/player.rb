class Player < ApplicationRecord
  has_one :player_pitching, dependent: :destroy

  belongs_to :batting_style, optional: true
  has_many :player_batting_skills, dependent: :destroy
  has_many :batting_skills, through: :player_batting_skills
  belongs_to :pitching_style, optional: true
  belongs_to :pinch_pitching_style, class_name: 'PitchingStyle', foreign_key: :pinch_pitching_style_id, optional: true
  has_many :player_pitching_skills, dependent: :destroy
  has_many :pitching_skills, through: :player_pitching_skills

  has_many :player_player_types, dependent: :destroy
  has_many :player_types, through: :player_player_types
  has_many :player_biorhythms, dependent: :destroy
  has_many :cost_players, dependent: :destroy

  has_many :biorhythms, through: :player_biorhythms

  has_many :catchers_players, dependent: :destroy
  has_many :catchers, through: :catchers_players, source: :catcher

  has_many :partner_pitchers_players, class_name: 'CatchersPlayer', foreign_key: 'catcher_id'
  has_many :partner_pitchers, through: :partner_pitchers_players, source: :player, dependent: :destroy

  belongs_to :catcher_pitching_style, class_name: 'PitchingStyle', foreign_key: :catcher_pitching_style_id, optional: true

  # ポジションをenumで定義
  enum :position, { pitcher: 'pitcher', catcher: 'catcher', infielder: 'infielder', outfielder: 'outfielder' }

  # 投打をenumで定義
  enum :throwing_hand, { right_throw: 'right_throw', left_throw: 'left_throw' }
  enum :batting_hand, { right_bat: 'right_bat', left_bat: 'left_bat', switch_hitter: 'switch_hitter' }

  # 守備力フォーマットの正規表現

  DEFENSE_RATING_FORMAT = /\A[0-5][A-E|S]\z/.freeze
  DEFENSE_ATTRIBUTES = %i[
    defense_p defense_c defense_1b defense_2b defense_3b defense_ss
    defense_of defense_lf defense_cf defense_rf special_defense_c
  ].freeze

  validates(*DEFENSE_ATTRIBUTES,
            format: { with: DEFENSE_RATING_FORMAT, message: 'は0～5の数字とA～Eのアルファベットの組み合わせ2文字で入力してください' },
            allow_blank: true)

  # 捕手の送球値
  validates :throwing_c,
            presence: { message: 'は捕手守備力が設定されている場合、必須です' },
            if: -> { defense_c.present? }
  validates :throwing_c,
            numericality: { only_integer: true, message: 'は整数で入力してください' },
            inclusion: { in: -5..5, message: 'は-5～5の範囲で入力してください' },
            allow_blank: true
  validates :special_throwing_c,
            presence: { message: 'は捕手守備力が設定されている場合、必須です' },
            if: -> { special_defense_c.present? }
  validates :special_throwing_c,
            numericality: { only_integer: true, message: 'は整数で入力してください' },
            inclusion: { in: -5..5, message: 'は-5～5の範囲で入力してください' },
            allow_blank: true

  # 外野手の送球値
  OUTFIELDER_THROWING_ATTRIBUTES = %i[throwing_of throwing_lf throwing_cf throwing_rf].freeze
  OUTFIELDER_THROWING_VALUES = %w[S A B C].freeze

  validates(*OUTFIELDER_THROWING_ATTRIBUTES,
            inclusion: { in: OUTFIELDER_THROWING_VALUES, message: 'はS, A, B, Cのいずれかで入力してください' },
            allow_blank: true)

  # 疲労P(先発)
  validates :starter_stamina,
            numericality: { only_integer: true, message: 'は整数で入力してください' },
            inclusion: { in: 4..9, message: 'は4～9の範囲で入力してください' },
            allow_blank: true,
            unless: :is_relief_only
  # 疲労P(リリーフ)
  validates :relief_stamina,
            numericality: { only_integer: true, message: 'は整数で入力してください' },
            inclusion: { in: 0..3, message: 'は0～3の範囲で入力してください' },
            allow_blank: true

  {
    defense_of: :throwing_of, defense_lf: :throwing_lf, defense_cf: :throwing_cf, defense_rf: :throwing_rf
  }.each do |defense_attr, throwing_attr|
    validates throwing_attr, presence: { message: 'は対応する守備力が設定されている場合、必須です' }, if: -> { send(defense_attr).present? }
  end

  # 走力・バント・盗塁値
  validates :speed, presence: true, numericality: { only_integer: true, message: 'は整数で入力してください' }, inclusion: { in: 1..5, message: 'は1～5の範囲で入力してください' }
  validates :bunt, presence: true, numericality: { only_integer: true, message: 'は整数で入力してください' }, inclusion: { in: 1..10, message: 'は1～10の範囲で入力してください' }
  validates :steal_start, presence: true, numericality: { only_integer: true, message: 'は整数で入力してください' }, inclusion: { in: 1..22, message: 'は1～22の範囲で入力してください' }
  validates :steal_end, presence: true, numericality: { only_integer: true, message: 'は整数で入力してください' }, inclusion: { in: 1..22, message: 'は1～22の範囲で入力してください' }

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
  validates :injury_rate, presence: true, numericality: { only_integer: true, message: 'は整数で入力してください' }, inclusion: { in: 1..7, message: 'は1～6の範囲で入力してください' }
end
