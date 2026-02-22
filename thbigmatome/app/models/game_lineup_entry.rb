class GameLineupEntry < ApplicationRecord
  belongs_to :game
  belongs_to :player_card

  enum :role, { starter: 0, bench: 1, off: 2, designated_player: 3 }

  validates :batting_order, numericality: { in: 1..9 }, allow_nil: true
  validates :batting_order, uniqueness: { scope: :game_id }, allow_nil: true
  validates :position, inclusion: { in: %w[P C 1B 2B 3B SS LF CF RF DH] }, allow_nil: true

  validate :starter_requires_batting_order_and_position

  private

  def starter_requires_batting_order_and_position
    return unless starter?

    errors.add(:batting_order, "は先発の場合必須です") if batting_order.nil?
    errors.add(:position, "は先発の場合必須です") if position.nil?
  end
end
