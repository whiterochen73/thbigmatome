module BaseballCardValidations
  extend ActiveSupport::Concern

  DEFENSE_RATING_FORMAT = /\A[0-5][A-ES]\z/.freeze
  DEFENSE_ATTRIBUTES = %i[
    defense_p defense_c defense_1b defense_2b defense_3b defense_ss
    defense_of defense_lf defense_cf defense_rf special_defense_c
  ].freeze

  OUTFIELDER_THROWING_ATTRIBUTES = %i[throwing_of throwing_lf throwing_cf throwing_rf].freeze
  OUTFIELDER_THROWING_VALUES = %w[S A B C].freeze

  included do
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

    # 怪我特徴
    validates :injury_rate, presence: true, numericality: { only_integer: true, message: :not_an_integer }, inclusion: { in: 1..7, message: :out_of_range }
  end

  private

  def defense_of_exclusivity
    has_of = defense_of.present?
    has_individual = [ defense_lf, defense_cf, defense_rf ].any?(&:present?)
    if has_of && has_individual
      errors.add(:base, :of_and_individual_exclusive)
    end
  end
end
