class Biorhythm < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :start_date, presence: true
  validates :end_date, presence: true
end