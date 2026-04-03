class PlayerCardDefense < ApplicationRecord
  belongs_to :player_card
  belongs_to :condition, class_name: "TraitCondition", optional: true

  validates :position, :range_value, :error_rank, presence: true
end
