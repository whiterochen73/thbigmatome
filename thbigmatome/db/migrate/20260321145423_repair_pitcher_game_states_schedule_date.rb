class RepairPitcherGameStatesScheduleDate < ActiveRecord::Migration[8.1]
  def up
    # schedule_date が NULL のレコードを game.home_schedule_date で補完
    execute <<~SQL
      UPDATE pitcher_game_states
      SET schedule_date = games.home_schedule_date
      FROM games
      WHERE pitcher_game_states.game_id = games.id
        AND pitcher_game_states.schedule_date IS NULL
        AND games.home_schedule_date IS NOT NULL
    SQL
  end

  def down
    # rollback はデータ修復のため対応しない
  end
end
