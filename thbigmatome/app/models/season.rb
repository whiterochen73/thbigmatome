class Season < ApplicationRecord
  belongs_to :team
  belongs_to :key_player, class_name: 'TeamMembership', optional: true

  has_many :season_schedules, dependent: :destroy
  validates :name, presence: true
  validates :team_id, uniqueness: { message: 'は既にシーズンが開始されています。' }
end
