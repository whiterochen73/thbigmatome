# db/scripts/cleanup_duplicate_players_527.rb
# cmd_527 重複Player削除スクリプト
#
# 問題: import:card_data が名前の完全一致でマッチするため、
#       全角スペース（元DB）vs 半角スペース（CSV）の違いで197件の重複Playerが作成された。
#
# 方針:
#   - 正規化名（スペース除去）でグループ化
#   - 各グループでIDが最小のPlayerを「元Player」として残す
#   - 重複PlayerのPlayerCard/TeamMembership/CostPlayerを元Playerに移動
#   - 重複Playerを削除
#
# Usage:
#   DRY_RUN=true  bundle exec rails runner db/scripts/cleanup_duplicate_players_527.rb
#   DRY_RUN=false bundle exec rails runner db/scripts/cleanup_duplicate_players_527.rb

dry_run = ENV.fetch("DRY_RUN", "true") != "false"
puts "=== cleanup_duplicate_players_527.rb ==="
puts "MODE: #{dry_run ? 'DRY RUN (no changes)' : 'EXECUTE'}"
puts

# 正規化名でグループ化
all_players = Player.all.to_a
grouped = all_players.group_by { |p| p.name.gsub(/[\s\u3000]+/, '') }
dup_groups = grouped.select { |_, v| v.size > 1 }

puts "重複グループ数: #{dup_groups.size}"
total_to_delete = dup_groups.sum { |_, v| v.size - 1 }
puts "削除対象Player数: #{total_to_delete}"
puts

merged_players   = 0
merged_pcs       = 0
merged_tms       = 0
merged_cps       = 0
conflict_pcs     = 0
skipped_groups   = 0

dup_groups.each do |norm_name, players_in_group|
  sorted = players_in_group.sort_by(&:id)
  original = sorted.first
  duplicates = sorted[1..]

  puts "[GROUP] 正規化名=#{norm_name.inspect}"
  puts "  元Player: id=#{original.id} name=#{original.name.inspect}"
  duplicates.each { |d| puts "  重複Player: id=#{d.id} name=#{d.name.inspect}" }

  duplicates.each do |dup|
    # --- PlayerCard 移動 ---
    dup_pcs = PlayerCard.where(player_id: dup.id)
    dup_pcs.each do |pc|
      # 同じcard_set+card_typeが元Playerに既に存在するか確認
      conflict = PlayerCard.find_by(player_id: original.id, card_set_id: pc.card_set_id, card_type: pc.card_type)
      if conflict
        conflict_pcs += 1
        puts "  CONFLICT: PlayerCard id=#{pc.id} (card_set=#{pc.card_set_id}, type=#{pc.card_type}) vs existing id=#{conflict.id}"
        # Active Storageはpc.idで参照されているため、pcを削除する前にattachmentを確認
        attachments = ActiveStorage::Attachment.where(record_type: "PlayerCard", record_id: pc.id)
        if attachments.any?
          puts "  WARN: PlayerCard id=#{pc.id} has #{attachments.count} attachments — will move to surviving card"
          unless dry_run
            # attachmentを既存カード(conflict)に付け替え
            attachments.update_all(record_id: conflict.id)
          end
        end
        # 重複PlayerCardのtrait/defense等を元Playerカードに移行 (simple: 削除のみ、データは元側を信頼)
        unless dry_run
          PlayerCardDefense.where(player_card_id: pc.id).destroy_all
          PlayerCardTrait.where(player_card_id: pc.id).destroy_all
          PlayerCardExclusiveCatcher.where(player_card_id: pc.id).destroy_all
          pc.destroy!
        end
      else
        # 競合なし: player_idを更新
        puts "  MOVE: PlayerCard id=#{pc.id} (card_set=#{pc.card_set_id}, type=#{pc.card_type}) → player_id=#{original.id}"
        unless dry_run
          pc.update_column(:player_id, original.id)
        end
        merged_pcs += 1
      end
    end

    # --- TeamMembership 移動 ---
    tms = TeamMembership.where(player_id: dup.id)
    tms.each do |tm|
      conflict_tm = TeamMembership.find_by(player_id: original.id, team_id: tm.team_id,
                                           squad: tm.squad)
      if conflict_tm
        puts "  CONFLICT TM: TeamMembership id=#{tm.id} conflicts with id=#{conflict_tm.id} — deleting dup"
        tm.destroy! unless dry_run
      else
        puts "  MOVE TM: TeamMembership id=#{tm.id} → player_id=#{original.id}"
        tm.update_column(:player_id, original.id) unless dry_run
        merged_tms += 1
      end
    end

    # --- SeasonSchedule pitcher references 更新 ---
    [ 'winning_pitcher_id', 'losing_pitcher_id', 'save_pitcher_id' ].each do |col|
      count = ActiveRecord::Base.connection.execute(
        "SELECT COUNT(*) FROM season_schedules WHERE #{col} = #{dup.id}"
      ).first['count'].to_i
      if count > 0
        puts "  MOVE SS #{col}: #{count}件 → player_id=#{original.id}"
        ActiveRecord::Base.connection.execute(
          "UPDATE season_schedules SET #{col} = #{original.id} WHERE #{col} = #{dup.id}"
        ) unless dry_run
      end
    end

    # --- PlayerPlayerType 移動 ---
    ppts = ActiveRecord::Base.connection.execute(
      "SELECT id, player_type_id FROM player_player_types WHERE player_id = #{dup.id}"
    )
    ppts.each do |ppt|
      conflict = ActiveRecord::Base.connection.execute(
        "SELECT id FROM player_player_types WHERE player_id = #{original.id} AND player_type_id = #{ppt['player_type_id']}"
      ).first
      if conflict
        puts "  CONFLICT PPT: player_type_id=#{ppt['player_type_id']} already on original — deleting dup"
        ActiveRecord::Base.connection.execute("DELETE FROM player_player_types WHERE id = #{ppt['id']}") unless dry_run
      else
        puts "  MOVE PPT: player_type_id=#{ppt['player_type_id']} → player_id=#{original.id}"
        ActiveRecord::Base.connection.execute(
          "UPDATE player_player_types SET player_id = #{original.id} WHERE id = #{ppt['id']}"
        ) unless dry_run
      end
    end

    # --- PlayerPitchingSkill 移動 ---
    ppss = ActiveRecord::Base.connection.execute(
      "SELECT id, pitching_skill_id FROM player_pitching_skills WHERE player_id = #{dup.id}"
    )
    ppss.each do |pps|
      conflict = ActiveRecord::Base.connection.execute(
        "SELECT id FROM player_pitching_skills WHERE player_id = #{original.id} AND pitching_skill_id = #{pps['pitching_skill_id']}"
      ).first
      if conflict
        puts "  CONFLICT PPS: pitching_skill_id=#{pps['pitching_skill_id']} already on original — deleting dup"
        ActiveRecord::Base.connection.execute("DELETE FROM player_pitching_skills WHERE id = #{pps['id']}") unless dry_run
      else
        puts "  MOVE PPS: pitching_skill_id=#{pps['pitching_skill_id']} → player_id=#{original.id}"
        ActiveRecord::Base.connection.execute(
          "UPDATE player_pitching_skills SET player_id = #{original.id} WHERE id = #{pps['id']}"
        ) unless dry_run
      end
    end

    # --- CostPlayer 移動 ---
    cps = CostPlayer.where(player_id: dup.id)
    cps.each do |cp|
      conflict_cp = CostPlayer.find_by(player_id: original.id, cost_id: cp.cost_id)
      if conflict_cp
        puts "  CONFLICT CP: CostPlayer id=#{cp.id} conflicts with id=#{conflict_cp.id} — deleting dup"
        cp.destroy! unless dry_run
      else
        puts "  MOVE CP: CostPlayer id=#{cp.id} → player_id=#{original.id}"
        cp.update_column(:player_id, original.id) unless dry_run
        merged_cps += 1
      end
    end

    # --- 重複Player削除 ---
    puts "  DELETE: Player id=#{dup.id} name=#{dup.name.inspect}"
    dup.destroy! unless dry_run
    merged_players += 1
  end
end

puts
puts "=== 結果サマリー ==="
puts "処理グループ数: #{dup_groups.size}"
puts "削除Player数: #{merged_players} (dry_run=#{dry_run})"
puts "移動PlayerCard数: #{merged_pcs}"
puts "移動TeamMembership数: #{merged_tms}"
puts "移動CostPlayer数: #{merged_cps}"
puts "PlayerCard競合（削除）数: #{conflict_pcs}"
puts
unless dry_run
  puts "=== 検証 ==="
  puts "Player.count: #{Player.count}"
  puts "PlayerCard.count: #{PlayerCard.count}"
  names = Player.pluck(:name).map { |n| n.gsub(/[\s\u3000]+/, '') }
  puts "重複名（正規化後）: #{names.length - names.uniq.length}件 ← 0が目標"
  puts "スペース含むPlayer: #{Player.all.select { |p| p.name.match?(/[\s\u3000]/) }.size}件"
end
