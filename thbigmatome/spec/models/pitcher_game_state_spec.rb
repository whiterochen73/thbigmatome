require "rails_helper"

RSpec.describe PitcherGameState, type: :model do
  describe "アソシエーション" do
    it { is_expected.to belong_to(:game) }
    it { is_expected.to belong_to(:pitcher).class_name("Player") }
    it { is_expected.to belong_to(:competition).optional }
    it { is_expected.to belong_to(:team) }
  end

  describe "バリデーション: pitcher_id の一意性（scope: game_id）" do
    it "同じゲームで同じ投手は登録できない" do
      game = create(:game)
      pitcher = create(:player, :pitcher)
      create(:pitcher_game_state, game: game, pitcher: pitcher)
      duplicate = build(:pitcher_game_state, game: game, pitcher: pitcher)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:pitcher_id]).to be_present
    end

    it "別ゲームで同じ投手は有効" do
      pitcher = create(:player, :pitcher)
      create(:pitcher_game_state, pitcher: pitcher)
      pgs2 = build(:pitcher_game_state, pitcher: pitcher)
      expect(pgs2).to be_valid
    end
  end

  describe "バリデーション: role" do
    %w[starter reliever opener].each do |valid_role|
      it "#{valid_role} は有効" do
        pgs = build(:pitcher_game_state, role: valid_role)
        expect(pgs).to be_valid
      end
    end

    it "invalid はエラー" do
      pgs = build(:pitcher_game_state, role: "invalid")
      expect(pgs).not_to be_valid
      expect(pgs.errors[:role]).to be_present
    end
  end

  describe "バリデーション: result_category" do
    %w[normal ko no_game long_loss].each do |valid_category|
      it "#{valid_category} は有効" do
        pgs = build(:pitcher_game_state, result_category: valid_category)
        expect(pgs).to be_valid
      end
    end

    it "nil は有効（allow_nil）" do
      pgs = build(:pitcher_game_state, result_category: nil)
      expect(pgs).to be_valid
    end

    it "invalid はエラー" do
      pgs = build(:pitcher_game_state, result_category: "invalid")
      expect(pgs).not_to be_valid
      expect(pgs.errors[:result_category]).to be_present
    end
  end

  describe ".calculate_result_category" do
    # 長イニング敗戦の閾値は「関与イニング > 補正後の疲労P + 1」（ルール§8.2.3 / §8.2.4）。
    # fatigue_p は試合前のスタミナ補正をかけた値。0 は「補正の結果 0」で、カード未記載の既定 3 とは別物（Operator 裁定 2026-10-25）。
    def category(**kw)
      described_class.calculate_result_category(**{ role: "starter", pitchers_in_game: 1 }.merge(kw))
    end

    context "game_result が no_game のとき" do
      it "no_game を返す" do
        expect(category(innings_pitched: 6.0, game_result: "no_game")).to eq("no_game")
      end
    end

    context "role が starter 以外（reliever / opener）のとき" do
      it "reliever は normal を返す" do
        expect(category(role: "reliever", innings_pitched: 2.0, game_result: "win", pitchers_in_game: 3)).to eq("normal")
      end

      it "opener は normal を返す" do
        expect(category(role: "opener", innings_pitched: 1.0, game_result: "win", pitchers_in_game: 2)).to eq("normal")
      end
    end

    context "KO（starter で innings < 5 かつ 後続投手あり かつ 負け かつ decision=L）" do
      it "ko を返す" do
        expect(category(innings_pitched: 4.2, game_result: "lose", pitchers_in_game: 2, decision: "L")).to eq("ko")
      end

      it "KO は疲労P が分からなくても決まる（fatigue_p: nil でも ko）" do
        expect(category(innings_pitched: 4.0, game_result: "lose", pitchers_in_game: 2, decision: "L", fatigue_p: nil)).to eq("ko")
      end
    end

    describe "KO の境界値" do
      it "innings==5.0 は KO にならない（normal。疲労P6なら 5 <= 7）" do
        expect(category(innings_pitched: 5.0, game_result: "lose", pitchers_in_game: 2, fatigue_p: 6, decision: "L")).to eq("normal")
      end

      it "innings==4.2 は KO（< 5 かつ後続あり かつ decision='L'）" do
        expect(category(innings_pitched: 4.2, game_result: "lose", pitchers_in_game: 2, decision: "L")).to eq("ko")
      end

      it "pitchers_in_game==1（完投）は KO にならない" do
        expect(category(innings_pitched: 4.0, game_result: "lose", pitchers_in_game: 1, decision: "L", fatigue_p: 6)).to eq("normal")
      end

      it "勝ち試合で先発が4回降板 → KO にならない（normal）" do
        expect(category(innings_pitched: 4.0, game_result: "win", pitchers_in_game: 2)).to eq("normal")
      end

      it "負け試合で先発が4回降板 + decision='L' → KO" do
        expect(category(innings_pitched: 4.0, game_result: "lose", pitchers_in_game: 2, decision: "L")).to eq("ko")
      end

      it "負け試合で先発が4回降板 + decision=nil（リリーフがLを持つ） → KO にならない" do
        expect(category(innings_pitched: 4.0, game_result: "lose", pitchers_in_game: 2, decision: nil, fatigue_p: 6)).to eq("normal")
      end

      # E11: KO には 0アウト降板の +1 を掛けない（§8.2.4 の適用範囲は長イニング敗戦と累積イニング）
      it "E11: 4回を投げ切り5回の頭に入って0アウト降板（no_out_exit）・負け・L・後続あり → ko（+1 しない）" do
        expect(category(innings_pitched: 4.0, game_result: "lose", pitchers_in_game: 2, decision: "L", no_out_exit: true)).to eq("ko")
      end

      # AMB-20 追補（Operator 裁定 2026-10-25）: 1つもアウトを取れず降板した先発（0.0回・no_out_exit）も KO。
      # innings_pitched > 0 は「登板した」の意味で読む。
      it "AMB-20追補: 0.0回・no_out_exit・負け・L・後続あり → ko" do
        expect(category(innings_pitched: 0.0, game_result: "lose", pitchers_in_game: 4, decision: "L", no_out_exit: true)).to eq("ko")
      end

      it "AMB-20追補: 0.0回・no_out_exit でも勝ち試合なら normal" do
        expect(category(innings_pitched: 0.0, game_result: "win", pitchers_in_game: 2, decision: nil, no_out_exit: true)).to eq("normal")
      end

      it "AMB-20追補: 0.0回・no_out_exit・負け でも敗戦投手でない（decision なし）なら normal" do
        expect(category(innings_pitched: 0.0, game_result: "lose", pitchers_in_game: 2, decision: nil, no_out_exit: true, fatigue_p: 6)).to eq("normal")
      end

      it "AMB-20追補: 0.0回・no_out_exit・負け・L でも後続投手なしなら normal" do
        expect(category(innings_pitched: 0.0, game_result: "lose", pitchers_in_game: 1, decision: "L", no_out_exit: true, fatigue_p: 6)).to eq("normal")
      end

      it "AMB-20追補: 0.0回で no_out_exit でない記録は ko にならない（登板していない扱い）" do
        expect(category(innings_pitched: 0.0, game_result: "lose", pitchers_in_game: 2, decision: "L", no_out_exit: false, fatigue_p: 6)).to eq("normal")
      end

      # Operator 念押し 2026-10-25: 6イニング目のマウンドに上がっていたら（投球回 5.0）0アウト降板でも KO は付かない
      it "AMB-20追補の境界: 5.0回・no_out_exit・負け・L・後続あり → ko ではない（normal。疲労P6なら関与6 <= 7）" do
        expect(category(innings_pitched: 5.0, game_result: "lose", pitchers_in_game: 2, decision: "L", no_out_exit: true, fatigue_p: 6)).to eq("normal")
      end

      it "AMB-20追補の境界: 4.2回・no_out_exit・負け・L・後続あり → ko" do
        expect(category(innings_pitched: 4.2, game_result: "lose", pitchers_in_game: 2, decision: "L", no_out_exit: true)).to eq("ko")
      end

      it "AMB-20追補: 0アウト降板の +1 は KO に掛けない（4.0回 + 5回頭0アウト降板 は ko のまま）" do
        expect(category(innings_pitched: 4.0, game_result: "lose", pitchers_in_game: 3, decision: "L", no_out_exit: true)).to eq("ko")
      end
    end

    describe "長イニング敗戦: 関与イニング > 補正後の疲労P + 1（Operator 例 2026-10-25）" do
      context "疲労P6・補正なし（閾値 7）" do
        it "7.0回で7回終了降板・負け → normal（関与7）" do
          expect(category(innings_pitched: 7.0, game_result: "lose", fatigue_p: 6)).to eq("normal")
        end

        it "7.0回 + 8回に入って0アウト降板（no_out_exit）・負け → long_loss（関与8）" do
          expect(category(innings_pitched: 7.0, game_result: "lose", fatigue_p: 6, no_out_exit: true, pitchers_in_game: 2)).to eq("long_loss")
        end

        it "7.1回・負け → long_loss（関与8）" do
          expect(category(innings_pitched: 7.1, game_result: "lose", fatigue_p: 6)).to eq("long_loss")
        end

        it "勝ち・引き分けなら 7.1回でも normal" do
          %w[win draw].each do |gr|
            expect(category(innings_pitched: 7.1, game_result: gr, fatigue_p: 6)).to eq("normal")
          end
        end
      end

      context "疲労P6・中5日の補正-1（→5。閾値 6）" do
        it "6.0回で6回終了降板・負け → normal（関与6）" do
          expect(category(innings_pitched: 6.0, game_result: "lose", fatigue_p: 5)).to eq("normal")
        end

        it "6.0回 + 7回に入って0アウト降板・負け → long_loss（関与7）" do
          expect(category(innings_pitched: 6.0, game_result: "lose", fatigue_p: 5, no_out_exit: true, pitchers_in_game: 2)).to eq("long_loss")
        end

        it "6.1回・負け → long_loss（関与7）" do
          expect(category(innings_pitched: 6.1, game_result: "lose", fatigue_p: 5)).to eq("long_loss")
        end

        it "勝ち・引き分けなら 6.1回でも normal" do
          %w[win draw].each do |gr|
            expect(category(innings_pitched: 6.1, game_result: gr, fatigue_p: 5)).to eq("normal")
          end
        end
      end

      it "疲労P7: 8.0回・負け → normal / 8.1回・負け → long_loss" do
        expect(category(innings_pitched: 8.0, game_result: "lose", fatigue_p: 7)).to eq("normal")
        expect(category(innings_pitched: 8.1, game_result: "lose", fatigue_p: 7)).to eq("long_loss")
      end

      it "疲労P7: 勝ち・引き分けなら9回でも normal" do
        %w[win draw].each do |gr|
          expect(category(innings_pitched: 9.0, game_result: gr, fatigue_p: 7)).to eq("normal")
        end
      end
    end

    describe "関与イニングは前の投手のアウト数から入った回を出す（第二先発。§8.2.4）" do
      it "前の投手が1回1/3（4アウト）を投げた後に入った先発扱いの投手が 6.2回 → 関与7（疲労P5 閾値6 → long_loss）" do
        # start_inning = floor(4/3)+1 = 2, end_inning = floor((4+20-1)/3)+1 = 8 → 8-2+1 = 7
        expect(category(innings_pitched: 6.2, prior_outs: 4, game_result: "lose", fatigue_p: 5, pitchers_in_game: 2)).to eq("long_loss")
      end

      it "同じ 6.2回でも関与7は疲労P6（閾値7）なら normal（境界: 7 > 7 は偽）" do
        expect(category(innings_pitched: 6.2, prior_outs: 4, game_result: "lose", fatigue_p: 6, pitchers_in_game: 2)).to eq("normal")
      end

      it "prior_outs=0 の通常の先発は従来と同じ（6.2回 → 関与7）" do
        expect(category(innings_pitched: 6.2, prior_outs: 0, game_result: "lose", fatigue_p: 6)).to eq("normal")
        expect(category(innings_pitched: 6.2, prior_outs: 0, game_result: "lose", fatigue_p: 5)).to eq("long_loss")
      end
    end

    # 旧: 「fatigue_p=0 を未設定とみなして既定 3 を当てる」テストがあったが、裁定 3 により廃止した
    # （0 は補正の結果の正当な値。既定 3 はカード未記載の時に PitcherStarterFatigue がカード値として入れる）。
    describe "疲労P の 0 と未特定の区別（Operator 裁定 3）" do
      it "補正の結果 0（fatigue_p: 0）の先発は 閾値 1。2.0回完投敗戦 → long_loss" do
        expect(category(innings_pitched: 2.0, game_result: "lose", fatigue_p: 0)).to eq("long_loss")
      end

      it "fatigue_p: 0 で 1.0回 → normal（関与1 > 1 は偽）" do
        expect(category(innings_pitched: 1.0, game_result: "lose", fatigue_p: 0)).to eq("normal")
      end

      it "fatigue_p が nil（特定できない）で長イニングの可能性がある時は nil（判定保留）。既定 3 を当てない" do
        expect(category(innings_pitched: 5.0, game_result: "lose", fatigue_p: nil)).to be_nil
      end

      it "fatigue_p が nil でも勝ち試合なら normal（疲労P が要らない）" do
        expect(category(innings_pitched: 9.0, game_result: "win", fatigue_p: nil)).to eq("normal")
      end

      it "fatigue_p が nil でも関与1以下なら normal と決まる" do
        expect(category(innings_pitched: 0.2, game_result: "lose", fatigue_p: nil)).to eq("normal")
      end

      it "reliever は fatigue_p: nil でも normal" do
        expect(category(role: "reliever", innings_pitched: 3.0, game_result: "lose", fatigue_p: nil)).to eq("normal")
      end
    end

    context "0アウト降板（no_out_exit）と関与イニング数の境界値（cmd_971）" do
      # P6先発: fp+1 = 7。関与7イニング以下はnormal、8以上はlong_loss
      it "P6先発が7回完了・敗戦・no_out_exit=false → normal（関与7, 7>7はfalse）" do
        expect(category(innings_pitched: 7.0, game_result: "lose", fatigue_p: 6, no_out_exit: false)).to eq("normal")
      end

      it "P6先発が8回登板→先頭打者出塁→0アウト降板・敗戦・no_out_exit=true → long_loss（関与8, 8>7はtrue）" do
        expect(category(innings_pitched: 7.0, game_result: "lose", pitchers_in_game: 2, fatigue_p: 6, no_out_exit: true)).to eq("long_loss")
      end

      it "P6先発が8回1アウトで降板・敗戦・no_out_exit=false → long_loss（関与8, 7.1回）" do
        expect(category(innings_pitched: 7.1, game_result: "lose", pitchers_in_game: 2, fatigue_p: 6, no_out_exit: false)).to eq("long_loss")
      end

      # 補正後疲労P（中日数等による実効P）での判定
      it "補正後P5（素P6・中5日→実効P5）で7回完了・敗戦 → long_loss（関与7, 7>6はtrue）" do
        expect(category(innings_pitched: 7.0, game_result: "lose", fatigue_p: 5, no_out_exit: false)).to eq("long_loss")
      end

      it "補正後P5で6回完了・敗戦 → normal（関与6, 6>6はfalse）" do
        expect(category(innings_pitched: 6.0, game_result: "lose", fatigue_p: 5, no_out_exit: false)).to eq("normal")
      end
    end
  end

  describe "バリデーション: injury_check" do
    %w[safe injured].each do |valid_check|
      it "#{valid_check} は有効" do
        pgs = build(:pitcher_game_state, injury_check: valid_check)
        expect(pgs).to be_valid
      end
    end

    it "nil は有効（allow_nil）" do
      pgs = build(:pitcher_game_state, injury_check: nil)
      expect(pgs).to be_valid
    end

    it "invalid はエラー" do
      pgs = build(:pitcher_game_state, injury_check: "invalid")
      expect(pgs).not_to be_valid
      expect(pgs.errors[:injury_check]).to be_present
    end
  end
end
