class Team < ApplicationRecord
  belongs_to :manager

  has_one :season, dependent: :restrict_with_error
  has_many :team_memberships, dependent: :destroy
  has_many :players, through: :team_memberships
  validates :name, presence: true
end
