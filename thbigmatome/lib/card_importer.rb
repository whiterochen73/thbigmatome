require "csv"
require "json"
require "set"

# 選手カードの取り込み本体（rake import:card_data と db/seeds/import_cards.rb の共通の実装。cmd_1898）。
#
# 鍵: player_cards.card_seq（CSV の通し番号）。card_seq を持つ行は card_seq で当て、CSV に合わせて中身を更新する。
# card_seq を持たない既存行（本番の旧行）は、次の順で一度だけ照合して card_seq を書き込む。以後は card_seq で当たる。
#   1. :exact   セット・Player・種別・variant が一致（旧来の鍵）
#   2. :rename  config/card_import_aliases.yml の variant 改名（楼閣→幽冥 など。持ち主とセットを限定した表）
#   3. :content セット・Player・背番号・打撃表が一致する旧行が 1 対 1 で当たる（variant の後付け・種別の訂正）
#   4. :macro   同じセット・背番号・種別で別 Player の旧行（表記ゆれの別名。従来の重複防止。中身は更新しない）
# どれにも当たらなければ新規作成する。Player は「カードを作る（付け替える）直前」にだけ作る（カードなし Player を増やさない）。
#
# 子の行（守備・特徴・能力・専属捕手）は CSV と同じ集合にそろえる。CSV の語彙が引けない行（WARN）がある種別は、足りない行を足すだけで消さない。
# dry_run: true なら本処理を transaction で流して rollback する（出力・レポートは実適用と同じ）。
class CardImporter
  ALIASES_PATH = "config/card_import_aliases.yml".freeze
  JSON_COLUMNS = %w[injury_traits biorhythm_date_ranges batting_table pitching_table].freeze
  SCALAR_INT = %w[speed bunt steal_start steal_end injury_rate starter_stamina relief_stamina].freeze
  SCALAR_STR = %w[unique_traits biorhythm_period card_label irc_macro_name irc_display_name].freeze
  SCALAR_BOOL = %w[is_pitcher is_relief_only is_closer official_use_prohibited].freeze
  REPORT_HEADERS = %w[kind card_seq player_card_id card_set player card_type variant tier memberships changes detail].freeze

  Row = Struct.new(:seq, :source, :defn, :card_set, :name, :norm, :card_type, :variant, :base_name, :macro, :number, :attrs, :json_attrs, keyword_init: true)

  attr_reader :report

  def initialize(data_dir:, dry_run: false, report_path: nil, out: $stdout)
    @dir = data_dir.to_s
    @dry_run = dry_run
    @report_path = report_path.presence
    @out = out
    @report = []
    @renames = (YAML.load_file(Rails.root.join(ALIASES_PATH))["variant_renames"] || [])
  end

  def self.normalize(name)
    name.to_s.gsub(/[\s　\p{Cf}]+/, "")
  end

  def run
    ActiveRecord::Base.transaction(requires_new: true) do
      import!
      raise ActiveRecord::Rollback if @dry_run
    end
    write_report
    self
  end

  private

  def say(msg) = @out.puts(msg)

  def csv(name) = CSV.read(File.join(@dir, name), headers: true)

  def derive_handedness(throwing, batting)
    t = { "right" => "right_throw", "left" => "left_throw" }[throwing]
    b = { "right" => "right_bat", "left" => "left_bat", "switch" => "switch_hitter" }[batting]
    t && b ? "#{t}/#{b}" : nil
  end

  def parse_json(raw)
    JSON.parse(raw)
  rescue JSON::ParserError => e
    Rails.logger.warn "JSON parse error: #{e.message}"
    nil
  end

  # ---- 行の組み立て ----
  def build_rows(card_csv)
    shared = card_csv.group_by { |r| [ r["card_source"], r["irc_macro_name"].presence, card_type_of(r) ] }
                     .select { |k, v| k[1] && v.size > 1 }.keys
    @shared_macro_keys = shared
    rows = []
    card_csv.each do |row|
      defn = CardSet::IMPORT_DEFINITIONS[row["card_source"]]
      unless defn
        say "  WARN: unknown card_source '#{row['card_source']}' (card_seq=#{row['card_seq']}), skipping"
        next
      end
      card_set = CardSet.find_or_create_by!(name: defn[:name]) do |cs|
        cs.year = defn[:year]
        cs.set_type = defn[:set_type]
        cs.series = defn[:series]
        cs.is_current = defn[:current]
      end
      # 現行の印は対応表に合わせる（既存のカードセットにも効く。PM2028 の時に PM2027 を外すため）
      card_set.update_column(:is_current, defn[:current]) if card_set.is_current != defn[:current]

      if row["name"].blank?
        say "  WARN: card_seq=#{row['card_seq']} has blank name — skipped"
        next
      end
      missing = %w[speed bunt steal_start steal_end injury_rate].select { |f| row[f].blank? }
      if missing.any?
        say "  WARN: card_seq=#{row['card_seq']} (#{row['name']}) missing #{missing.join(',')} — skipped"
        next
      end

      attrs = {}
      SCALAR_INT.each { |c| attrs[c] = row[c].presence&.to_i }
      SCALAR_STR.each { |c| attrs[c] = row[c].presence }
      SCALAR_BOOL.each { |c| attrs[c] = row[c] == "true" }
      hand = derive_handedness(row["throwing_hand"], row["batting_hand"])
      attrs["handedness"] = hand if hand
      json_attrs = {}
      JSON_COLUMNS.each do |c|
        next if row[c].blank?
        v = parse_json(row[c])
        json_attrs[c] = v unless v.nil?
      end
      variant = row["variant"].presence
      rows << Row.new(
        seq: row["card_seq"].presence&.to_i, source: row["card_source"], defn: defn, card_set: card_set, name: row["name"], norm: self.class.normalize(row["name"]),
        card_type: card_type_of(row), variant: variant, base_name: row["base_player_name"].presence, macro: row["irc_macro_name"].presence,
        number: row["number"].presence, attrs: attrs, json_attrs: json_attrs
      )
    end
    rows
  end

  def card_type_of(r)
    if r["card_type"].present? then r["card_type"]
    elsif r["is_pitcher"] == "true" then "pitcher"
    elsif r["is_pitcher"] == "false" then "batter"
    end
  end

  # ---- Player ----
  def load_players
    @players_by_norm = {}
    @player_names = {}
    Player.order(:id).pluck(:id, :name).each { |id, name| register_player(id, name) }
  end

  def register_player(id, name)
    @player_names[id] = name
    @players_by_norm[self.class.normalize(name)] ||= id
  end

  def player_by_norm(norm)
    id = @players_by_norm[norm]
    id && Player.find(id)
  end

  # カードの持ち主（既存の Player だけ。作らない）。variant と base_player_name があれば基の Player。warn: 基が無い時の WARN を出す
  def lookup_player(row, warn: false)
    if row.variant && row.base_name
      base = player_by_norm(self.class.normalize(row.base_name))
      return [ base, :base ] if base
      say "  WARN: base_player_name='#{row.base_name}' not found for #{row.name}, using variant player" if warn
    end
    [ player_by_norm(row.norm), :name ]
  end

  def player_id_for(row)
    row.variant && row.base_name && @players_by_norm[self.class.normalize(row.base_name)] || @players_by_norm[row.norm]
  end

  # ---- 照合 ----
  def match_rows(rows)
    seqs = rows.filter_map(&:seq)
    by_seq = PlayerCard.where(card_seq: seqs).index_by(&:card_seq)
    sets = rows.map { |r| r.card_set.id }.uniq
    all = PlayerCard.where(card_set_id: sets).to_a
    csv_seqs = seqs.to_set
    legacy = all.select { |pc| pc.card_seq.nil? }
    claimed = {}   # row.object_id => [pc, tier]
    taken = Set.new

    claim = lambda do |row, pc, tier|
      claimed[row.object_id] = [ pc, tier ]
      taken << pc.id
    end

    rows.each { |row| (pc = by_seq[row.seq]) && claim.call(row, pc, :card_seq) if row.seq }

    key_of = ->(set_id, pid, type, variant) { [ set_id, pid, type, variant.to_s ] }
    index = legacy.group_by { |pc| key_of.call(pc.card_set_id, pc.player_id, pc.card_type, pc.variant) }
    rows.each do |row|
      next if claimed[row.object_id]
      pid = player_id_for(row) or next
      pc = index[key_of.call(row.card_set.id, pid, row.card_type, row.variant)]&.find { |c| !taken.include?(c.id) }
      claim.call(row, pc, :exact) if pc
    end

    rows.each do |row|
      next if claimed[row.object_id] || row.variant.nil?
      pid = player_id_for(row) or next
      @renames.each do |rn|
        next unless rn["card_set"] == row.card_set.name && rn["to"] == row.variant && self.class.normalize(rn["player"]) == (row.base_name ? self.class.normalize(row.base_name) : row.norm)
        pc = index[key_of.call(row.card_set.id, pid, row.card_type, rn["from"])]&.find { |c| !taken.include?(c.id) }
        (claim.call(row, pc, :rename); break) if pc
      end
    end

    # 内容の一致（セット・Player・背番号・打撃表）。行と旧行が 1 対 1 の時だけ当てる。複数なら当てずにレポートへ出す
    pending = rows.reject { |r| claimed[r.object_id] }
    cand = {}
    pending.each do |row|
      pid = player_id_for(row)
      next if pid.nil? || row.macro.nil? || !row.json_attrs.key?("batting_table")
      cand[row.object_id] = legacy.select do |pc|
        !taken.include?(pc.id) && pc.card_set_id == row.card_set.id && pc.player_id == pid &&
          pc.irc_macro_name.to_s == row.macro && pc.batting_table == row.json_attrs["batting_table"] &&
          (row.variant || pc.variant.nil?) # variant 空の行は variant 空のカードにだけ当てる（PM2026 の「UR」カードを別の行のものと取り違えない）
      end
    end
    rev = Hash.new { |h, k| h[k] = [] }
    cand.each { |oid, pcs| pcs.each { |pc| rev[pc.id] << oid } }
    pending.each do |row|
      pcs = cand[row.object_id] or next
      if pcs.size == 1 && rev[pcs.first.id].size == 1
        claim.call(row, pcs.first, :content)
      elsif pcs.size > 1 || (pcs.size == 1 && rev[pcs.first.id].size > 1)
        @report << rep("ambiguous", row, detail: "旧行の候補 #{pcs.map(&:id).join(',')}（当てずに新規作成）")
      end
    end

    # 同じセット・背番号・種別の別名カード（従来の重複防止）。CSV で背番号を共有する組には当てない
    rows.each do |row|
      next if claimed[row.object_id] || row.macro.nil? || @shared_macro_keys.include?([ row.source, row.macro, row.card_type ])
      pid = player_id_for(row)
      pc = all.find do |c|
        !taken.include?(c.id) && c.card_set_id == row.card_set.id && c.irc_macro_name == row.macro && c.card_type == row.card_type &&
          c.player_id != pid && (c.card_seq.nil? || !csv_seqs.include?(c.card_seq))
      end
      claim.call(row, pc, :macro) if pc
    end
    claimed
  end

  def rep(kind, row, pc: nil, tier: nil, memberships: nil, changes: nil, detail: nil)
    {
      "kind" => kind, "card_seq" => row&.seq, "player_card_id" => pc&.id, "card_set" => row&.card_set&.name,
      "player" => row&.name, "card_type" => row&.card_type, "variant" => row&.variant, "tier" => tier,
      "memberships" => memberships, "changes" => changes, "detail" => detail
    }
  end

  # ---- 本処理 ----
  def import!
    card_csv = csv("player_cards.csv")
    load_players
    rows = build_rows(card_csv)
    claimed = match_rows(rows)
    refs = reference_counts
    @created_players = 0

    say "=== Step 1: player_cards.csv ==="
    card_map = {}    # 子の行を同期する対象（macro 照合の旧行は中身を更新しないので入れない）
    matched_ids = [] # orphan 判定から外すカード（macro 照合の旧行も含む）
    rows.each do |row|
      pc, tier = claimed[row.object_id]
      result = pc ? apply_match(row, pc, tier, refs) : create_card(row)
      next unless result
      matched_ids << result.id
      card_map[row.seq.to_s] = result unless tier == :macro
    end
    unclaimed = PlayerCard.where(card_set_id: rows.map { |r| r.card_set.id }.uniq).where.not(id: matched_ids).to_a
    unclaimed.each do |pc|
      @report << { "kind" => "orphan_card", "card_seq" => pc.card_seq, "player_card_id" => pc.id, "card_set" => pc.card_set.name,
                   "player" => pc.player.name, "card_type" => pc.card_type, "variant" => pc.variant, "tier" => nil,
                   "memberships" => refs[:memberships][pc.id].to_i, "changes" => nil, "detail" => "CSV のどの行にも当たらない既存カード（触らない）" }
    end
    say "  PlayerCard.count = #{PlayerCard.count}"

    sync_children(card_map)

    say "=== Card Import Done ==="
    say "CardSet.count              = #{CardSet.count}"
    say "Player.count               = #{Player.count}"
    say "PlayerCard.count           = #{PlayerCard.count}"
    say "PlayerCardDefense.count    = #{PlayerCardDefense.count}"
    say "PlayerCardTrait.count      = #{PlayerCardTrait.count}"
    say "PlayerCardExclusiveCatcher.count = #{PlayerCardExclusiveCatcher.count}"
    summarize
  end

  def reference_counts
    {
      memberships: TeamMembership.group(:player_card_id).count,
      other: [ CompetitionRoster, GameLineupEntry, CostPlayer, TeamMembershipChange ].each_with_object(Hash.new(0)) do |m, h|
        m.where.not(player_card_id: nil).group(:player_card_id).count.each { |k, v| h[k] += v }
      end
    }
  end

  def refs_total(refs, pc) = refs[:memberships][pc.id].to_i + refs[:other][pc.id].to_i

  def resolve_or_create_player(row)
    player, via = lookup_player(row, warn: true)
    unless player
      player = Player.create!(name: row.name, number: row.number || "?")
      register_player(player.id, player.name)
      @created_players += 1
      @report << rep("player_created", row, detail: "Player ##{player.id} #{player.name}")
    end
    # series が未設定の場合のみ card_source から補完（既存値を上書きしない）。名前で引いた Player にだけ行う（従来と同じ）
    player.update_column(:series, row.defn[:series]) if via == :name && player.series.nil? && row.defn[:series].present?
    player
  end

  def card_attrs(row)
    row.attrs.merge(row.json_attrs)
  end

  def create_card(row)
    player = resolve_or_create_player(row)
    if PlayerCard.exists?(card_set_id: row.card_set.id, player_id: player.id, card_type: row.card_type, variant: row.variant)
      other = PlayerCard.find_by(card_set_id: row.card_set.id, player_id: player.id, card_type: row.card_type, variant: row.variant)
      @report << rep("conflict", row, pc: other, detail: "同じ鍵（セット・Player・種別・variant）の既存カードが card_seq=#{other.card_seq.inspect} を持つ。作らず飛ばした")
      say "  WARN: card_seq=#{row.seq} (#{row.name}) key collides with player_card=#{other.id} (card_seq=#{other.card_seq.inspect}) — skipped"
      return nil
    end
    pc = PlayerCard.create!(card_attrs(row).merge("card_set_id" => row.card_set.id, "player_id" => player.id, "card_type" => row.card_type,
                                                  "variant" => row.variant, "card_seq" => row.seq))
    @report << rep("created", row, pc: pc, memberships: 0)
    pc
  end

  def apply_match(row, pc, tier, refs)
    mem = refs[:memberships][pc.id].to_i
    if tier == :macro
      say "  WARN: irc_macro_name=#{row.macro} (#{row.card_type}) already assigned to player=#{pc.player&.name}(#{pc.player_id}), skipping new record for #{row.name}"
      pc.update!(card_seq: row.seq) if pc.card_seq.nil? && row.seq
      @report << rep("matched", row, pc: pc, tier: tier, memberships: mem, detail: "別名の旧行に結び付けた（中身は更新しない）")
      return pc
    end

    if tier == :card_seq && pc.card_set_id != row.card_set.id
      @report << rep("conflict", row, pc: pc, memberships: mem, detail: "card_seq は別のカードセットの行に付いている。更新せず飛ばした")
      say "  WARN: card_seq=#{row.seq} (#{row.name}) belongs to another card set (player_card=#{pc.id}) — skipped"
      return nil
    end

    wanted_pid = player_id_for(row)
    identity_change = pc.card_type != row.card_type || pc.irc_macro_name.to_s != row.macro.to_s || pc.player_id != wanted_pid
    if tier == :card_seq && identity_change && refs_total(refs, pc) > 0
      @report << rep("conflict", row, pc: pc, memberships: mem,
                     detail: "card_seq の行の持ち主・種別・背番号が CSV と違うが、在籍・出場などの参照がある（#{refs_total(refs, pc)} 件）。更新せず飛ばした")
      say "  WARN: card_seq=#{row.seq} (#{row.name}) identity differs from player_card=#{pc.id} and it is referenced — skipped"
      return nil
    end

    changes = {}
    desired = card_attrs(row).merge("card_type" => row.card_type, "variant" => row.variant)
    desired["card_seq"] = row.seq if row.seq
    if wanted_pid != pc.player_id || wanted_pid.nil?
      player = resolve_or_create_player(row)
      desired["player_id"] = player.id
    end
    desired.each do |col, val|
      old = pc[col]
      changes[col] = [ old, val ] unless old == val
    end
    unless changes.empty?
      begin
        pc.update!(changes.transform_values(&:last))
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
        @report << rep("conflict", row, pc: pc, memberships: mem, detail: "更新が一意制約に当たった: #{e.message}")
        say "  WARN: card_seq=#{row.seq} (#{row.name}) update failed (#{e.class}) — skipped"
        return nil
      end
    end
    unless changes.empty? || (changes.keys == [ "card_seq" ])
      identity = %w[card_type player_id].any? { |c| changes.key?(c) }
      kind = identity ? "matched_changed_identity" : "matched_changed"
      detail = changes.except("card_seq").map { |c, (o, n)| "#{c}: #{short(o)} -> #{short(n)}" }.join(" | ")
      # 種別・持ち主が変わる在籍カードは、在籍ごとに（membership id・チーム・軍・selected_cost_type）を出す。本番適用時の確認用
      if identity && mem > 0
        members = TeamMembership.where(player_card_id: pc.id).map { |m| "membership##{m.id} team##{m.team_id} #{m.squad} #{m.selected_cost_type}" }
        detail = "#{detail} || 在籍: #{members.join('; ')}"
      end
      @report << rep(kind, row, pc: pc, tier: tier, memberships: mem, changes: changes.keys.join(","), detail: detail)
    else
      @report << rep("matched", row, pc: pc, tier: tier, memberships: mem, changes: changes.keys.join(","))
    end
    pc
  end

  def short(v)
    s = v.is_a?(String) ? v : v.to_json
    s = s.gsub(/\s+/, " ")
    s.length > 80 ? "#{s[0, 77]}..." : s
  end

  # ---- 子の行 ----
  def group_by_seq(csv_rows) = csv_rows.group_by { |r| r["card_seq"] }

  def sync_children(card_map)
    sync_defenses(card_map)
    sync_traits(card_map)
    sync_catchers(card_map)
    sync_abilities(card_map)
  end

  def each_card(csv_rows, card_map)
    group_by_seq(csv_rows).each do |seq, rs|
      pc = card_map[seq]
      yield pc, rs, seq if pc
    end
  end

  def child_report(kind, pc, seq, table, desc)
    @report << { "kind" => kind, "card_seq" => seq.to_i, "player_card_id" => pc.id, "card_set" => nil, "player" => nil, "card_type" => nil,
                 "variant" => nil, "tier" => table, "memberships" => nil, "changes" => nil, "detail" => desc }
  end

  # existing: 現在の子の行、desired: [[key, attrs]]（CSV の順）、complete: CSV の全行を解決できたか
  def sync(model, pc, seq, table, existing, desired, complete, key_fn, describe)
    keep = Set.new
    desired.each do |key, attrs|
      next if keep.include?(key)
      keep << key
      rows = existing.select { |r| key_fn.call(r) == key }
      if rows.empty?
        model.create!(attrs.merge(player_card_id: pc.id))
        child_report("child_added", pc, seq, table, describe.call(attrs))
      else
        first = rows.min_by(&:id)
        diff = attrs.reject { |k, v| first[k] == v }
        first.update!(diff) unless diff.empty?
        rows.reject { |r| r.id == first.id }.each { |dup| dup.destroy!; child_report("child_removed", pc, seq, table, "重複 #{describe.call(dup.attributes.symbolize_keys)}") }
      end
    end
    return unless complete
    existing.each do |r|
      next if keep.include?(key_fn.call(r))
      r.destroy!
      child_report("child_removed", pc, seq, table, describe.call(r.attributes.symbolize_keys))
    end
  end

  def sync_defenses(card_map)
    say "=== Step 2: player_card_defenses.csv ==="
    each_card(csv("player_card_defenses.csv"), card_map) do |pc, rs, seq|
      complete = true
      desired = []
      rs.each do |row|
        condition = nil
        if row["condition_name"].present?
          condition = TraitCondition.find_by(name: row["condition_name"])
          unless condition
            say "  WARN: card_seq=#{row['card_seq']} defense condition '#{row['condition_name']}' not found — skipped"
            complete = false
            next
          end
        end
        desired << [ [ row["position"], condition&.id ],
                     { position: row["position"], condition_id: condition&.id, range_value: row["range_value"].to_i, error_rank: row["error_rank"], throwing: row["throwing"].presence } ]
      end
      sync(PlayerCardDefense, pc, seq, "defense", pc.player_card_defenses.reload.to_a, desired, complete,
           ->(r) { [ r.position, r.condition_id ] },
           ->(a) { "#{a[:position]} 範囲#{a[:range_value]} #{a[:error_rank]}#{a[:condition_id] ? " 条件##{a[:condition_id]}" : ''}" })
    end
    say "  PlayerCardDefense.count = #{PlayerCardDefense.count}"
  end

  def sync_traits(card_map)
    say "=== Step 3: player_card_traits.csv ==="
    skipped = []
    each_card(csv("player_card_traits.csv"), card_map) do |pc, rs, seq|
      complete = true
      desired = []
      rs.each do |row|
        trait_def = TraitDefinition.find_by(name: row["trait_definition_name"])
        unless trait_def
          skipped << { card_seq: row["card_seq"], name: row["trait_definition_name"] }
          complete = false
          next
        end
        condition = nil
        if row["condition_name"].present?
          condition = TraitCondition.find_by(name: row["condition_name"])
          unless condition
            say "  WARN: card_seq=#{row['card_seq']} trait '#{row['trait_definition_name']}' condition '#{row['condition_name']}' not found in trait_conditions — skipped (seed master_traits first)"
            complete = false
            next
          end
        end
        desired << [ [ trait_def.id, condition&.id, row["role"].presence ],
                     { trait_definition_id: trait_def.id, condition_id: condition&.id, role: row["role"].presence, sort_order: row["sort_order"].to_i } ]
      end
      sync(PlayerCardTrait, pc, seq, "trait", pc.player_card_traits.reload.to_a, desired, complete,
           ->(r) { [ r.trait_definition_id, r.condition_id, r.role ] },
           ->(a) { "特徴##{a[:trait_definition_id]}#{a[:condition_id] ? " 条件##{a[:condition_id]}" : ''}#{a[:role] ? " #{a[:role]}" : ''}" })
    end
    say "  PlayerCardTrait.count = #{PlayerCardTrait.count}"
    say "  Unresolved traits (#{skipped.size}): #{skipped.map { |s| s[:name] }.uniq.first(10).join(', ')}" if skipped.any?
  end

  def sync_catchers(card_map)
    say "=== Step 4: player_card_exclusive_catchers.csv ==="
    each_card(csv("player_card_exclusive_catchers.csv"), card_map) do |pc, rs, seq|
      complete = true
      ids = []
      rs.each do |row|
        name = row["catcher_name_raw"].presence or next
        pid = @players_by_norm[self.class.normalize(name)]
        unless pid
          say "  WARN: catcher '#{name}' not found in players — skipped (import their card first)"
          complete = false
          next
        end
        ids << pid
      end
      existing = PlayerCardExclusiveCatcher.where(player_card_id: pc.id).pluck(:catcher_player_id)
      (ids.uniq - existing).each do |cid|
        PlayerCardExclusiveCatcher.create!(player_card_id: pc.id, catcher_player_id: cid)
        child_report("child_added", pc, seq, "catcher", "専属捕手 ##{cid}")
      end
      next unless complete
      (existing - ids).each do |cid|
        PlayerCardExclusiveCatcher.where(player_card_id: pc.id, catcher_player_id: cid).delete_all
        child_report("child_removed", pc, seq, "catcher", "専属捕手 ##{cid}")
      end
    end
    say "  PlayerCardExclusiveCatcher.count = #{PlayerCardExclusiveCatcher.count}"
  end

  def sync_abilities(card_map)
    say "=== Step 5: player_card_abilities.csv ==="
    each_card(csv("player_card_abilities.csv"), card_map) do |pc, rs, seq|
      complete = true
      desired = []
      rs.each do |row|
        ability = AbilityDefinition.find_by(name: row["ability_definition_name"])
        unless ability
          say "  WARN: card_seq=#{row['card_seq']} ability '#{row['ability_definition_name']}' not found in ability_definitions — skipped (seed master_traits first)"
          complete = false
          next
        end
        condition = nil
        if row["condition_name"].present?
          condition = TraitCondition.find_by(name: row["condition_name"])
          unless condition
            say "  WARN: card_seq=#{row['card_seq']} ability '#{row['ability_definition_name']}' condition '#{row['condition_name']}' not found in trait_conditions — skipped (seed master_traits first)"
            complete = false
            next
          end
        end
        desired << [ [ ability.id, condition&.id, row["role"].presence ],
                     { ability_definition_id: ability.id, condition_id: condition&.id, role: row["role"].presence, sort_order: row["sort_order"].to_i } ]
      end
      sync(PlayerCardAbility, pc, seq, "ability", pc.player_card_abilities.reload.to_a, desired, complete,
           ->(r) { [ r.ability_definition_id, r.condition_id, r.role ] },
           ->(a) { "能力##{a[:ability_definition_id]}#{a[:condition_id] ? " 条件##{a[:condition_id]}" : ''}#{a[:role] ? " #{a[:role]}" : ''}" })
    end
    say "  PlayerCardAbility.count = #{PlayerCardAbility.count}"
  end

  # ---- レポート ----
  def summarize
    c = @report.group_by { |r| r["kind"] }.transform_values(&:size)
    c.default = 0
    say "=== Reconcile Summary#{@dry_run ? ' (DRY RUN: rolled back)' : ''} ==="
    %w[created matched matched_changed matched_changed_identity conflict ambiguous orphan_card player_created child_added child_removed].each { |k| say "  #{k} = #{c[k]}" }
    tiers = @report.select { |r| r["kind"].to_s.start_with?("matched") }.group_by { |r| r["tier"] }.transform_values(&:size)
    say "  match tiers: #{tiers.map { |t, n| "#{t}=#{n}" }.join(' ')}"
    say "  referenced cards changed identity: #{@report.count { |r| r['kind'] == 'matched_changed_identity' && r['memberships'].to_i > 0 }}"
  end

  def write_report
    return unless @report_path
    CSV.open(@report_path, "w") do |f|
      f << REPORT_HEADERS
      @report.each { |r| f << REPORT_HEADERS.map { |h| r[h] } }
    end
    say "  report: #{@report_path} (#{@report.size} rows)"
  end
end
