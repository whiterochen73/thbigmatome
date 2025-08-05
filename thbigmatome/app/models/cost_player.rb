class CostPlayer < ApplicationRecord
  belongs_to :cost
  belongs_to :player

  validates :normal_cost, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_blank: true
  validates :relief_only_cost, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_blank: true
  validates :pitcher_only_cost, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_blank: true
  validates :fielder_only_cost, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_blank: true
  validates :two_way_cost, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_blank: true
end
