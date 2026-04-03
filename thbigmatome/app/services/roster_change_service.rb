class RosterChangeService
  def initialize(team, season_id, since_date)
    @team = team
    @season_id = season_id
    @since_date = since_date.is_a?(Date) ? since_date : Date.parse(since_date.to_s)
  end

  def call
    rosters = SeasonRoster
      .joins(team_membership: :player)
      .where(season_id: @season_id, team_memberships: { team_id: @team.id })
      .where("season_rosters.registered_on > ?", @since_date)
      .order("season_rosters.registered_on ASC")
      .select("season_rosters.squad, season_rosters.registered_on, players.name AS player_name, players.number, players.id AS player_id")

    changes = rosters.map do |r|
      {
        type: r.squad == "first" ? "promote" : "demote",
        player_id: r.player_id,
        player_name: r.player_name,
        number: r.number,
        date: r.registered_on.to_s
      }
    end

    promotes = changes.select { |c| c[:type] == "promote" }
    demotes  = changes.select { |c| c[:type] == "demote" }

    text_lines = []
    promotes.each { |c| text_lines << "登録：#{c[:number]} #{c[:player_name]}" }
    demotes.each  { |c| text_lines << "抹消：#{c[:number]} #{c[:player_name]}" }

    { changes: changes, text: text_lines.join("\n") }
  end
end
