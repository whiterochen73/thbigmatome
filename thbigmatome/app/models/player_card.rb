class PlayerCard < ApplicationRecord
  include BaseballCardValidations

  belongs_to :card_set
  belongs_to :player
  belongs_to :batting_style, optional: true
  belongs_to :pitching_style, optional: true
  belongs_to :pinch_pitching_style, class_name: "PitchingStyle", foreign_key: :pinch_pitching_style_id, optional: true
  belongs_to :catcher_pitching_style, class_name: "PitchingStyle", foreign_key: :catcher_pitching_style_id, optional: true

  has_many :player_card_player_types, dependent: :destroy
  has_many :player_types, through: :player_card_player_types
  has_many :competition_rosters, dependent: :destroy

  validates :card_set_id, :player_id, presence: true
  validates :card_set_id, uniqueness: { scope: :player_id }
end
