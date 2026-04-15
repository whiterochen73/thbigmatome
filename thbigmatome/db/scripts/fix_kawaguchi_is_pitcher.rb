# fix_kawaguchi_is_pitcher.rb
# 川口息吹のplayer_cardにis_pitcher=trueを設定する修正スクリプト
# 実行: RAILS_ENV=production rails runner db/scripts/fix_kawaguchi_is_pitcher.rb
#       RAILS_ENV=development rails runner db/scripts/fix_kawaguchi_is_pitcher.rb

player = Player.find_by(name: '川口　息吹')
unless player
  puts "ERROR: 川口息吹 not found"
  exit 1
end

puts "Player found: id=#{player.id} name=#{player.name}"

updated = 0
player.player_cards.each do |pc|
  puts "  Card: id=#{pc.id} card_type=#{pc.card_type} is_pitcher=#{pc.is_pitcher}"
  unless pc.is_pitcher
    pc.update!(is_pitcher: true)
    puts "  -> Updated: is_pitcher=true"
    updated += 1
  else
    puts "  -> Already correct"
  end
end

puts "Done. #{updated} record(s) updated."
