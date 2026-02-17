class Biorhythm < ApplicationRecord
  has_many :player_biorhythms, dependent: :restrict_with_error
  has_many :players, through: :player_biorhythms

  validates :name, presence: true, uniqueness: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_date_after_start_date

  private

  def end_date_after_start_date
    if start_date.present? && end_date.present? && start_date > end_date
      errors.add(:end_date, :after_start_date)
    end
  end
end
