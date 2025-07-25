class Team < ApplicationRecord
  belongs_to :manager
  validates :name, presence: true
end
