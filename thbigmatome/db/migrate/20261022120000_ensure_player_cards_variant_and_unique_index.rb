# player_cards.variant 列と、それを含む一意索引を repo の履歴に取り込む。
#
# 本番 DB には variant 列と式索引が migration を通さず手で足されており、
# repo 側（db/schema.rb）にだけ存在しなかった。本番では何も変更せず
# schema_migrations に version が記録されるだけになるよう、全工程を冪等にしてある。
# （本番 rails コンテナは起動時に db:prepare を走らせるため、冪等性が壊れると起動できない）
class EnsurePlayerCardsVariantAndUniqueIndex < ActiveRecord::Migration[8.1]
  OLD_INDEX = "index_player_cards_on_card_set_player_card_type".freeze
  NEW_INDEX = "index_player_cards_on_card_set_player_card_type_variant".freeze

  def up
    add_column :player_cards, :variant, :string unless column_exists?(:player_cards, :variant)

    unless index_name_exists?(:player_cards, NEW_INDEX)
      execute <<~SQL.squish
        CREATE UNIQUE INDEX #{NEW_INDEX}
        ON player_cards (card_set_id, player_id, card_type, COALESCE(variant, ''::character varying))
      SQL
    end

    remove_index :player_cards, name: OLD_INDEX if index_name_exists?(:player_cards, OLD_INDEX)
  end

  # variant 列は戻さない（削除しない）。本番では本 migration より前から存在した列で、
  # 列を落とすとデータを失う。索引だけを旧状態へ戻す。
  def down
    remove_index :player_cards, name: NEW_INDEX if index_name_exists?(:player_cards, NEW_INDEX)

    unless index_name_exists?(:player_cards, OLD_INDEX)
      add_index :player_cards, [ :card_set_id, :player_id, :card_type ], unique: true, name: OLD_INDEX
    end
  end
end
