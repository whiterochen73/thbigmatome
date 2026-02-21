class CardSetSerializer < ActiveModel::Serializer
  attributes :id, :year, :set_type, :name
end
