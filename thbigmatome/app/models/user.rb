class User < ApplicationRecord
  has_secure_password
  validates :name, presence: true, uniqueness: true
  validates :display_name, presence: true

  enum :role, { player: 0, commissioner: 1 }

  has_many :teams, foreign_key: :user_id, dependent: :nullify
end
