class SeasonSchedule < ApplicationRecord
  belongs_to :season
  belongs_to :announced_starter, class_name: 'TeamMembership', optional: true
  belongs_to :opponent_team, class_name: 'Team', foreign_key: 'oppnent_team_id', optional: true
  belongs_to :winning_pitcher, class_name: 'Player', optional: true
  belongs_to :losing_pitcher, class_name: 'Player', optional: true
  belongs_to :save_pitcher, class_name: 'Player', optional: true
end
