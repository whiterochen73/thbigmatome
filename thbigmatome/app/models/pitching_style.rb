class PitchingStyle < ApplicationRecord
  has_many :players, dependent: :restrict_with_error, foreign_key: :pitching_style_id

  validates :name, presence: true, uniqueness: true
end
