module BaseballCardValidations
  extend ActiveSupport::Concern

  included do
    # 走力・バント・盗塁値
    validates :speed, presence: true, numericality: { only_integer: true, message: :not_an_integer }, inclusion: { in: 1..5, message: :out_of_range }
    validates :bunt, presence: true, numericality: { only_integer: true, message: :not_an_integer }, inclusion: { in: 1..10, message: :out_of_range }
    validates :steal_start, presence: true, numericality: { only_integer: true, message: :not_an_integer }, inclusion: { in: 1..22, message: :out_of_range }
    validates :steal_end, presence: true, numericality: { only_integer: true, message: :not_an_integer }, inclusion: { in: 1..22, message: :out_of_range }

    # 怪我特徴 (0=怪我特徴なし, 1〜6=怪我レベル, 7=フルイニング)
    validates :injury_rate, presence: true, numericality: { only_integer: true, message: :not_an_integer }, inclusion: { in: 0..7, message: :out_of_range }
  end
end
