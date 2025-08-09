class Schedule < ApplicationRecord
  has_many :schedule_details, dependent: :destroy
end
