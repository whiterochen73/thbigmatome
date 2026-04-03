class TraitDefinition < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  # Note: column is `typical_role` (not `default_role`) due to Rails 8 reserved attribute conflict
end
