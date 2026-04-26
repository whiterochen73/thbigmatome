module CooldownCalculable
  extend ActiveSupport::Concern

  private

  # Rule 3: Cooldown calculation with same-day exemption info
  # Returns { cooldown_until: Date|nil, same_day_exempt: boolean, demotion_date: Date|nil }
  def calculate_cooldown_info(team_membership, current_date)
    last_demotion = team_membership.season_rosters
                      .where(squad: "second")
                      .where("registered_on <= ?", current_date)
                      .order(registered_on: :desc, created_at: :desc)
                      .first

    return { cooldown_until: nil, same_day_exempt: false, demotion_date: nil } unless last_demotion

    # Find the most recent promotion before this demotion (including same-day entries)
    previous_promotion = team_membership.season_rosters
                           .where(squad: "first")
                           .where(
                             "registered_on < :date OR (registered_on = :date AND created_at < :cat)",
                             date: last_demotion.registered_on, cat: last_demotion.created_at
                           )
                           .order(registered_on: :desc, created_at: :desc)
                           .first

    return { cooldown_until: nil, same_day_exempt: false, demotion_date: nil } unless previous_promotion

    cooldown_end_date = last_demotion.registered_on + 10.days
    return { cooldown_until: nil, same_day_exempt: false, demotion_date: nil } unless current_date < cooldown_end_date

    same_day = previous_promotion.registered_on == last_demotion.registered_on
    { cooldown_until: cooldown_end_date, same_day_exempt: same_day, demotion_date: last_demotion.registered_on }
  end
end
