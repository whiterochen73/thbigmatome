class Cost < ApplicationRecord
  has_many :cost_players, dependent: :destroy
  has_many :players, through: :cost_players

  validates :name, presence: true
  validates :start_date, presence: true

  def self.current_cost
    Cost.where(end_date: nil).first
  end
end