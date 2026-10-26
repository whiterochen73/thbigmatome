class Game < ApplicationRecord
  belongs_to :competition, optional: true
  belongs_to :home_team, class_name: "Team", inverse_of: :home_games
  belongs_to :visitor_team, class_name: "Team", inverse_of: :visitor_games
  belongs_to :stadium, optional: true
  has_many :at_bats, dependent: :destroy
  has_many :game_events, dependent: :destroy
  has_many :pitcher_game_states, dependent: :destroy
  has_many :game_lineup_entries, dependent: :destroy
  has_one :game_record, dependent: :nullify

  # ノーゲームの試合を除く。成績（チーム勝敗・得失点・打撃・投手成績）の集計はこの絞り込みを通す（台帳 D-11。NoGameGames 参照）
  scope :excluding_no_game, -> { where.not(id: NoGameGames.ids) }

  validates :status, inclusion: { in: %w[draft confirmed] }
  validates :source, inclusion: { in: %w[live log_import summary] }

  def draft?
    status == "draft"
  end
end
