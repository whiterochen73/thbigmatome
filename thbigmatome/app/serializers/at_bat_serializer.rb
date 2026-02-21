class AtBatSerializer < ActiveModel::Serializer
  attributes :id, :game_id, :inning, :half, :seq, :batter_id, :pitcher_id, :result_code
end
