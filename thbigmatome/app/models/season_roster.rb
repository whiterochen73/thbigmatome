class SeasonRoster < ApplicationRecord
  belongs_to :season
  belongs_to :team_membership

  validates :squad, presence: true
  validates :registered_on, presence: true
end