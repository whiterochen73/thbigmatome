class PitcherGameState < ApplicationRecord
  belongs_to :game
  belongs_to :pitcher, class_name: "Player"
  belongs_to :competition, optional: true
  belongs_to :team
  # 登板した試合日の日程の行（cmd_1784 段3）。対応する日程の行が無い登板（日程の無いチーム・日程の外の日付）は nil のまま残す
  belongs_to :season_schedule, optional: true

  # 保存する時に、（チーム, 試合日）から日程の行を引いて紐づける。呼び出し側（登板の保存・rake）が個別に埋めない
  before_validation :link_season_schedule, if: :link_season_schedule?

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

  # チーム・試合日の日程の行の id。ちょうど 1 件に決まる時だけ返す（0 件 = 日程の外、2 件以上 = 決められない）。日付が読めなければ nil
  def self.schedule_id_for(team_id:, date:)
    parsed = parse_schedule_date(date)
    return nil if parsed.nil?

    ids = SeasonSchedule.of_team_on(team_id, parsed).limit(2).pluck(:id)
    ids.one? ? ids.first : nil
  end

  # そのチームのその試合日の登板。日程の行に紐づく登板（season_schedule_id）を正とし、まだ紐づけていない登板（rake の前・
  # 日程の外の日付）は schedule_date で拾う。日程の行が 1 件に決まらない日は schedule_date だけで引く
  def self.on_day(team_id:, date:)
    date_str = date.to_s
    in_team = where(team_id: team_id)
    parsed = parse_schedule_date(date_str)
    schedule_ids = parsed ? SeasonSchedule.of_team_on(team_id, parsed).pluck(:id) : []
    return in_team.where(schedule_date: date_str) unless schedule_ids.one?

    in_team.where(season_schedule_id: schedule_ids.first).or(in_team.where(season_schedule_id: nil, schedule_date: date_str))
  end

  def self.parse_schedule_date(value)
    Date.iso8601(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  # result_category 自動計算ロジック
  # game_result: "win" / "lose" / "draw" / "no_game"（試合概要の得点から求めた値。PitcherGameResult 参照）
  # pitchers_in_game: この試合のこのチームの投手総数（新規追加分含む）
  # fatigue_p: 試合前のスタミナ補正をかけた先発の疲労P（PitcherStarterFatigue が求める）。
  #   0 は「補正の結果 0」を意味する正当な値。カード未記載の既定 3 は呼び出し側（PitcherStarterFatigue）が
  #   カード値として 3 を入れる。nil は「疲労P を特定できない」で、判定に疲労P が要る場合は nil（判定保留）を返す。
  # prior_outs: 同じ試合で自分より前に投げた同チーム投手の通算アウト数（関与イニングの算出に使う）
  # no_out_exit: 0アウト降板フラグ。trueの場合、関与イニングに +1（長イニング敗戦のみ。KO には掛けない）。
  #   ただし投球回 0.0 でも true なら「登板した」ものとして KO の対象にする
  DEFAULT_STARTER_FATIGUE_P = 3

  # 戻り値: "normal" / "ko" / "long_loss" / "no_game" / nil（判定保留: 疲労P が必要なのに fatigue_p が nil）
  def self.calculate_result_category(role:, innings_pitched:, game_result:, pitchers_in_game:, fatigue_p: nil, decision: nil, no_out_exit: false, prior_outs: 0)
    return "no_game" if game_result == "no_game"
    return "normal" unless role == "starter"

    has_successor = pitchers_in_game > 1
    # KO は実際に投げたイニングで判定する（§8.2.4 の +1 は長イニング敗戦と累積イニングの適用範囲。E11）
    # 0.0 回でも no_out_exit（1つもアウトを取れず降板）なら「登板した」ので KO の対象（AMB-20 追補・Operator 裁定 2026-10-25）。
    # 5.0 回以上（6 イニング目に上がった 0アウト降板を含む）は < 5 を満たさず KO にならない。
    pitched = innings_pitched.to_f
    if (pitched > 0 || no_out_exit) && pitched < 5 && has_successor && game_result == "lose" && decision == "L"
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

  private

  def link_season_schedule?
    (new_record? || will_save_change_to_schedule_date?) && !will_save_change_to_season_schedule_id?
  end

  def link_season_schedule
    self.season_schedule_id = self.class.schedule_id_for(team_id: team_id, date: schedule_date)
  end
end
