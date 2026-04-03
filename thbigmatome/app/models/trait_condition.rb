class TraitCondition < ApplicationRecord
  validates :name, presence: true, uniqueness: true
end
