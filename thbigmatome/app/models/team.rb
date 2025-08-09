class Team < ApplicationRecord
  belongs_to :manager
  has_many :team_memberships, dependent: :destroy
  has_many :players, through: :team_memberships
  validates :name, presence: true
end
