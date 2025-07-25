class Manager < ApplicationRecord
  has_many :teams, dependent: :destroy
  validates :name, presence: true
end
