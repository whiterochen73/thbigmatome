class PlayerCardTrait < ApplicationRecord
  belongs_to :player_card
  belongs_to :trait_definition
  belongs_to :condition, class_name: "TraitCondition", optional: true
end
