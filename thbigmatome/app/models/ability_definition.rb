class AbilityDefinition < ApplicationRecord
  validates :name, presence: true, uniqueness: true
end
