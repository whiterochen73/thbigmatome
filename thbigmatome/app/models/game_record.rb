class GameRecord < ApplicationRecord
  belongs_to :team
  has_many :at_bat_records, dependent: :destroy

  VALID_STATUSES = %w[draft confirmed].freeze
  VALID_RESULTS = %w[win lose draw].freeze

  validates :status, inclusion: { in: VALID_STATUSES }
  validates :result, inclusion: { in: VALID_RESULTS }, allow_nil: true

  scope :draft, -> { where(status: "draft") }
  scope :confirmed, -> { where(status: "confirmed") }

  def draft?
    status == "draft"
  end

  def confirmed?
    status == "confirmed"
  end
end
