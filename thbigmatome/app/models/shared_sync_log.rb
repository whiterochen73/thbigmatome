class SharedSyncLog < ApplicationRecord
  VALID_STATUSES = %w[success failed dry_run].freeze

  validates :resource_type, presence: true
  validates :status, inclusion: { in: VALID_STATUSES }
  validates :synced_at, presence: true

  scope :recent, -> { order(synced_at: :desc) }

  def self.last_sync_for(resource_type)
    where(resource_type: resource_type, status: "success").order(synced_at: :desc).first
  end
end
