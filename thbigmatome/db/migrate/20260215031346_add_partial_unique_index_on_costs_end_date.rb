class AddPartialUniqueIndexOnCostsEndDate < ActiveRecord::Migration[8.0]
  def change
    add_index :costs, :end_date, unique: true, where: "end_date IS NULL", name: "index_costs_on_active"
  end
end
