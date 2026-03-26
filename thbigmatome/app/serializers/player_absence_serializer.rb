class PlayerAbsenceSerializer < ActiveModel::Serializer
  attributes :id, :team_membership_id, :season_id, :absence_type, :reason, :start_date, :duration, :duration_unit, :player_name, :player_id, :effective_end_date

  def player_name
    object.team_membership.player.name
  end

  def player_id
    object.team_membership.player_id
  end
end
