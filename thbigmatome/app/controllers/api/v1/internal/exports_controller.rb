class Api::V1::Internal::ExportsController < Api::V1::InternalBaseController
  DEFAULT_PER_PAGE = 100
  MAX_PER_PAGE = 1_000

  def players
    render_collection(Player.all.order(:id), :players) { |p|
      { id: p.id, name: p.name, short_name: p.short_name,
        number: p.number, series: p.series,
        created_at: p.created_at, updated_at: p.updated_at }
    }
  end

  def teams
    render_collection(Team.all.order(:id), :teams) { |t|
      { id: t.id, name: t.name, short_name: t.short_name,
        team_type: t.team_type, is_active: t.is_active,
        created_at: t.created_at, updated_at: t.updated_at }
    }
  end

  def stadiums
    render_collection(Stadium.all.order(:id), :stadiums) { |s|
      { id: s.id, name: s.name, code: s.code, indoor: s.indoor,
        up_table_ids: s.up_table_ids,
        created_at: s.created_at, updated_at: s.updated_at }
    }
  end

  def card_sets
    render_collection(CardSet.all.order(:id), :card_sets) { |cs|
      { id: cs.id, name: cs.name, year: cs.year, set_type: cs.set_type,
        series: cs.series, is_outside_world: cs.is_outside_world,
        created_at: cs.created_at, updated_at: cs.updated_at }
    }
  end

  def player_cards
    render_collection(PlayerCard.all.order(:id), :player_cards) { |pc|
      { id: pc.id, player_id: pc.player_id, card_set_id: pc.card_set_id,
        card_type: pc.card_type, is_pitcher: pc.is_pitcher,
        is_relief_only: pc.is_relief_only, is_closer: pc.is_closer,
        handedness: pc.handedness, speed: pc.speed, bunt: pc.bunt,
        steal_start: pc.steal_start, steal_end: pc.steal_end,
        injury_rate: pc.injury_rate, starter_stamina: pc.starter_stamina,
        relief_stamina: pc.relief_stamina,
        batting_table: pc.batting_table, pitching_table: pc.pitching_table,
        unique_traits: pc.unique_traits,
        irc_macro_name: pc.irc_macro_name, irc_display_name: pc.irc_display_name,
        card_label: pc.card_label, variant: pc.variant,
        created_at: pc.created_at, updated_at: pc.updated_at }
    }
  end

  def seasons
    render_collection(Season.all.order(:id), :seasons) { |s|
      { id: s.id, name: s.name, team_id: s.team_id,
        current_date: s.current_date, team_type: s.team_type,
        key_player_id: s.key_player_id,
        created_at: s.created_at, updated_at: s.updated_at }
    }
  end

  def games
    games = Game.all.order(:id)
    games = games.where(real_date: params[:from]..) if params[:from].present?
    games = games.where(real_date: ..params[:to]) if params[:to].present?

    render_collection(games, :games) { |g|
      { id: g.id, home_team_id: g.home_team_id,
        visitor_team_id: g.visitor_team_id, stadium_id: g.stadium_id,
        real_date: g.real_date, home_score: g.home_score,
        visitor_score: g.visitor_score, status: g.status,
        source: g.source, dh: g.dh,
        created_at: g.created_at, updated_at: g.updated_at }
    }
  end

  def game_show
    game = Game.find(params[:id])
    render json: {
      id: game.id, home_team_id: game.home_team_id,
      visitor_team_id: game.visitor_team_id, stadium_id: game.stadium_id,
      real_date: game.real_date, home_score: game.home_score,
      visitor_score: game.visitor_score, status: game.status,
      source: game.source, dh: game.dh,
      created_at: game.created_at, updated_at: game.updated_at
    }
  end

  private

  def render_collection(scope, resource_key)
    unless paginated_request?
      render json: scope.map { |record| yield(record) }
      return
    end

    page = normalized_page
    per_page = normalized_per_page
    total_count = scope.count
    records = scope.limit(per_page).offset((page - 1) * per_page)

    render json: {
      resource_key => records.map { |record| yield(record) },
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

  def paginated_request?
    params.key?(:page) || params.key?(:per_page)
  end

  def normalized_page
    parsed = params[:page].to_i
    parsed.positive? ? parsed : 1
  end

  def normalized_per_page
    parsed = params[:per_page].presence&.to_i || DEFAULT_PER_PAGE
    parsed = DEFAULT_PER_PAGE unless parsed.positive?
    [ parsed, MAX_PER_PAGE ].min
  end
end
