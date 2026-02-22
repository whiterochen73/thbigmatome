class Player < ApplicationRecord
  include BaseballCardValidations

  has_many :team_memberships, dependent: :destroy
  has_many :teams, through: :team_memberships

  belongs_to :batting_style, optional: true
  has_many :player_batting_skills, dependent: :destroy
  has_many :batting_skills, through: :player_batting_skills
  belongs_to :pitching_style, optional: true
  belongs_to :pinch_pitching_style, class_name: "PitchingStyle", foreign_key: :pinch_pitching_style_id, optional: true
  has_many :player_pitching_skills, dependent: :destroy
  has_many :pitching_skills, through: :player_pitching_skills

  has_many :player_player_types, dependent: :destroy
  has_many :player_types, through: :player_player_types
  has_many :player_biorhythms, dependent: :destroy
  has_many :cost_players, dependent: :destroy

  has_many :biorhythms, through: :player_biorhythms

  has_many :catchers_players, dependent: :destroy
  has_many :catchers, through: :catchers_players, source: :catcher

  has_many :partner_pitchers_players, class_name: "CatchersPlayer", foreign_key: "catcher_id"
  has_many :partner_pitchers, through: :partner_pitchers_players, source: :player, dependent: :destroy

  has_many :player_cards, dependent: :destroy
  has_many :at_bats_as_batter, class_name: "AtBat", foreign_key: :batter_id, dependent: :destroy, inverse_of: :batter
  has_many :at_bats_as_pitcher, class_name: "AtBat", foreign_key: :pitcher_id, dependent: :destroy, inverse_of: :pitcher
  has_many :pitcher_game_states, foreign_key: :pitcher_id, dependent: :destroy, inverse_of: :pitcher
  has_many :imported_stats, dependent: :destroy

  belongs_to :catcher_pitching_style, class_name: "PitchingStyle", foreign_key: :catcher_pitching_style_id, optional: true

  # ポジションをenumで定義
  enum :position, { pitcher: "pitcher", catcher: "catcher", infielder: "infielder", outfielder: "outfielder" }

  # 投打をenumで定義
  enum :throwing_hand, { right_throw: "right_throw", left_throw: "left_throw" }
  enum :batting_hand, { right_bat: "right_bat", left_bat: "left_bat", switch_hitter: "switch_hitter" }

  def batting_skill_ids
    player_batting_skills.map(&:batting_skill_id)
  end

  def player_type_ids
    player_player_types.map(&:player_type_id)
  end

  def biorhythm_ids
    player_biorhythms.map(&:biorhythm_id)
  end

  def pitching_skill_ids
    player_pitching_skills.map(&:pitching_skill_id)
  end

  def catcher_ids
    catchers_players.map(&:catcher_id)
  end

  def partner_pitcher_ids
    partner_pitchers_players.map(&:player_id)
  end
end
