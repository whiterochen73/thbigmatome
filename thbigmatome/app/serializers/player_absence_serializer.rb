class PlayerAbsenceSerializer < ActiveModel::Serializer
  attributes :id, :team_membership_id, :season_id, :absence_type, :reason, :start_date, :duration, :duration_unit, :player_name, :effective_end_date

  def player_name
    object.team_membership.player.name
  end
end
