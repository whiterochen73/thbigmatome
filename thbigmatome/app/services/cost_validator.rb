class CostValidator
  TOTAL_LIMIT = 200

  # 1軍人数別コスト上限（人数 => 上限）
  FIRST_SQUAD_LIMITS = {
    28 => 120,
    27 => 119,
    26 => 117,
    25 => 114
  }.freeze

  def initialize(competition_entry_id)
    @competition_entry = CompetitionEntry.find(competition_entry_id)
    @rosters = @competition_entry.competition_rosters.includes(player_card: { player: :cost_players })
    @current_cost = Cost.current_cost
  end

  def validate
    first_squad = @rosters.select(&:first_squad?)
    second_squad = @rosters.select(&:second_squad?)

    first_squad_count = first_squad.count
    first_squad_cost = first_squad.sum { |r| player_cost(r.player_card) }
    current_total_cost = first_squad_cost + second_squad.sum { |r| player_cost(r.player_card) }

    errors = []

    # 1軍人数チェック（24人以下は禁止）
    if first_squad_count < 25
      errors << "1軍人数が不足しています（最低25人必要、現在#{first_squad_count}人）"
    end

    # 1軍コスト上限（段階制）
    first_squad_limit = first_squad_limit_for(first_squad_count)
    if first_squad_limit
      if first_squad_cost > first_squad_limit
        errors << "1軍コストが上限（#{first_squad_limit}）を超えています（現在#{first_squad_cost}）"
      end
    end

    # チーム全体コスト上限
    if current_total_cost > TOTAL_LIMIT
      errors << "チーム全体コストが上限（#{TOTAL_LIMIT}）を超えています（現在#{current_total_cost}）"
    end

    {
      valid: errors.empty?,
      errors: errors,
      current_total_cost: current_total_cost,
      total_limit: TOTAL_LIMIT,
      first_squad_cost: first_squad_cost,
      first_squad_limit: first_squad_limit,
      first_squad_count: first_squad_count
    }
  end

  private

  def first_squad_limit_for(count)
    FIRST_SQUAD_LIMITS[[ count, 28 ].min]
  end

  def player_cost(player_card)
    cost_player = @current_cost ? player_card.player.cost_players.find { |cp| cp.cost_id == @current_cost.id } : nil
    return 0 unless cost_player

    if player_card.is_relief_only
      cost_player.relief_only_cost || cost_player.normal_cost || 0
    elsif player_card.is_pitcher
      cost_player.pitcher_only_cost || cost_player.normal_cost || 0
    else
      cost_player.fielder_only_cost || cost_player.normal_cost || 0
    end
  end
end
