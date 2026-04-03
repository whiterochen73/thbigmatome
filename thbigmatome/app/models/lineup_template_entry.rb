class LineupTemplateEntry < ApplicationRecord
  belongs_to :lineup_template
  belongs_to :player

  validates :batting_order, inclusion: { in: 1..9 }
  validates :position, presence: true
end
