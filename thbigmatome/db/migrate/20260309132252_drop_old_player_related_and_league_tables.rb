class DropOldPlayerRelatedAndLeagueTables < ActiveRecord::Migration[8.1]
  def up
    # Phase 2b: 旧プレイヤー結合テーブル廃止 (全0レコード)
    drop_table :catchers_players
    drop_table :player_biorhythms
    drop_table :player_batting_skills
    drop_table :player_pitching_skills
    drop_table :player_player_types

    # Phase 3: league系5テーブル廃止
    drop_table :league_pool_players
    drop_table :league_games
    drop_table :league_memberships
    drop_table :league_seasons
    drop_table :leagues

    # Phase 3: batting_skills / pitching_skills マスタ廃止
    drop_table :batting_skills
    drop_table :pitching_skills
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
