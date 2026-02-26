class PlayerCardExclusiveCatcher < ApplicationRecord
  self.primary_key = [ :player_card_id, :catcher_player_id ]

  belongs_to :player_card
  belongs_to :catcher_player, class_name: "Player", foreign_key: :catcher_player_id
end
