# チーム編成の変更記録 1 件（cmd_1784 段2）。登録（join）・契約の変更（contract）・放出（release）を、日付と区分つきで残す。
# 設計: context/thbig-dugout-season-record-restructure-design.md §4.2。変更後の値を丸ごと持つ（差分ではない）。
class TeamMembershipChange < ApplicationRecord
  KINDS = %w[join contract release].freeze
  PHASES = SeasonRoster::PHASES
  COST_TYPES = %w[normal_cost relief_only_cost pitcher_only_cost fielder_only_cost two_way_cost].freeze

  belongs_to :team_membership
  belongs_to :season
  belongs_to :player_card, optional: true
  belongs_to :recorded_by_user, class_name: "User", optional: true

  validates :effective_on, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :phase, inclusion: { in: PHASES }
  validates :selected_cost_type, presence: true, inclusion: { in: COST_TYPES }

  # 在籍の初期記録（join）の日付。選手の最初の昇降格の日、無ければシーズン開始日（日程の最初の日）。
  # 昇降格の記録がシーズン開始日より前にあれば、そちらを取る（その日にはすでにチームにいたはず）。どちらも無ければ nil
  def self.initial_join_date(first_roster_date, season_start)
    [ first_roster_date, season_start ].compact.min
  end
end
