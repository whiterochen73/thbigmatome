class PitcherGameState < ApplicationRecord
  belongs_to :game
  belongs_to :pitcher, class_name: "Player"
  belongs_to :competition, optional: true
  belongs_to :team

  VALID_DECISIONS = %w[W L S H].freeze

  validates :pitcher_id, uniqueness: { scope: :game_id }
  validates :role, inclusion: { in: %w[starter reliever opener] }
  validates :result_category, inclusion: { in: %w[normal ko no_game long_loss] }, allow_nil: true
  validates :injury_check, inclusion: { in: %w[safe injured] }, allow_nil: true
  validates :earned_runs, numericality: { greater_than_or_equal_to: 0 }
  validates :decision, inclusion: { in: VALID_DECISIONS + [ nil ] }
  validates :is_opener, inclusion: { in: [ true, false ] }
  validates :consecutive_short_rest_count, numericality: { greater_than_or_equal_to: 0 }
  validates :pre_injury_days_excluded, numericality: { greater_than_or_equal_to: 0 }

  # result_category 自動計算ロジック
  # game_result: "win" / "lose" / "draw" / "no_game"
  # pitchers_in_game: この試合のこのチームの投手総数（新規追加分含む）
  # fatigue_p: カード記載の先発疲労P（long_loss判定に使用）。0/nil の場合はデフォルト3を適用（ルール§8.3）
  DEFAULT_STARTER_FATIGUE_P = 3

  def self.calculate_result_category(role:, innings_pitched:, game_result:, pitchers_in_game:, fatigue_p: 0, decision: nil)
    return "no_game" if game_result == "no_game"
    return "normal" unless role == "starter"

    has_successor = pitchers_in_game > 1
    innings = innings_pitched.to_f
    fp = fatigue_p.to_i
    # ルール§8.3: 先発疲労P未記載の投手が先発した場合、先発疲労P=3として扱う
    fp = DEFAULT_STARTER_FATIGUE_P if fp == 0
    if innings > 0 && innings < 5 && has_successor && game_result == "lose" && decision == "L"
      "ko"
    elsif game_result == "lose" && innings > fp + 1
      "long_loss"
    else
      "normal"
    end
  end
end
