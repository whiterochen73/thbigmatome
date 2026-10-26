require "rails_helper"

# Test Basis: rulebook 08-pitcher-management.md §8.3.1（先発→先発の休養表）/ cmd_1775 Operator 裁定 2026-10-25 #2
RSpec.describe PitcherRestStatus do
  describe ".starter_fatigue_p（カード疲労P 7 の先発）" do
    def fp(category, rest) = described_class.starter_fatigue_p(7, category, rest)

    it "通常: 中3日 P0 / 中4日 -3 / 中5日 -1 / 中6日以上 カード値" do
      expect([ fp("normal", 3), fp("normal", 4), fp("normal", 5), fp("normal", 6), fp("normal", 9) ]).to eq([ 0, 4, 6, 7, 7 ])
    end

    it "KO・ノーゲーム: 中3日 -3 / 中4日以上 カード値" do
      %w[ko no_game].each do |cat|
        expect([ fp(cat, 3), fp(cat, 4), fp(cat, 5) ]).to eq([ 4, 7, 7 ])
      end
    end

    it "長イニング敗戦: 中3日 P0 / 中4日 -4 / 中5日 -2 / 中6日 -1 / 中7日以上 カード値" do
      expect([ fp("long_loss", 3), fp("long_loss", 4), fp("long_loss", 5), fp("long_loss", 6), fp("long_loss", 7) ]).to eq([ 0, 3, 5, 6, 7 ])
    end

    it "中2日以内は登板不可（nil）" do
      expect(fp("normal", 2)).to be_nil
      expect(fp("normal", 0)).to be_nil
    end

    it "補正の下限は 0（カード疲労P が小さくても負にならない）" do
      expect(described_class.starter_fatigue_p(2, "long_loss", 4)).to eq(0)
    end

    it "前登板の区分が nil なら normal の表" do
      expect(fp(nil, 4)).to eq(4)
    end
  end

  # Test Basis: rulebook §8.3.4 スラッシュ選手（リリーフ→先発）
  describe ".slash_starter_fatigue_p_after_relief（カード疲労P 7）" do
    def fp(cumulative, rest) = described_class.slash_starter_fatigue_p_after_relief(7, cumulative, rest)

    it "累積0〜2I: 中3日 -1 / 中4日以上 カード値" do
      [ 0, 1, 2 ].each { |c| expect([ fp(c, 3), fp(c, 4), fp(c, 5) ]).to eq([ 6, 7, 7 ]) }
    end

    it "累積3I: 中3日 -3 / 中4日 -1 / 中5日以上 カード値" do
      expect([ fp(3, 3), fp(3, 4), fp(3, 5), fp(3, 6) ]).to eq([ 4, 6, 7, 7 ])
    end

    it "累積4I以上: 中3日 P0 / 中4日 -3 / 中5日 -1 / 中6日以上 カード値" do
      [ 4, 6, 9 ].each { |c| expect([ fp(c, 3), fp(c, 4), fp(c, 5), fp(c, 6) ]).to eq([ 0, 4, 6, 7 ]) }
    end

    it "中2日以内は登板不可（nil）" do
      expect(fp(3, 2)).to be_nil
    end
  end

  # 休養表示（calculate_projected_status）と補正表が食い違わないことの突き合わせ（裁定 #2「同じ表」）
  describe "calculate_projected_status との整合" do
    %w[normal ko no_game long_loss].each do |category|
      (3..9).each do |rest|
        it "#{category} 中#{rest}日: 表示の reduced_N / full と補正表が一致する" do
          status = described_class.calculate_projected_status("starter", rest, category, 0, false, 0)
          corrected = described_class.starter_fatigue_p(7, category, rest)
          case status
          when "full" then expect(corrected).to eq(7)
          when /\Areduced_(\d+)\z/ then expect(corrected).to eq(7 - Regexp.last_match(1).to_i)
          when "injury_check" then expect(corrected).to eq(0) # 中3日の P0 + 負傷チェック
          else raise "unexpected status #{status}"
          end
        end
      end
    end
  end

  # Test Basis: rulebook §8.3.1（KO・ノーゲーム中4日 / 長イニング敗戦中4日は「2回連続で発動」）/ §8.5.1 条件2 / cmd_1775 第2段 E8
  describe "calculate_projected_status: 中4日の「2回連続で負傷チェック」（E8）" do
    def status(category, rest, consecutive)
      described_class.calculate_projected_status("starter", rest, category, 0, false, consecutive)
    end

    it "KO 中4日: 1回目（連続カウント 0）は full、2回連続（>=1）は injury_check" do
      expect(status("ko", 4, 0)).to eq("full")
      expect(status("ko", 4, 1)).to eq("injury_check")
      expect(status("ko", 4, 2)).to eq("injury_check")
    end

    it "ノーゲーム 中4日も KO と同じ" do
      expect(status("no_game", 4, 0)).to eq("full")
      expect(status("no_game", 4, 1)).to eq("injury_check")
    end

    it "長イニング敗戦 中4日: 1回目は reduced_4（P-4・負傷チェックなし）、2回連続は injury_check" do
      expect(status("long_loss", 4, 0)).to eq("reduced_4")
      expect(status("long_loss", 4, 1)).to eq("injury_check")
    end

    it "連続カウントは中4日だけに効く（KO 中3日・中5日、長イニング中3日・中5日は変わらない）" do
      expect(status("ko", 3, 1)).to eq("reduced_3")
      expect(status("ko", 5, 1)).to eq("full")
      expect(status("long_loss", 3, 1)).to eq("injury_check")
      expect(status("long_loss", 5, 1)).to eq("reduced_2")
      expect(status("long_loss", 6, 1)).to eq("reduced_1")
    end

    it "通常 中4日の既存分岐は変わらない（0 → reduced_3、>=1 → injury_check）" do
      expect(status("normal", 4, 0)).to eq("reduced_3")
      expect(status("normal", 4, 1)).to eq("injury_check")
    end
  end

  # Test Basis: AMB-04 追補（2026-09-13）リセットは差し引かない実日数差 (next - last) - 1 >= 10 / cmd_1775 第2段 E5
  describe ".rest_reset?（中10日リセットの境）" do
    it "実日数中9日はリセットしない、中10日でリセットする" do
      expect(described_class.rest_reset?(Date.new(2026, 6, 1), Date.new(2026, 6, 11))).to be(false) # 中9日
      expect(described_class.rest_reset?(Date.new(2026, 6, 1), Date.new(2026, 6, 12))).to be(true)  # 中10日
    end
  end

  # Test Basis: AMB-04「出場停止と負傷は別枠」（2026-09-12）/ cmd_1775 第2段 E4
  describe ".injury_absences（中日数の控除・減衰凍結に使う離脱は負傷のみ）" do
    let(:team) { create(:team) }
    let(:season) { create(:season, team: team) }
    let(:membership) { create(:team_membership, team: team) }

    it "injury だけを返し、suspension / reconditioning は含めない" do
      %i[injury suspension reconditioning].each_with_index do |type, i|
        create(:player_absence, team_membership: membership, season: season, absence_type: type,
                                start_date: Date.new(2026, 6, 1 + i), duration: 2, duration_unit: "days")
      end
      result = described_class.injury_absences([ membership.id ])
      expect(result[membership.id].map { |a| a[:start_date] }).to eq([ Date.new(2026, 6, 1) ])
    end

    it "離脱が無い登録は空配列（キーなしでも空で引ける）" do
      expect(described_class.injury_absences([ membership.id ])[membership.id]).to eq([])
    end
  end
end
