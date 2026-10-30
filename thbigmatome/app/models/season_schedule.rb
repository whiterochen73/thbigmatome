class SeasonSchedule < ApplicationRecord
  belongs_to :season
  belongs_to :announced_starter, class_name: "TeamMembership", optional: true
  belongs_to :opponent_team, class_name: "Team", foreign_key: "opponent_team_id", optional: true
  belongs_to :winning_pitcher, class_name: "Player", optional: true
  belongs_to :losing_pitcher, class_name: "Player", optional: true
  belongs_to :save_pitcher, class_name: "Player", optional: true

  validates :home_away, inclusion: { in: [ "home", "visitor" ] }, allow_blank: true

  # 開催球場（IRC のチャンネル）。stadium（ゲーム内の球場）とは別の列。
  VENUES = %w[ch1 ch2 ch3 ch4 ch5 tlb].freeze
  # 大まかな開始時刻は 30 分刻み（"00:00"〜"23:30"）
  REAL_START_TIME_FORMAT = /\A([01]\d|2[0-3]):(00|30)\z/

  # 画面の「未選択」は空文字で届くことがある。日付列が空文字を nil にするのと揃え、空文字・空白だけは nil として保存する
  normalizes :real_start_time, :venue, with: ->(value) { value.presence }

  validates :real_start_time, format: { with: REAL_START_TIME_FORMAT }, allow_nil: true
  validates :venue, inclusion: { in: VENUES }, allow_nil: true

  # 試合ログの原文（解析はしない。保存するだけ）。上限は 1MB。文字数ではなくバイト数で数える（日本語は 1 文字 3 バイト）。
  # 空文字は null に正規化する（空白だけのログは内容として残すので presence は使わない）
  GAME_LOG_MAX_BYTES = 1_048_576
  normalizes :game_log, with: ->(value) { value.empty? ? nil : value }
  validate :game_log_within_limit
  validate :game_log_without_nul

  # 得点が保存・変更されたら、その試合の自チーム先発の result_category を作り直す（E2）。
  # 区分は登板記録の保存時にだけ計算されていたため、得点を後から直しても長イニング敗戦・KO が残っていた。
  # 得点が消された（未入力に戻った）時は「負けではない」として作り直す。
  # ノーゲーム（no_game）が立った・外れた時も作り直す（立てば no_game、外せば得点から戻す。cmd_1775 第3段 E12）。
  # 作り直しが想定外のエラーで落ちても、得点の保存は取り消さない（pitcher_rebuild_error に残し、呼び出し側が警告にする）。
  before_save { @pitcher_rebuild_error = nil }
  after_save :rebuild_pitcher_result_categories,
             if: -> { saved_change_to_score? || saved_change_to_opponent_score? || saved_change_to_no_game? }

  # 直近の保存で、投手の判定の作り直しが失敗した時の例外。成功・未実行なら nil。
  attr_reader :pitcher_rebuild_error

  # この試合日の自チームの登板記録の件数（pitcher_game_states の行数）。シーズン画面が入力漏れの印に使う。
  # 一覧を返す側（SeasonDetailSerializer）が日付ごとの件数をまとめて入れる（行ごとの問い合わせを避ける）。
  # 入っていない時は、この試合日の分だけ問い合わせて求める。
  attr_writer :pitcher_appearance_count

  def pitcher_appearance_count
    @pitcher_appearance_count ||= PitcherGameState.where(team_id: season.team_id, schedule_date: date.to_s).count
  end

  def calculated_game_number
    game_number || season.season_schedules
      .where(date_type: [ "game_day", "interleague_game_day" ])
      .where("date < ?", date)
      .count + 1
  end

  # シーズン画面の勝敗の印。ノーゲームは勝ち・負け・引き分けにせず result "no_game" を返し、得点も出さない
  # （得点が入っていても成績ではない。台帳 D-11 再確認 2026-10-26）。得点が未入力でもノーゲームの印は返す。
  def game_result_hash
    return { opponent_short_name: opponent_team&.short_name, score: nil, result: "no_game" } if no_game
    return nil if score.blank? || opponent_score.blank?

    result = if score > opponent_score then "win"
    elsif score < opponent_score then "lose"
    else "draw"
    end

    {
      opponent_short_name: opponent_team&.short_name,
      score: "#{score} - #{opponent_score}",
      result: result
    }
  end

  private

  # PostgreSQL の text 列は NUL 文字（\u0000）を保存できず、そのまま渡すと 500 になる。
  # ログは無加工で保存する方針なので NUL を取り除いて通さず、422 で断る（他の制御文字・タブは通す）。
  def game_log_without_nul
    return if game_log.nil? || !game_log.include?("\u0000")

    errors.add(:game_log, "に NUL 文字（\\u0000）は含められません。取り除いてから保存してください")
  end

  def game_log_within_limit
    return if game_log.nil? || game_log.bytesize <= GAME_LOG_MAX_BYTES

    errors.add(:game_log, "は #{GAME_LOG_MAX_BYTES} バイト（1MB）以下にしてください（現在 #{game_log.bytesize} バイト）")
  end

  # 作り直しは得点の保存と同じトランザクションの中で走る。落ちた時に得点ごと取り消さないよう、次の 2 点を守る。
  #   1. セーブポイント（requires_new）の中で走らせる。PostgreSQL は SQL エラーでトランザクション全体が中断状態になり、
  #      後続の文もすべて失敗するため。失敗したら作り直しの途中の書き込みだけが戻る
  #   2. 例外は握ってログに残し、pitcher_rebuild_error に持つ（作り直しは後で rake で再実行できる）
  def rebuild_pitcher_result_categories
    self.class.transaction(requires_new: true) do
      PitcherResultCategoryRebuilder.new(apply: true, unscored: :not_loss)
                                    .rebuild_for_schedule(self, recompute_no_game: saved_change_to_no_game?)
    end
  rescue StandardError => e
    @pitcher_rebuild_error = e
    Rails.logger.error(
      "[PitcherResultCategoryRebuilder] 判定の作り直しに失敗（得点は保存済み） season_schedule_id=#{id} " \
      "#{e.class}: #{e.message}\n#{Array(e.backtrace).first(10).join("\n")}"
    )
  end
end
