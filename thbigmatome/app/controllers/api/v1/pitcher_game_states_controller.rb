module Api
  module V1
    class PitcherGameStatesController < BaseController
      include TeamAccessible

      before_action :set_team
      before_action :authorize_team_access!

      # GET /teams/:team_id/pitcher_game_states?date=YYYY-MM-DD&player_ids[]=1&player_ids[]=2
      def index
        target_date = params[:date]&.to_date || Date.today
        player_ids = params[:player_ids]&.map(&:to_i)

        pitcher_ids = if player_ids.present?
          player_ids
        else
          # 投手能力を持つカード（can_pitchスコープ）かつ野手専念契約でない選手のみ投手として扱う（#5 #6）
          @team.team_memberships
               .where.not(selected_cost_type: "fielder_only_cost")
               .joins(:player_card)
               .merge(PlayerCard.can_pitch)
               .distinct
               .pluck(:player_id)
        end

        injured_ids = build_injured_set(pitcher_ids, target_date)
        absence_map = preload_pitcher_absences(pitcher_ids)

        result = pitcher_ids.map do |player_id|
          last_app = PitcherGameState
            .where(pitcher_id: player_id, team_id: @team.id)
            .where("schedule_date < ?", target_date.to_s)
            .order(schedule_date: :desc)
            .first

          rest_days = nil
          cumulative_innings = 0
          last_role = nil
          absences = absence_map[player_id] || []

          if last_app
            last_date = last_app.schedule_date.to_date
            last_role = last_app.role

            rest_days = effective_rest_days(absences, last_date, target_date)

            if %w[reliever opener].include?(last_role)
              cumulative_innings = compute_cumulative_innings(player_id, target_date, absences)
            end
          end

          {
            player_id: player_id,
            rest_days: rest_days,
            cumulative_innings: cumulative_innings,
            last_role: last_role,
            is_injured: injured_ids.include?(player_id)
          }
        end

        render json: result
      end

      # GET /teams/:team_id/pitcher_game_states/fatigue_summary
      def fatigue_summary
        target_date = params[:date]&.to_date || Date.today

        # 1軍判定は昇降格の変更記録（RosterState）で target_date・phase 時点を導く。省略時は pre_game。記録が無い選手は 2軍
        phase = begin
          RosterState.parse_phase(params[:phase])
        rescue ArgumentError
          return render json: { error: "Invalid phase" }, status: :bad_request
        end
        # 投手能力を持つカード（can_pitchスコープ）かつ野手専念契約でない選手のみ（#5 #6）
        all_pitcher_memberships = @team.team_memberships
          .where.not(selected_cost_type: "fielder_only_cost")
          .joins(:player_card)
          .merge(PlayerCard.can_pitch)
          .includes(:player, :season_rosters, player_card: { player_card_abilities: :ability_definition })
          .distinct.to_a

        first_ids = RosterState.new(@team, memberships: all_pitcher_memberships).first_memberships(target_date, phase).map(&:id).to_set
        pitcher_memberships = all_pitcher_memberships.select { |tm| first_ids.include?(tm.id) }

        pitcher_ids = pitcher_memberships.map(&:player_id)
        name_map = pitcher_memberships.each_with_object({}) { |tm, h| h[tm.player_id] = tm.player.name }
        membership_map = pitcher_memberships.index_by(&:player_id)

        injured_ids = build_injured_set(pitcher_ids, target_date)
        absence_map = preload_pitcher_absences(pitcher_ids)

        # 「オープナー可」のアビリティ定義が 1 件でもあるか（1 リクエストで 1 回だけ問い合わせる）。無い間は
        # カードの記載が未取込なので、リリーフで投げられる投手全員を「オープナーなら」の対象にする（PlayerCard#opener_capable?）
        opener_definitions_present = AbilityDefinition.exists?
        opener_capable_source = opener_definitions_present ? "card_ability" : "fallback_all_relievers"

        result = pitcher_ids.map do |player_id|
          last_app = PitcherGameState
            .where(pitcher_id: player_id, team_id: @team.id)
            .where("schedule_date < ?", target_date.to_s)
            .order(schedule_date: :desc)
            .first

          rest_days = nil
          raw_rest_days = nil
          reset = false
          cumulative_innings = 0
          relief_cumulative_after_last = 0
          last_role = nil
          last_result_category = nil
          consecutive_short_rest_count = 0
          absences = absence_map[player_id] || []
          membership = membership_map[player_id]
          card = membership&.player_card

          if last_app
            last_date = last_app.schedule_date.to_date
            last_role = last_app.role
            last_result_category = last_app.result_category
            consecutive_short_rest_count = last_app.consecutive_short_rest_count || 0

            rest_days = effective_rest_days(absences, last_date, target_date)
            raw_rest_days = PitcherRestStatus.raw_rest_days(last_date, target_date)
            reset = PitcherRestStatus.rest_reset?(last_date, target_date)

            if %w[reliever opener].include?(last_role)
              cumulative_innings = compute_cumulative_innings(player_id, target_date, absences)
              # スラッシュ選手がリリーフ明けに先発する時の表選びは、直近リリーフ登板直後（減衰前）の累積（AMB-18 追補）
              if card&.slash_pitcher?
                relief_cumulative_after_last = compute_cumulative_innings(player_id, last_date + 1, absences)
              end
            end
          end

          is_injured = injured_ids.include?(player_id)

          states = PitcherRestStatus.role_states(
            last_role: last_role, rest_days: rest_days, raw_rest_days: raw_rest_days, reset: reset,
            last_result_category: last_result_category, cumulative_innings: cumulative_innings,
            relief_cumulative_after_last: relief_cumulative_after_last,
            consecutive_short_rest_count: consecutive_short_rest_count,
            is_injured: is_injured, slash: card&.slash_pitcher? || false,
            opener_capable: card&.opener_capable?(opener_definitions_present) || false
          )
          # 既存の projected_status は「前回と同じ役割で続ける場合」の状態
          projected = last_role.nil? || last_role == "starter" ? states[:as_starter][:status] : states[:as_reliever][:status]
          starter_omitted = starter_omitted_reason(membership)
          reliever_omitted = reliever_omitted_reason(membership)
          as_starter = starter_omitted ? nil : states[:as_starter]
          as_reliever = reliever_omitted ? nil : states[:as_reliever]
          # 「オープナーなら」は「オープナー可」アビリティを持つ投手だけ（rulebook 08 §8.4.1）。持たない投手は nil
          as_opener = states[:as_opener]

          {
            player_id: player_id,
            player_name: name_map[player_id],
            last_role: last_role,
            rest_days: last_role == "starter" ? rest_days : nil,
            cumulative_innings: %w[reliever opener].include?(last_role) ? cumulative_innings : nil,
            last_result_category: last_result_category,
            is_injured: is_injured,
            # 先発としては登板不可（中2日以内。前回の役割に依らない §8.7.2）。リリーフ専門など「先発なら」を出さない投手は false
            is_unavailable: !is_injured && as_starter&.dig(:status) == "unavailable",
            projected_status: projected,
            as_starter: as_starter,
            as_reliever: as_reliever,
            as_opener: as_opener,
            as_starter_omitted_reason: starter_omitted,
            as_reliever_omitted_reason: reliever_omitted,
            as_opener_omitted_reason: as_opener ? nil : "no_opener_ability",
            # as_opener の出し分けの根拠。fallback_all_relievers = オープナー可のデータ未取込（リリーフで投げられる投手全員）/ card_ability = カードの記載どおり
            opener_capable_source: opener_capable_source,
            # カード記載の疲労P（画面の「カード疲労P」列。6/1・1R・6 の組み立ては画面側）。試合前補正を掛けた計算値とは別物
            starter_stamina: card&.starter_stamina,
            relief_stamina: card&.relief_stamina,
            is_relief_only: card&.is_relief_only || false
          }
        end

        render json: result
      end

      private

      # 「先発なら」を出さない理由。リリーフ専門（カード）か救援専任契約。先発もできる契約に変われば nil に戻る
      def starter_omitted_reason(membership)
        return nil if membership.nil?
        return "relief_only_card" if membership.player_card&.is_relief_only
        return "relief_only_contract" if membership.relief_only_contract?

        nil
      end

      # 「リリーフなら」を出さない理由。リリーフ向けの疲労P（relief_stamina）をカードに持たない先発。リリーフ専門のカードは出す
      def reliever_omitted_reason(membership)
        return nil if membership.nil?

        card = membership.player_card
        return nil if card.nil? || card.relief_capable?

        "no_relief_stamina"
      end

      def set_team
        @team = Team.find(params[:team_id])
      end

      def build_injured_set(pitcher_ids, target_date)
        tm_map = @team.team_memberships
          .where(player_id: pitcher_ids)
          .each_with_object({}) { |tm, h| h[tm.id] = tm.player_id }

        return Set.new if tm_map.empty?

        PlayerAbsence
          .where(team_membership_id: tm_map.keys)
          .select { |pa|
            start = pa.start_date&.to_date
            end_d = pa.respond_to?(:effective_end_date) ? pa.effective_end_date&.to_date : pa.end_date&.to_date
            next false unless start && start <= target_date
            end_d.nil? || end_d > target_date
          }
          .map { |pa| tm_map[pa.team_membership_id] }
          .compact
          .to_set
      end

      # 複数投手の中日数控除用の離脱期間（負傷のみ）を一括取得。
      # 出場停止・再調整は中日数にも累積イニングの減衰凍結にも使わない（AMB-04「出場停止と負傷は別枠」）。
      # 出場可否の表示（build_injured_set）は全種別を見るので、ここを通さない。
      # 戻り値: { player_id => [{start_date:, end_date:}, ...] }
      # end_date は復帰可能日（排他的）。nil は無期限離脱。
      def preload_pitcher_absences(pitcher_ids)
        tm_map = @team.team_memberships
          .where(player_id: pitcher_ids)
          .each_with_object({}) { |tm, h| h[tm.id] = tm.player_id }

        return {} if tm_map.empty?

        by_membership = PitcherRestStatus.injury_absences(tm_map.keys)
        tm_map.each_with_object({}) do |(tm_id, player_id), result|
          result[player_id] = by_membership[tm_id]
        end
      end

      # 画面に返す中日数。実日数差が中10日以上ならリセット成立で、離脱を差し引かない実日数を返す
      # （控除後の中日数が2日以内でも登板不可にしない。AMB-04 追補2）。リセット不成立なら負傷を差し引いた値。
      def effective_rest_days(absences, last_date, target_date)
        raw_rest_days = PitcherRestStatus.raw_rest_days(last_date, target_date)
        return raw_rest_days if PitcherRestStatus.rest_reset?(last_date, target_date)

        raw_rest_days - absence_days_in_range(absences, last_date + 1, target_date - 1)
      end

      def absence_days_in_range(absences, from_date, to_date)
        PitcherRestStatus.absence_days_in_range(absences, from_date, to_date)
      end

      # 判定表は PitcherRestStatus に集約（先発の試合前疲労P計算と共有）
      def calculate_projected_status(*args)
        PitcherRestStatus.calculate_projected_status(*args)
      end

      def compute_cumulative_innings(pitcher_id, target_date, absences = [])
        PitcherRestStatus.cumulative_innings(@team.id, pitcher_id, target_date, absences)
      end
    end
  end
end
