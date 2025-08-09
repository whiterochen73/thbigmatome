class ScheduleSerializer < ActiveModel::Serializer
  attributes :id, :name, :start_date, :end_date, :effective_date
end