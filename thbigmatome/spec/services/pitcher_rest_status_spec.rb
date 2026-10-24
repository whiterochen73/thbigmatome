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
end
