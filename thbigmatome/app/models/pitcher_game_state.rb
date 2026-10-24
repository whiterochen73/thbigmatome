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
  # game_result: "win" / "lose" / "draw" / "no_game"（試合概要の得点から求めた値。PitcherGameResult 参照）
  # pitchers_in_game: この試合のこのチームの投手総数（新規追加分含む）
  # fatigue_p: 試合前のスタミナ補正をかけた先発の疲労P（PitcherStarterFatigue が求める）。
  #   0 は「補正の結果 0」を意味する正当な値。カード未記載の既定 3 は呼び出し側（PitcherStarterFatigue）が
  #   カード値として 3 を入れる。nil は「疲労P を特定できない」で、判定に疲労P が要る場合は nil（判定保留）を返す。
  # prior_outs: 同じ試合で自分より前に投げた同チーム投手の通算アウト数（関与イニングの算出に使う）
  # no_out_exit: 0アウト降板フラグ。trueの場合、関与イニングに +1（長イニング敗戦のみ。KO には掛けない）
  DEFAULT_STARTER_FATIGUE_P = 3

  # 戻り値: "normal" / "ko" / "long_loss" / "no_game" / nil（判定保留: 疲労P が必要なのに fatigue_p が nil）
  def self.calculate_result_category(role:, innings_pitched:, game_result:, pitchers_in_game:, fatigue_p: nil, decision: nil, no_out_exit: false, prior_outs: 0)
    return "no_game" if game_result == "no_game"
    return "normal" unless role == "starter"

    has_successor = pitchers_in_game > 1
    # KO は実際に投げたイニングで判定する（§8.2.4 の +1 は長イニング敗戦と累積イニングの適用範囲。E11）
    pitched = innings_pitched.to_f
    if pitched > 0 && pitched < 5 && has_successor && game_result == "lose" && decision == "L"
      return "ko"
    end
    return "normal" unless game_result == "lose"

    # 長イニング敗戦: 関与イニング（§8.2.4）> 補正後の疲労P + 1
    involved = PitcherInnings.involvement(innings_pitched, prior_outs: prior_outs, no_out_exit: no_out_exit)
    # 疲労P は 0 以上なので、関与 1 以下なら疲労P が分からなくても normal と決まる
    return "normal" if involved <= 1
    return nil if fatigue_p.nil?

    involved > fatigue_p.to_i + 1 ? "long_loss" : "normal"
  end
end
