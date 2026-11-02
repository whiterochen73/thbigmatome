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

  # ノーゲームの試合を除く（台帳 D-11。NoGameGames 参照）。2026-11 時点で app 内の呼び出し元は無い
  # （成績を集計していた画面・API は cmd_1795 で削除した）。成績の集計を作り直す時は、この絞り込みを通すこと
  scope :excluding_no_game, -> { where.not(id: NoGameGames.ids) }

  validates :status, inclusion: { in: %w[draft confirmed] }
  # log_import は取り込み機能の廃止（cmd_1791）前に作られた既存データの値。新規には作られないが、既存行を保存し直せるよう許可値に残す
  validates :source, inclusion: { in: %w[live log_import summary] }

  def draft?
    status == "draft"
  end
end
