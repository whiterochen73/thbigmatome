require "csv"

# player_cards.csv の 1 行を、取り込み済みの PlayerCard 1 枚に当てる（画像の取り込み・コストの card_seq 行が共有する）。
#
# 当て方は取り込み（db/seeds/import_cards.rb の Step 1）と同じ:
#   1. PlayerCard に card_seq 列があり、その行の card_seq を持つカードがあればそれ（取り込み側が列を持たせた後は、これが最も確か）
#   2. 無ければ、出典のカードセット・持ち主・種別・variant で引く。持ち主は variant と base_player_name が両方ある行なら base_player_name の選手
#      （取り込みが「添え字つきの Player を作ってから基の Player へ付け替える」のと同じ。基の選手が無ければ行の名前の選手）。
#      variant の無い行は、variant の無いカードにだけ当てる。variant つきのカード（PM2026 の 小鳥遊 柚 の UR など）に寄せない。
#      現行の取り込みは variant の無い行では variant を鍵にしないため、variant つきの既存カードを「その行のカード」として使い、行のカードを作らない
#      （card_seq 405）。そのカードに画像やコストを当てると別のカード（UR）に付く取り違えになるので、当てずに漏れとして数える。
#      取り込み側が直れば（card_seq 列、または variant の無い行を variant で絞る）、このまま当たるようになる
module PlayerCardLocator
  Result = Struct.new(:card, :owner, :reason, keyword_init: true) do
    def found? = !card.nil?
  end

  module_function

  # row: CSV::Row か Hash（card_seq・name・card_source・card_type・is_pitcher・variant・base_player_name を読む）
  def locate(row)
    seq = row["card_seq"].to_s
    if seq_column? && seq.present?
      by_seq = PlayerCard.find_by(card_seq: seq.to_i)
      return Result.new(card: by_seq, owner: by_seq.player) if by_seq
    end

    variant = row["variant"].presence
    owner = owner_for(row, variant)
    return Result.new(reason: "player_missing") unless owner

    set = CardSet.find_by(name: card_set_name_for(row["card_source"]))
    return Result.new(owner: owner, reason: "card_set_missing") unless set

    scope = PlayerCard.where(card_set: set, player: owner, card_type: card_type_of(row))
    card = scope.find_by(variant: variant || [ nil, "" ])
    card ? Result.new(card: card, owner: owner) : Result.new(owner: owner, reason: "card_missing")
  end

  # 当て先の点検（画像ファイルは使わない）。rows を全部当てて、漏れ・取り違えの疑い・同じカードへの重複を数える。
  #   missing    : 当たらなかった行（reason つき）
  #   mismatched : 当たったが、鍵に使っていない項目（背番号・足・バント・盗塁・怪我率・種別・セット）が行と食い違うカード。
  #                取り込みは既存の行を書き換えないので、CSV を直した後の既存カードでは正当に食い違うことがある（人が見る一覧）
  #   collisions : 2 行以上が同じカードに当たったもの（取り込みの irc_macro_name による重複防止で、別の行が既存カードに寄せられた場合を含む）
  AUDIT_FIELDS = %w[irc_macro_name speed bunt steal_start steal_end injury_rate].freeze

  def audit(rows)
    missing = []
    mismatched = []
    hits = Hash.new { |h, k| h[k] = [] }
    total = 0
    rows.each do |row|
      total += 1
      result = locate(row)
      unless result.found?
        missing << { card_seq: row["card_seq"], name: row["name"], card_source: row["card_source"], reason: result.reason }
        next
      end

      card = result.card
      hits[card.id] << row["card_seq"]
      diffs = []
      diffs << "card_type" if card.card_type != card_type_of(row)
      diffs << "card_set" if card.card_set&.name != card_set_name_for(row["card_source"])
      AUDIT_FIELDS.each do |field|
        expected = row[field].presence
        actual = card[field]
        diffs << field unless expected.to_s == actual.to_s
      end
      mismatched << { card_seq: row["card_seq"], name: row["name"], card_source: row["card_source"], card_id: card.id, fields: diffs } if diffs.any?
    end
    collisions = hits.select { |_id, seqs| seqs.size > 1 }.map { |card_id, seqs| { card_id: card_id, card_seqs: seqs } }
    { total: total, found: total - missing.size, missing: missing, mismatched: mismatched, collisions: collisions }
  end

  # player_cards.csv の card_source → card_sets.name（config/card_set_definitions.yml = CardSet::IMPORT_DEFINITIONS が正本）
  def card_set_name_for(card_source)
    CardSet::IMPORT_DEFINITIONS.dig(card_source, :name) || card_source
  end

  def card_type_of(row)
    row["card_type"].presence || (row["is_pitcher"] == "true" ? "pitcher" : "batter")
  end

  def normalize_name(value)
    value.to_s.unicode_normalize(:nfkc).gsub(/[[:space:]　]+/, "")
  end

  def find_player_by_name(name)
    index[normalize_name(name)]
  end

  def clear_cache!
    @index = nil
    @seq_column = nil
  end

  def seq_column?
    return @seq_column unless @seq_column.nil?

    @seq_column = PlayerCard.column_names.include?("card_seq")
  end

  def owner_for(row, variant)
    if variant && row["base_player_name"].present?
      base = find_player_by_name(row["base_player_name"])
      return base if base
    end
    find_player_by_name(row["name"])
  end

  # 名前の寄せ方は resolver と同じ（NFKC・空白除去）。同じ寄せ後の名前が複数あれば先の id（find_by と同じ）
  def index
    @index ||= Player.order(:id).each_with_object({}) { |player, h| h[normalize_name(player.name)] ||= player }
  end
end
