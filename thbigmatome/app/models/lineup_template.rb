class LineupTemplate < ApplicationRecord
  belongs_to :team
  has_many :lineup_template_entries, dependent: :destroy
  accepts_nested_attributes_for :lineup_template_entries, allow_destroy: true

  validates :opponent_pitcher_hand, inclusion: { in: %w[left right] }
  validates :dh_enabled, inclusion: { in: [ true, false ] }
  validates :team_id, uniqueness: { scope: [ :dh_enabled, :opponent_pitcher_hand ] }
end
