class GameLineupEntry < ApplicationRecord
  GAME_RULES = YAML.load_file(Rails.root.join("config", "game_rules.yaml")).freeze
  BATTING_ORDER_MIN = GAME_RULES.dig("thbig_baseball", "game", "batting_order", "min")
  BATTING_ORDER_MAX = GAME_RULES.dig("thbig_baseball", "game", "batting_order", "max")

  belongs_to :game
  belongs_to :player_card

  enum :role, { starter: 0, bench: 1, off: 2, designated_player: 3 }

  validates :batting_order, numericality: { in: BATTING_ORDER_MIN..BATTING_ORDER_MAX }, allow_nil: true
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
