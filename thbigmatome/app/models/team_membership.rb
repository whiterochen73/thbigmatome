class TeamMembership < ApplicationRecord
  belongs_to :team
  belongs_to :player
  belongs_to :player_card, optional: true
  has_many :season_rosters
  # チーム編成の変更記録（cmd_1784 段2）。契約・カード・在籍は、ある時点の値をここから導く（RosterState）
  has_many :team_membership_changes, dependent: :destroy
  has_many :player_absences, dependent: :restrict_with_error

  attr_accessor :skip_commissioner_validation
  # 同キャラの検査を呼び出し側（TeamMembershipWriter）が保存後の姿で済ませている時に立てる。同じ保存で放出する同キャラは DB の在籍に残っているため、
  # 行ごとの検査だと入れ替えを誤って拒む。カードの検査（player_card_registrable）は常に効く
  attr_accessor :skip_character_validation

  validates :squad, inclusion: { in: %w[first second] }
  validates :selected_cost_type, presence: true, inclusion: { in: %w[normal_cost relief_only_cost pitcher_only_cost fielder_only_cost two_way_cost] }

  validate :player_not_in_director_sibling_team, on: :create, unless: :skip_commissioner_validation
  # 登録の制限（cmd_1893/subtask_1893e）。コミッショナーにも適用する（skip_commissioner_validation の対象外。裁定に例外が無い）
  validate :player_card_registrable, if: -> { new_record? || will_save_change_to_player_card_id? }
  validate :character_not_duplicated_in_team, on: :create, unless: :skip_character_validation

  # 登録で選べないカードの理由（選べるなら nil）。カードの無い登録（nil）は受ける。
  # 既存の所属が持つ現行外のカードは、カードを替えない限り検査しない（呼び出し側が「新規・カード変更」の時だけ呼ぶ）
  def self.card_registration_error(card)
    return nil if card.nil?
    return I18n.t("activerecord.errors.models.team_membership.player_card_official_use_prohibited") if card.official_use_prohibited
    return I18n.t("activerecord.errors.models.team_membership.player_card_not_current", card_set_name: card.card_set&.name) unless card.card_set&.is_current

    nil
  end

  # 同じキャラクター（Player#character_key）の選手を、同じチームの在籍中の所属から探す（player_id が違うものだけ）
  def self.same_character_member(team_id, player)
    return nil if player&.character_key.blank?

    active.where(team_id: team_id).where.not(player_id: player.id)
          .joins(:player).find_by(players: { character_key: player.character_key })
  end

  # 在籍中（放出されていない）。on_team は変更記録の最新の状態の写し（RosterState#rebuild_cache!）
  scope :active, -> { where(on_team: true) }
  scope :included_in_team_total, -> { where(excluded_from_team_total: false) }
  scope :excluded_from_team_total, -> { where(excluded_from_team_total: true) }

  def selected_cost_value(cost_list)
    cost_list_id = extract_cost_list_id(cost_list)
    return 0 unless cost_list_id

    preferred_cost_types.each do |cost_type|
      value = cost_value_for(cost_type, cost_list_id)
      return value if value.present?
    end

    0
  end

  # 外の世界枠のバランス（4 人のとき投手・野手が 1 人以上）で、投手に数えるか。AMB-29（2026-11-02 改訂・暫定）:
  #   1. 専任契約が最優先: 投手専任・救援専任＝投手のみ、野手専任＝野手のみ
  #   2. 二刀流契約（two_way_cost）のときだけ、投手にも野手にも数える（選んだコスト区分で決める。選手が二刀流契約できる範囲は Player#available_cost_types）
  #   3. それ以外の契約は選んだカードの主な位置（PlayerCard#primary_position）で、投手（P）＝投手、それ以外＝野手
  #      （card_type・can_pitch?・P 守備の有無・hachinai_two_way? では決めない。カードが無い選手は決められないので、どちらにも数えない）
  def pitcher_role?
    balance_roles.first
  end

  # 野手に数えるか（pitcher_role? と同じ規則）
  def fielder_role?
    balance_roles.last
  end

  # 外の世界枠の内訳（画面の「投・野・二刀流」）の区分。pitcher_role? / fielder_role? の組み合わせだけで決める（別の判定を作らない）。
  # 投手だけに数える = :pitcher_only、野手だけに数える = :fielder_only、両方に数える = :two_way、どちらにも数えない = nil
  def pitcher_fielder_kind
    pitcher = pitcher_role?
    fielder = fielder_role?
    return :two_way if pitcher && fielder
    return :pitcher_only if pitcher
    return :fielder_only if fielder

    nil
  end

  def starter_pitcher_role?
    return false unless pitching_role?

    player_card&.starter_stamina.present? && player_card.starter_stamina >= 4
  end

  # 救援専任契約（selected_cost_type = relief_only_cost）。カードの is_relief_only とは別に、チームでの契約がリリーフ専門であること。
  # 先発もできる契約（normal_cost / pitcher_only_cost / two_way_cost）に変わると false に戻る。
  def relief_only_contract?
    selected_cost_type == "relief_only_cost"
  end

  def relief_only_role?
    return false unless pitching_role?

    player_card&.is_relief_only || false
  end

  def roster_position
    return "pitcher" if pitching_role?

    player_card&.primary_position&.downcase
  end

  # 選んだカードを投手として使うか（画面の表示・先発/救援の判定用の従来の判定）。外の世界枠のバランスの数え方（pitcher_role?）とは別
  def pitching_role?
    return false if selected_cost_type == "fielder_only_cost"
    return true if player_card&.can_pitch?

    player&.hachinai_two_way? && %w[normal_cost pitcher_only_cost two_way_cost].include?(selected_cost_type)
  end

  private

  def player_card_registrable
    return if player_card_id.blank?

    message = self.class.card_registration_error(player_card)
    errors.add(:base, message) if message
  end

  def character_not_duplicated_in_team
    return unless team_id && player

    other = self.class.same_character_member(team_id, player)
    return unless other

    errors.add(:base, I18n.t("activerecord.errors.models.team_membership.same_character_in_team",
                                  player_name: player.name, other_name: other.player.name))
  end

  # [投手に数える, 野手に数える]（pitcher_role? の規則）
  def balance_roles
    case selected_cost_type
    when "pitcher_only_cost", "relief_only_cost" then [ true, false ]
    when "fielder_only_cost" then [ false, true ]
    when "two_way_cost" then [ true, true ]
    else
      return [ false, false ] if player_card.nil?

      player_card.primary_position_pitcher? ? [ true, false ] : [ false, true ]
    end
  end

  def preferred_cost_types
    return [ selected_cost_type ] unless player&.hachinai_two_way?

    case selected_cost_type
    when "fielder_only_cost"
      %w[fielder_only_cost two_way_cost pitcher_only_cost normal_cost]
    when "pitcher_only_cost"
      %w[pitcher_only_cost two_way_cost fielder_only_cost normal_cost]
    when "two_way_cost"
      %w[two_way_cost pitcher_only_cost fielder_only_cost normal_cost]
    when "normal_cost"
      if player_card&.can_pitch?
        %w[pitcher_only_cost two_way_cost fielder_only_cost normal_cost]
      else
        %w[fielder_only_cost two_way_cost pitcher_only_cost normal_cost]
      end
    else
      [ selected_cost_type ]
    end
  end

  def extract_cost_list_id(cost_list)
    return cost_list.id if cost_list.respond_to?(:id)
    return cost_list if cost_list.is_a?(Integer)

    nil
  end

  def cost_value_for(cost_type, cost_list_id)
    player.cost_value_for_types([ cost_type ], cost_list_id, exact_player_card_id: player_card_id).presence
  end

  def player_not_in_director_sibling_team
    return unless team

    director_tm = team.director_team_manager
    return unless director_tm

    director_id = director_tm.manager_id

    sibling_team_ids = TeamManager.joins(:team)
                                  .where(manager_id: director_id, role: :director)
                                  .where(teams: { is_active: true })
                                  .where.not(team_id: team.id)
                                  .pluck(:team_id)
    return if sibling_team_ids.empty?

    if TeamMembership.active.where(team_id: sibling_team_ids, player_id: player_id).exists?
      sibling_team = Team.joins(:team_managers)
                         .where(team_managers: { manager_id: director_id, role: :director })
                         .where.not(id: team.id)
                         .first
      errors.add(:base,
        I18n.t("activerecord.errors.models.team_membership.player_in_sibling_team",
               player_name: player&.name,
               team_name: sibling_team&.name))
    end
  end
end
