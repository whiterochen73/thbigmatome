class User < ApplicationRecord
  has_secure_password
  validates :name, presence: true, uniqueness: true
  validates :display_name, presence: true
end
