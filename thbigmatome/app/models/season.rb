class Season < ApplicationRecord
  belongs_to :team
  belongs_to :key_player, class_name: "TeamMembership", optional: true

  has_many :season_schedules, dependent: :destroy
  has_many :player_absences, dependent: :destroy

  # シーズンに題は付けない（画面はチーム名をタイトルにする）。列 name は NOT NULL のまま残してあるので、
  # 入力が無ければチーム名を入れる。既存の行には触れない。
  before_validation :default_name_from_team, on: :create

  validates :team_id, uniqueness: { message: :season_already_started }

  # 現在日は日程の結果から導く（SeasonCurrentRange）。列 current_date は日程が無いシーズンの初期値としてだけ読む。
  # 呼ぶたびに日程を引くので、ループの中では 1 度ローカルに取ってから使う。
  def current_range
    SeasonCurrentRange.for_season(self)
  end

  def current_date
    current_range&.current_date || super
  end

  private

  def default_name_from_team
    self.name = team&.name if name.blank?
  end
end
