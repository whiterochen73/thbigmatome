class Biorhythm < ApplicationRecord
  has_many :player_biorhythms, dependent: :restrict_with_error
  has_many :players, through: :player_biorhythms

  validates :name, presence: true, uniqueness: true
  validates :start_date, presence: true
  validates :end_date, presence: true
end