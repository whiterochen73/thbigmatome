class PlayerCard < ApplicationRecord
  has_one_attached :card_image

  belongs_to :card_set
  belongs_to :player
  belongs_to :batting_style, optional: true
  belongs_to :pitching_style, optional: true
  belongs_to :pinch_pitching_style, class_name: "PitchingStyle", foreign_key: :pinch_pitching_style_id, optional: true
  belongs_to :catcher_pitching_style, class_name: "PitchingStyle", foreign_key: :catcher_pitching_style_id, optional: true

  has_many :player_card_player_types, dependent: :destroy
  has_many :player_types, through: :player_card_player_types
  has_many :competition_rosters, dependent: :destroy
  has_many :game_lineup_entries, dependent: :destroy
  has_many :player_card_defenses, dependent: :destroy
  has_many :player_card_traits, dependent: :destroy
  has_many :player_card_abilities, dependent: :destroy
  has_many :player_card_exclusive_catchers, dependent: :destroy

  accepts_nested_attributes_for :player_card_defenses, allow_destroy: true
  accepts_nested_attributes_for :player_card_traits, allow_destroy: true
  accepts_nested_attributes_for :player_card_abilities, allow_destroy: true
  has_many :exclusive_catchers, through: :player_card_exclusive_catchers, source: :catcher_player

  # 登録画面で選べるカード: 現行カードセットで、公式戦で使えるもの（Operator 裁定 2026-11-14）。既存の所属が持つ現行外のカードはこの絞りの対象外（消さない）
  scope :registrable, -> { joins(:card_set).merge(CardSet.current).where(official_use_prohibited: false) }

  validates :card_set_id, :player_id, presence: true
  validates :card_type, presence: true, inclusion: { in: %w[pitcher batter] }
  # DB の一意 index（card_set_id, player_id, card_type, COALESCE(variant, '')）と同じ鍵。variant 違いの同名カードを作れるようにする
  validates :card_set_id, uniqueness: { scope: [ :player_id, :card_type, :variant ] }
  # CSV の通し番号（取り込みの鍵。既存の旧行は取り込みの最初の 1 回が埋める）
  validates :card_seq, uniqueness: true, allow_nil: true

  # 投手として使用可能か（能力判定）
  # 判定条件: card_type='pitcher' OR is_pitcher=true OR player_card_defensesに投手(P)ポジションがある
  # player_card_defensesが正典（P守備があれば確実に投手能力あり）。is_pitcherはフォールバック。
  # ※ selected_cost_type='fielder_only_cost'（野手専念）の場合は呼び出し側で除外すること
  def can_pitch?
    card_type == "pitcher" ||
      is_pitcher ||
      player_card_defenses.any? { |d| d.position&.upcase == "P" }
  end

  # 1 枚で二刀流のカード: 野手カードに投球表がある（P 守備を持つ）。取込 CSV では「天弓 千亦 (草津)」（PM2026 の 375・PM2027 の 519）と「とり」
  # （324・477）の 4 枚だけ（2026-11-14 実測）。PM のカードの二刀流はこれだけで決まる（Player#pitcher_fielder_pair?）
  def two_way_card?
    card_type == "batter" && !is_pitcher && player_card_defenses.any? { |d| d.position&.upcase == "P" }
  end

  # カードの主な位置（画面の primary_position と同じ定義）。守備位置の 1 つ目（id 順）。外の世界枠の投手・野手の数え方（AMB-29 改訂）で使う。
  # 取込 CSV の position（投手/内野手/外野手/捕手）と、投手（P）かどうかが一致することを開発 DB の全カードで確認済み（cmd_1808）。守備が 1 つも無いカードは nil
  def primary_position
    player_card_defenses.to_a.min_by { |d| d.id || Float::INFINITY }&.position
  end

  # 主な位置が投手（P）か。can_pitch? とは別（card_type が pitcher でも主な位置が内野手のカードがある）
  def primary_position_pitcher?
    primary_position&.upcase == "P"
  end

  # スラッシュ選手: 先発もリリーフもできるカード（先発疲労P とリリーフ疲労P の両方があり、リリーフ専門でない）。
  # 先発→リリーフ・リリーフ→先発の休養表（rulebook 08 §8.3.3 / §8.3.4）がスラッシュ用に変わる。
  def slash_pitcher?
    starter_stamina.present? && relief_stamina.present? && !is_relief_only
  end

  # 【中4日可】: 中4日で先発できる固有特徴。連続中4日のペナルティ（rulebook 08 §8.5.1 条件 2）を受けない（Operator 2026-11-14）。
  # 免除するのは条件 2 だけ。中4日の疲労P（§8.3.1）と中3日の負傷チェック（条件 1）は変わらない。
  SHORT_REST_CAPABLE_TRAIT = "【中4日可】".freeze

  def short_rest_capable?
    unique_traits.to_s.include?(SHORT_REST_CAPABLE_TRAIT)
  end

  # 時限選手（カードの特徴欄に日付の範囲が書かれたカード。cmd_1896）。「M/D~」= その日からシーズン終わりまで、
  # 「~M/D」= シーズン初めからその日まで（両端を含む）。全角の「〜」「～」も受ける。バイオリズム（biorhythm_*）は別物で読まない。
  # 返す値: 範囲が無ければ nil、あれば { from: [月, 日] または nil, to: [月, 日] または nil }
  TIME_LIMITED_PATTERN = %r{(?:(\d{1,2})[ \t]*/[ \t]*(\d{1,2}))?[ \t]*[~〜～][ \t]*(?:(\d{1,2})[ \t]*/[ \t]*(\d{1,2}))?}

  def availability_period
    unique_traits.to_s.scan(TIME_LIMITED_PATTERN).each do |fm, fd, tm, td|
      next if fm.nil? && tm.nil?

      from = fm && Date.valid_date?(2000, fm.to_i, fd.to_i) ? [ fm.to_i, fd.to_i ] : nil
      to = tm && Date.valid_date?(2000, tm.to_i, td.to_i) ? [ tm.to_i, td.to_i ] : nil
      return { from: from, to: to } if from || to
    end
    nil
  end

  def time_limited?
    availability_period.present?
  end

  # date の日に起用（1軍登録）できるか。時限でなければ常に true。
  # 年はシーズンの年で解決する: anchor（シーズン初日。無ければ date）以後で最初に来るその月日。年をまたぐシーズンでは翌年の月日になる。
  def available_on?(date, anchor: nil)
    period = availability_period
    return true if period.nil?

    anchor ||= date
    from = period[:from] && resolve_period_date(period[:from], anchor)
    to = period[:to] && resolve_period_date(period[:to], anchor)
    return false if from && date < from
    return false if to && date > to

    true
  end

  # 期間の文言用（例「4/22 から」「9/24 まで」「4/22〜9/24」）
  def availability_period_label
    period = availability_period or return nil
    f = period[:from] && "#{period[:from][0]}/#{period[:from][1]}"
    t = period[:to] && "#{period[:to][0]}/#{period[:to][1]}"
    if f && t then "#{f}〜#{t}"
    elsif f then "#{f} から"
    else "#{t} まで"
    end
  end

  # リリーフで投げられるカードか。画面の「リリーフなら」を出す条件と同じ（リリーフ向けの疲労P を持つ、またはリリーフ専門）
  def relief_capable?
    is_relief_only || relief_stamina.present?
  end

  # 「オープナー可」アビリティ（ability_definitions.name。rulebook 08 §8.4.1）。pitcher_game_states.is_opener は登板時のフラグで別物。
  # カードの記載は Dugout に未取込のことがある（2026-10-27 時点で ability_definitions は 0 件）。定義が 1 件も無い間は、
  # リリーフで投げられるカード全員を true にする（Operator 2026-10-27）。定義が 1 件でもあれば、カードの記載どおり。
  # definitions_present: 定義の有無。一覧で投手ごとに引かないよう、呼び出し側が 1 回だけ AbilityDefinition.exists? を渡す。
  # includes(player_card_abilities: :ability_definition) 済みなら追加クエリなし。
  OPENER_ABILITY_NAME = "オープナー可".freeze

  def opener_capable?(definitions_present = AbilityDefinition.exists?)
    return relief_capable? unless definitions_present

    player_card_abilities.any? { |a| a.ability_definition&.name == OPENER_ABILITY_NAME }
  end

  # DB検索用スコープ: 投手能力を持つカード（can_pitch?のDB版）
  # player_card_defensesにP守備がある OR is_pitcher=true OR card_type='pitcher'
  scope :can_pitch, -> {
    where(card_type: "pitcher")
      .or(where(is_pitcher: true))
      .or(
        where(
          "EXISTS (SELECT 1 FROM player_card_defenses pcd WHERE pcd.player_card_id = player_cards.id AND pcd.position = ?)",
          "P"
        )
      )
  }

  validates :speed, presence: true,
            numericality: { only_integer: true },
            inclusion: { in: 1..5 }
  validates :bunt, presence: true,
            numericality: { only_integer: true },
            inclusion: { in: 1..10 }
  validates :steal_start, presence: true,
            numericality: { only_integer: true },
            inclusion: { in: 1..22 }
  validates :steal_end, presence: true,
            numericality: { only_integer: true },
            inclusion: { in: 1..22 }
  validates :injury_rate, presence: true,
            numericality: { only_integer: true },
            inclusion: { in: 0..7 }
  validates :starter_stamina,
            numericality: { only_integer: true },
            inclusion: { in: 4..9 },
            allow_blank: true,
            unless: :is_relief_only
  validates :relief_stamina,
            numericality: { only_integer: true },
            inclusion: { in: 0..3 },
            allow_blank: true
  validates :special_defense_c,
            format: { with: /\A[0-5][A-ES]\z/ },
            allow_blank: true
  validates :special_throwing_c,
            presence: true,
            if: -> { special_defense_c.present? }
  validates :special_throwing_c,
            numericality: { only_integer: true },
            inclusion: { in: -5..5 },
            allow_blank: true

  def cost_value(cost_list)
    player.cost_value_for_card(self, cost_list)
  end

  def registrable?
    !official_use_prohibited && card_set&.is_current == true
  end

  # 期間の月日（[月, 日]）を anchor 以後で最初のその日付にする
  def resolve_period_date(month_day, anchor)
    # 2/29 の年が非閏年なら 3/1 に倒す
    year = anchor.year
    date = Date.valid_date?(year, *month_day) ? Date.new(year, *month_day) : Date.new(year, 3, 1)
    date < anchor ? date.next_year : date
  end
end
