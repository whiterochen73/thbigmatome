class CreateManagers < ActiveRecord::Migration[8.0]
  def change
    create_table :managers do |t|
      t.string :name
      t.string :short_name
      t.string :irc_name
      t.string :user_id

      t.timestamps
    end
  end
end
