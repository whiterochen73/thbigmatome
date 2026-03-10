CardSet.where('name LIKE ?', '%ハチナイ%').each { |cs| cs.update!(is_outside_world: true) }
CardSet.where('name LIKE ?', '%PM2026%').each { |cs| cs.update!(is_outside_world: true) }
CardSet.where('name LIKE ?', '%球詠%').each { |cs| cs.update!(is_outside_world: true) }
CardSet.all.each { |cs| puts "#{cs.id} #{cs.name}: is_outside_world=#{cs.is_outside_world}" }
