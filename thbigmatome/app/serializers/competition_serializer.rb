class CompetitionSerializer < ActiveModel::Serializer
  attributes :id, :name, :year, :competition_type

  attribute :entry_count

  def entry_count
    object.competition_entries.count
  end
end
