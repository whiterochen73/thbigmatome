class CatchersPlayer < ApplicationRecord
  belongs_to :player
  belongs_to :catcher, class_name: 'Player'
end