require "rails_helper"

# 投手ごとに「先発なら」「リリーフなら」の登板時の状態を並べて出す（cmd_1775 第3段 E10・E9）。
# Test Basis:
#   rulebook 08-pitcher-management.md §8.3.1（先発→先発）/ §8.3.2（リリーフ→リリーフ・累積イニング）/
#   §8.3.3（先発→リリーフ・スラッシュは 1 日短縮）/ §8.3.4（リリーフ→先発・スラッシュの累積別 3 表）/
#   §8.4.3（オープナーの負傷チェック）/ §8.5.1 / §8.7.2（先発は中2日以内不可。前回リリーフでも）
#   台帳 AMB-18 追補（リリーフ→先発の補正）/ AMB-19 追補（疲労P0 と「最初から疲労状態」は別状態）/
#   AMB-21（中5日/中6日は回復の上限）/ AMB-04 追補 2（中10日リセットは登板可否より優先）/
#   「Dugout 監査 E9〜E12 の残り — 実装の範囲」（2026-10-26 Operator 決定）
RSpec.describe PitcherRestStatus, ".role_states" do
  # 既定: 前回先発・通常・中4日・連続なし・スラッシュでない・リセットなし
  def states(last_role: "starter", rest_days: 4, raw_rest_days: nil, reset: false, category: "normal",
             cumulative: 0, relief_cumulative: nil, consecutive: 0, injured: false, slash: false, opener_capable: true)
    described_class.role_states(
      last_role: last_role, rest_days: rest_days, raw_rest_days: raw_rest_days || rest_days, reset: reset,
      last_result_category: category, cumulative_innings: cumulative,
      relief_cumulative_after_last: relief_cumulative || cumulative,
      consecutive_short_rest_count: consecutive, is_injured: injured, slash: slash,
      opener_capable: opener_capable
    )
  end

  def starter(**args) = states(**args)[:as_starter][:status]
  def reliever(**args) = states(**args)[:as_reliever][:status]

  describe "共通" do
    it "登板歴なしは どちらも full" do
      s = states(last_role: nil, rest_days: nil)
      expect([ s[:as_starter][:status], s[:as_reliever][:status] ]).to eq(%w[full full])
    end

    it "負傷中は どちらも injured" do
      s = states(injured: true)
      expect([ s[:as_starter][:status], s[:as_reliever][:status] ]).to eq(%w[injured injured])
    end

    it "中10日リセット成立は、前回の役割・中日数に依らず どちらも full（登板可否より優先）" do
      %w[starter reliever opener].each do |role|
        s = states(last_role: role, rest_days: 0, raw_rest_days: 10, reset: true, category: "long_loss", cumulative: 9)
        expect([ role, s[:as_starter][:status], s[:as_reliever][:status] ]).to eq([ role, "full", "full" ])
      end
    end
  end

  describe "先発なら: 前回が先発（§8.3.1。既存の休養表と同じ）" do
    %w[normal ko no_game long_loss].each do |category|
      (0..9).each do |rest|
        [ 0, 1 ].each do |count|
          it "#{category} 中#{rest}日 連続#{count}: calculate_projected_status と一致" do
            expect(starter(category: category, rest_days: rest, consecutive: count))
              .to eq(described_class.calculate_projected_status("starter", rest, category, 0, false, count))
          end
        end
      end
    end
  end

  describe "先発なら: 前回がリリーフ（§8.3.4 通常選手。AMB-18 追補）" do
    it "中2日以内は先発不可（§8.7.2。前回リリーフでも）" do
      [ 0, 1, 2 ].each { |rest| expect(starter(last_role: "reliever", rest_days: rest)).to eq("unavailable") }
    end

    it "中3日 P0（負傷チェック）/ 中4日 P-3 / 中5日 P-1 / 中6日以上 カード値" do
      expect([ 3, 4, 5, 6, 9 ].map { |r| starter(last_role: "reliever", rest_days: r) })
        .to eq(%w[injury_check reduced_3 reduced_1 full full])
    end

    it "オープナーも同じ（登板はリリーフとして扱う §8.4.2）" do
      expect([ 2, 3, 4 ].map { |r| starter(last_role: "opener", rest_days: r) }).to eq(%w[unavailable injury_check reduced_3])
    end

    it "前回の区分（long_loss など）は先発→先発の表にだけ効く。前回リリーフは通常選手の表" do
      expect(starter(last_role: "reliever", rest_days: 4, category: "long_loss")).to eq("reduced_3")
    end

    it "前回リリーフでは連続中4日のカウントを見ない（先発→先発の『2回連続』だけに効く）" do
      expect(starter(last_role: "reliever", rest_days: 4, consecutive: 1)).to eq("reduced_3")
    end
  end

  describe "先発なら: 前回がリリーフ（§8.3.4 スラッシュ選手。累積別 3 表）" do
    def slash_starter(cum, rest) = starter(last_role: "reliever", rest_days: rest, slash: true, relief_cumulative: cum, cumulative: 0)

    it "累積2I以下（0・1・2）: 中3日 P-1 / 中4日以上 カード値" do
      [ 0, 1, 2 ].each { |c| expect([ 3, 4, 5 ].map { |r| slash_starter(c, r) }).to eq(%w[reduced_1 full full]) }
    end

    it "累積3I: 中3日 P-3 / 中4日 P-1 / 中5日以上 カード値" do
      expect([ 3, 4, 5, 6 ].map { |r| slash_starter(3, r) }).to eq(%w[reduced_3 reduced_1 full full])
    end

    it "累積4I以上: 中3日 P0（疲労状態・負傷チェック）/ 中4日 P-3 / 中5日 P-1 / 中6日以上 カード値" do
      [ 4, 6, 9 ].each { |c| expect([ 3, 4, 5, 6 ].map { |r| slash_starter(c, r) }).to eq(%w[injury_check reduced_3 reduced_1 full]) }
    end

    it "中2日以内は累積に依らず先発不可" do
      [ 0, 3, 5 ].each { |c| expect([ 1, 2 ].map { |r| slash_starter(c, r) }).to eq(%w[unavailable unavailable]) }
    end

    it "表を選ぶ累積は、直近リリーフ登板直後（減衰前）の値。減衰後の cumulative_innings ではない" do
      expect(starter(last_role: "reliever", rest_days: 3, slash: true, relief_cumulative: 4, cumulative: 0)).to eq("injury_check")
    end
  end

  describe "リリーフなら: 前回が先発（§8.3.3）" do
    def after_start(category, rest, slash: false) = reliever(last_role: "starter", rest_days: rest, category: category, slash: slash)

    it "通常: 中3日 P0 / 中4日以上 カード値。それ未満（中2日以内）は登板不可（AMB-22）" do
      expect([ 0, 2, 3, 4, 8 ].map { |r| after_start("normal", r) }).to eq(%w[unavailable unavailable reduced_0 full full])
    end

    it "KO・ノーゲーム: 中2日 P0 / 中3日以上 カード値。中1日以内は登板不可（AMB-22）" do
      %w[ko no_game].each { |c| expect([ 0, 1, 2, 3, 6 ].map { |r| after_start(c, r) }).to eq(%w[unavailable unavailable reduced_0 full full]) }
    end

    it "長イニング敗戦: 中4日 P0 / 中5日以上 カード値。中3日以内は登板不可（AMB-22）" do
      expect([ 0, 2, 3, 4, 5, 7 ].map { |r| after_start("long_loss", r) }).to eq(%w[unavailable unavailable unavailable reduced_0 full full])
    end

    it "スラッシュ選手は各ケース 1 日短縮: 通常 中2日 P0・中3日以上 / KO 中1日 P0・中2日以上 / 長イニング 中3日 P0・中4日以上" do
      expect([ 1, 2, 3 ].map { |r| after_start("normal", r, slash: true) }).to eq(%w[unavailable reduced_0 full])
      expect([ 0, 1, 2 ].map { |r| after_start("ko", r, slash: true) }).to eq(%w[unavailable reduced_0 full])
      expect([ 0, 1, 2 ].map { |r| after_start("no_game", r, slash: true) }).to eq(%w[unavailable reduced_0 full])
      expect([ 2, 3, 4 ].map { |r| after_start("long_loss", r, slash: true) }).to eq(%w[unavailable reduced_0 full])
    end

    # Test Basis: 台帳 AMB-22（2026-10-26 Operator）「表にないほど短い間隔では救援登板も不可」。
    #   境界: 表の最短行（P0）の 1 日前は不可、最短行は P0。最短行より短い日数はすべて不可（no_rule という状態は無い）
    describe "AMB-22: 表より短い間隔はリリーフも登板不可（区分 × スラッシュ有無の境界）" do
      # [区分, スラッシュ, 表の最短行（P0 になる中日数）]
      [
        [ "normal", false, 3 ], [ "normal", true, 2 ],
        [ "ko", false, 2 ], [ "ko", true, 1 ],
        [ "no_game", false, 2 ], [ "no_game", true, 1 ],
        [ "long_loss", false, 4 ], [ "long_loss", true, 3 ]
      ].each do |category, slash, shortest|
        it "#{category}#{slash ? '（スラッシュ）' : ''}: 中#{shortest - 1}日 = unavailable / 中#{shortest}日 = reduced_0" do
          expect(after_start(category, shortest - 1, slash: slash)).to eq("unavailable")
          expect(after_start(category, shortest, slash: slash)).to eq("reduced_0")
        end

        it "#{category}#{slash ? '（スラッシュ）' : ''}: 中0日〜中#{shortest - 1}日はすべて unavailable（no_rule にならない）" do
          expect((0...shortest).map { |r| after_start(category, r, slash: slash) }.uniq).to eq([ "unavailable" ])
        end
      end

      it "no_rule という状態は返さない（どの区分・中日数・スラッシュ有無でも）" do
        got = %w[normal ko no_game long_loss].product([ true, false ], (0..12).to_a).map { |c, s, r| after_start(c, r, slash: s) }
        expect(got).not_to include("no_rule")
      end

      it "先発明けの登板不可は is_injured に勝たない（負傷中は injured のまま）" do
        expect(states(last_role: "starter", rest_days: 1, injured: true)[:as_reliever][:status]).to eq("injured")
      end
    end

    it "前回の区分が nil なら通常の表" do
      expect(after_start(nil, 3)).to eq("reduced_0")
    end

    it "先発明けにはオープナー・前日登板の注記を付けない（累積は 0）" do
      expect(states(last_role: "starter", rest_days: 3)[:as_reliever][:notes]).to eq([])
    end
  end

  describe "リリーフなら: 前回がリリーフ（§8.3.2。AMB-19 追補: 疲労P0 と最初から疲労状態は別）" do
    def after_relief(cum, rest = 1, **rest_of) = reliever(last_role: "reliever", rest_days: rest, cumulative: cum, **rest_of)

    it "累積0 カード値 / 1 疲労P0 / 2 最初から疲労状態（P0 とは別の値）" do
      expect([ 0, 1, 2 ].map { |c| after_relief(c) }).to eq(%w[full reduced_0 fatigued_start])
      expect(after_relief(2)).not_to eq(after_relief(1))
    end

    it "累積3以上は最初から疲労状態 + 登板後の負傷チェック（疲労状態が見えなくならない別の値）" do
      expect([ 3, 4, 9 ].map { |c| after_relief(c) }).to eq(%w[fatigued_start_check fatigued_start_check fatigued_start_check])
    end

    it "オープナーの前回もリリーフと同じ" do
      expect(reliever(last_role: "opener", rest_days: 1, cumulative: 2)).to eq("fatigued_start")
    end
  end

  # Test Basis: AMB-21（2026-10-26 本体判断・Operator 委任）。中5日 → 累積1以下（P0）、中6日以上 → 累積0（カード値）が回復の上限。
  #   cumulative は減衰後の値。累積の減衰でそれより良ければ累積の表を使う（中5日で P0 に悪化させない）
  describe "リリーフなら: 中5日・中6日は回復の上限（AMB-21）" do
    def after_relief(cum, rest) = reliever(last_role: "reliever", rest_days: rest, cumulative: cum)

    it "中5日: 減衰後の累積が 3 でも P0 まで戻る（累積8 で休養5日 → 減衰後 3）" do
      expect(after_relief(3, 5)).to eq("reduced_0")
    end

    it "中6日: 減衰後の累積が 1 でもカード値まで戻る（累積8 で休養6日 → 減衰後 1）" do
      expect(after_relief(1, 6)).to eq("full")
    end

    it "中5日: 累積0 はカード値のまま（P0 に悪化させない）" do
      expect(after_relief(0, 5)).to eq("full")
    end

    it "中5日: 累積1 は P0（上限と同じ）、累積2 は P0 まで改善" do
      expect([ 1, 2 ].map { |c| after_relief(c, 5) }).to eq(%w[reduced_0 reduced_0])
    end

    it "中4日までは上限なし（累積3 は最初から疲労状態 + 負傷チェックのまま）" do
      expect(after_relief(3, 4)).to eq("fatigued_start_check")
    end

    it "中6日以上はどんな累積でもカード値" do
      expect([ 1, 2, 3, 6 ].map { |c| after_relief(c, 6) }).to eq(%w[full full full full])
      expect(after_relief(9, 20)).to eq("full")
    end

    it "注記は上限を掛けた後の累積で決める（中5日で累積4 → 前日登板の注意書きは付かない）" do
      expect(states(last_role: "reliever", rest_days: 5, cumulative: 4)[:as_reliever][:notes]).to eq([])
    end
  end

  describe "リリーフなら: 注記（§8.3.2 前日登板）" do
    def notes(cum, rest: 1, raw: nil) = states(last_role: "reliever", rest_days: rest, raw_rest_days: raw || rest, cumulative: cum)[:as_reliever][:notes]

    it "オープナーの負傷チェックの注記は「リリーフなら」側には出さない（「オープナーなら」列へ移した）" do
      expect([ 0, 1, 2, 3 ].map { |c| notes(c) }).to eq([ [], [], [], [] ])
    end

    it "累積4以上かつ前日登板: 合否は記録せず、1イニング限定の注意書きだけ出す" do
      expect(notes(4, rest: 0)).to eq(%w[previous_day_one_inning_only])
      expect(notes(9, rest: 0)).to include("previous_day_one_inning_only")
    end

    it "前日登板の注意書きは累積4以上だけ（累積3 の前日登板には出さない）" do
      expect(notes(3, rest: 0)).not_to include("previous_day_one_inning_only")
    end

    it "前日登板でなければ（中1日）累積4以上でも出さない" do
      expect(notes(5, rest: 1)).not_to include("previous_day_one_inning_only")
    end

    it "前日登板は離脱を差し引かない実日数で見る（実日数 中1日・控除後 0 は前日登板ではない）" do
      expect(notes(4, rest: 0, raw: 1)).not_to include("previous_day_one_inning_only")
    end

    it "「先発なら」側には注記を付けない" do
      expect(states(last_role: "reliever", rest_days: 0, cumulative: 5)[:as_starter][:notes]).to eq([])
    end
  end

  # Test Basis: rulebook 08 §8.4.2（オープナー本人はこの登板をリリーフ扱い）/ §8.4.3（負傷チェック発動条件 3 つ）/
  #   §8.4.1（「オープナー可」アビリティ保有選手のみ）/ Operator 2026-10-27（「リリーフなら」の隣に「オープナーなら」列を 1 つ増やす）
  describe "オープナーなら（§8.4.2・§8.4.3）" do
    def opener(**args) = states(**args)[:as_opener]
    def opener_notes(cum, role: "reliever", rest: 1, raw: nil) = opener(last_role: role, rest_days: rest, raw_rest_days: raw || rest, cumulative: cum)[:notes]

    it "「オープナー可」を持たない投手は nil（API でも出さない）" do
      expect(states(last_role: "reliever", rest_days: 0, cumulative: 5, opener_capable: false)[:as_opener]).to be_nil
      expect(states(last_role: nil, rest_days: nil, opener_capable: false)[:as_opener]).to be_nil
      expect(states(injured: true, opener_capable: false)[:as_opener]).to be_nil
    end

    it "状態は「リリーフなら」と同じ（オープナー本人はリリーフ扱い §8.4.2）。前回が先発でも・リリーフでも" do
      [ [ "starter", 3, 0 ], [ "starter", 1, 0 ], [ "reliever", 1, 2 ], [ "reliever", 1, 4 ], [ "opener", 3, 1 ] ].each do |role, rest, cum|
        s = states(last_role: role, rest_days: rest, cumulative: cum)
        expect(s[:as_opener][:status]).to eq(s[:as_reliever][:status])
      end
    end

    it "登板歴なし・中10日リセット・負傷中は注記なし（負傷中は injured）" do
      expect(opener(last_role: nil, rest_days: nil)).to eq({ status: "full", notes: [] })
      expect(opener(last_role: "opener", rest_days: 0, raw_rest_days: 10, reset: true, cumulative: 9)).to eq({ status: "full", notes: [] })
      expect(opener(injured: true)).to eq({ status: "injured", notes: [] })
    end

    it "累積1以上: 負傷チェック（累積0 は出さない）" do
      expect(opener_notes(0)).to eq([])
      expect(opener_notes(1)).to eq(%w[opener_check_cumulative])
      expect(opener_notes(3)).to eq(%w[opener_check_cumulative])
    end

    it "累積は上限を掛けた後で見る（中5日で累積4 → 累積1 扱い。中6日で累積9 → 0 扱いで出ない）" do
      expect(opener_notes(4, rest: 5)).to eq(%w[opener_check_cumulative])
      expect(opener_notes(9, rest: 6)).to eq([])
    end

    it "前日登板（離脱を差し引かない実日数 0）: 負傷チェック。実日数 中1日なら前日登板ではない" do
      expect(opener_notes(0, rest: 0)).to eq(%w[opener_check_previous_day])
      expect(opener_notes(2, rest: 0)).to eq(%w[opener_check_previous_day opener_check_cumulative])
      expect(opener_notes(0, rest: 0, raw: 1)).to eq([])
    end

    it "中2日以内の連続オープナー登板: 前回がオープナー・中2日以内で負傷チェック。中3日以上・前回がリリーフ/先発なら対象外" do
      expect(opener_notes(0, role: "opener", rest: 2)).to eq(%w[opener_check_consecutive])
      expect(opener_notes(0, role: "opener", rest: 1)).to eq(%w[opener_check_consecutive])
      expect(opener_notes(0, role: "opener", rest: 3)).to eq([])
      expect(opener_notes(0, role: "reliever", rest: 2)).to eq([])
    end

    it "3 条件が重なれば全部並べる（連続・前日・累積の順）" do
      expect(opener_notes(2, role: "opener", rest: 0)).to eq(%w[opener_check_consecutive opener_check_previous_day opener_check_cumulative])
    end

    it "累積4以上で前日登板: 1イニング限定の注意書きも付く（オープナー本人もリリーフ扱い）" do
      expect(opener_notes(4, rest: 0)).to eq(%w[opener_check_previous_day opener_check_cumulative previous_day_one_inning_only])
    end

    it "登板不可・負傷中には注記を付けない（登板できないので）" do
      s = opener(last_role: "starter", rest_days: 0, category: "normal")
      expect(s).to eq({ status: "unavailable", notes: [] })
    end

    it "「リリーフなら」「先発なら」の notes には opener_check_* を混ぜない" do
      s = states(last_role: "opener", rest_days: 0, cumulative: 3)
      expect((s[:as_reliever][:notes] + s[:as_starter][:notes]).grep(/opener/)).to eq([])
    end
  end

  describe "calculate_projected_status（同じ役割で続ける場合の既存表示）のリリーフ分岐" do
    def status(cum, rest = 1) = described_class.calculate_projected_status("reliever", rest, "normal", cum, false, 0)

    it "累積2 は最初から疲労状態（reduced_0 と区別する）、3以上は +負傷チェック" do
      expect([ 0, 1, 2, 3, 6 ].map { |c| status(c) }).to eq(%w[full reduced_0 fatigued_start fatigued_start_check fatigued_start_check])
    end

    it "AMB-21 の上限は同じ休養日数で効く（中5日で累積3 → reduced_0、中6日で累積3 → full）" do
      expect([ status(3, 5), status(3, 6), status(0, 5) ]).to eq(%w[reduced_0 full full])
    end
  end
end
