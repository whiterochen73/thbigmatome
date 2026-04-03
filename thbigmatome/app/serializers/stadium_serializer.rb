class StadiumSerializer < ActiveModel::Serializer
  attributes :id, :code, :name, :up_table_ids, :indoor
end
