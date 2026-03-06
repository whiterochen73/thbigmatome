class SquadTextSetting < ApplicationRecord
  belongs_to :team

  BATTING_STATS_DEFAULTS = {
    "avg" => true, "hr" => true, "rbi" => true,
    "sb" => false, "obp" => false, "ops" => false,
    "ab_h" => false
  }.freeze

  PITCHING_STATS_DEFAULTS = {
    "w_l" => true, "games" => true, "era" => true,
    "so" => true, "ip" => true,
    "hold" => false, "save" => false
  }.freeze

  after_initialize :set_defaults

  private

  def set_defaults
    self.batting_stats_config = BATTING_STATS_DEFAULTS.merge(batting_stats_config || {})
    self.pitching_stats_config = PITCHING_STATS_DEFAULTS.merge(pitching_stats_config || {})
  end
end
