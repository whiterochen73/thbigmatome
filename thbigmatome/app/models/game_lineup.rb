class GameLineup < ApplicationRecord
  belongs_to :team

  validates :lineup_data, presence: true
end
