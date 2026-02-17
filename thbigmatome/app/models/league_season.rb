class LeagueSeason < ApplicationRecord
  belongs_to :league
  has_many :league_games, dependent: :destroy
  has_many :league_pool_players, dependent: :destroy
  has_many :pool_players, through: :league_pool_players, source: :player

  enum :status, { pending: 0, active: 1, completed: 2 }

  validates :name, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :status, presence: true
  validates :end_date, comparison: { greater_than_or_equal_to: :start_date }

  def generate_schedule
    teams = league.teams.to_a # リーグに所属するチームを取得
    return if teams.size != 6 # 6チーム制であることを確認

    current_date = start_date
    game_count = 0

    # 総当たり組み合わせを生成
    teams.combination(2).each do |team1, team2|
      # team1 ホーム vs team2 アウェイ
      3.times do |i|
        if game_count > 0 && game_count % 6 == 0
          current_date += 1.day # 6試合ごとに1日休養日
        end
        LeagueGame.create!(
          league_season: self,
          home_team: team1,
          away_team: team2,
          game_date: current_date,
          game_number: i + 1
        )
        game_count += 1
        current_date += 1.day # 試合ごとに日付を進める
      end

      # team2 ホーム vs team1 アウェイ
      3.times do |i|
        if game_count > 0 && game_count % 6 == 0
          current_date += 1.day # 6試合ごとに1日休養日
        end
        LeagueGame.create!(
          league_season: self,
          home_team: team2,
          away_team: team1,
          game_date: current_date,
          game_number: i + 1
        )
        game_count += 1
        current_date += 1.day # 試合ごとに日付を進める
      end
    end
  end
end
