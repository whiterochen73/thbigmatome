class Cost < ApplicationRecord
  has_many :cost_players, dependent: :destroy
  has_many :players, through: :cost_players

  validates :name, presence: true
  validates :start_date, presence: true
end