class CompetitionRoster < ApplicationRecord
  belongs_to :competition_entry
  belongs_to :player_card

  enum :squad, { first_squad: 0, second_squad: 1 }

  validates :competition_entry_id, uniqueness: { scope: :player_card_id }
  validates :squad, presence: true
end
