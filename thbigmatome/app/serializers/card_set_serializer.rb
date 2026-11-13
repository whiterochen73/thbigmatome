class CardSetSerializer < ActiveModel::Serializer
  attributes :id, :year, :set_type, :name, :is_current
end
