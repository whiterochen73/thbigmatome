class Stadium < ApplicationRecord
  has_many :games, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true
  validates :code, presence: true, uniqueness: true
end
