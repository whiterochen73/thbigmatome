require 'rails_helper'

RSpec.describe Player, type: :model do
  describe 'アソシエーション' do
    it { is_expected.to have_many(:team_memberships).dependent(:destroy) }
    it { is_expected.to have_many(:teams).through(:team_memberships) }
    it { is_expected.to have_many(:cost_players).dependent(:destroy) }
  end

  describe '#hachinai_two_way?' do
    let(:hachinai_card_set) { create(:card_set, set_type: "hachinai61", series: "hachinai") }

    context 'ハチナイ背番号39以下の選手（片方カードのみ）' do
      let(:player) { create(:player, number: "25") }
      before { create(:player_card, player: player, card_set: hachinai_card_set, card_type: "pitcher", is_pitcher: true) }

      it { expect(player.hachinai_two_way?).to be true }
    end

    context 'ハチナイ背番号39の選手（野手カードのみ）' do
      let(:player) { create(:player, number: "39") }
      before { create(:player_card, player: player, card_set: hachinai_card_set, card_type: "batter", is_pitcher: false) }

      it { expect(player.hachinai_two_way?).to be true }
    end

    context 'ハチナイ背番号40以上で片方カードのみの選手' do
      let(:player) { create(:player, number: "40") }
      before { create(:player_card, player: player, card_set: hachinai_card_set, card_type: "pitcher", is_pitcher: true) }

      it { expect(player.hachinai_two_way?).to be false }
    end

    context 'ハチナイ背番号40以上で両方カード持ちの選手' do
      let(:player) { create(:player, number: "40") }
      before do
        create(:player_card, player: player, card_set: hachinai_card_set, card_type: "pitcher", is_pitcher: true)
        create(:player_card, player: player, card_set: hachinai_card_set, card_type: "batter", is_pitcher: false)
      end

      it { expect(player.hachinai_two_way?).to be true }
    end

    context 'ハチナイ以外のカードのみの選手' do
      let(:player) { create(:player, number: "25") }
      let(:touhou_card_set) { create(:card_set, set_type: "annual", series: "touhou") }
      before { create(:player_card, player: player, card_set: touhou_card_set, card_type: "pitcher", is_pitcher: true) }

      it { expect(player.hachinai_two_way?).to be false }
    end
  end

  describe '#available_cost_types' do
    let(:hachinai_card_set) { create(:card_set, set_type: "hachinai61", series: "hachinai") }

    context 'ハチナイ背番号39以下の選手（片方カードのみ）' do
      let(:player) { create(:player, number: "25") }
      before { create(:player_card, player: player, card_set: hachinai_card_set, card_type: "pitcher", is_pitcher: true, relief_stamina: 2) }

      it 'normal_costを含まない' do
        expect(player.available_cost_types).not_to include("normal_cost")
      end

      it 'two_way_costを含む' do
        expect(player.available_cost_types).to include("two_way_cost")
      end

      it 'pitcher_only_costとfielder_only_costを含む' do
        expect(player.available_cost_types).to include("pitcher_only_cost", "fielder_only_cost")
      end
    end
  end

  describe 'PM2026 の分離 player rescue' do
    let(:hachinai_card_set) { create(:card_set, set_type: "hachinai61", series: "hachinai", name: "ハチナイ6.1") }
    let(:pm_card_set) { create(:card_set, set_type: "pm2026", series: "original", name: "PM2026") }
    let!(:base_player) { create(:player, name: "リン・レイファ", short_name: "リン", number: "F34", series: "hachinai") }
    let!(:ur_player) { create(:player, name: "リン・レイファ (UR)", number: "38", series: "original") }

    before do
      create(:player_card, player: base_player, card_set: hachinai_card_set, card_type: "batter", is_pitcher: false)
      create(:player_card, player: ur_player, card_set: pm_card_set, card_type: "batter", is_pitcher: false)
    end

    it 'PM2026 側でも canonical なハチナイ選手を参照して二刀流扱いにできる' do
      expect(ur_player.hachinai_two_way?).to be true
      expect(ur_player.available_cost_types).to include("two_way_cost", "pitcher_only_cost", "fielder_only_cost")
      expect(ur_player.available_cost_types).not_to include("normal_cost")
    end
  end

  describe 'PM（オリジナル）の版違いのカードセット（PM2027）' do
    let(:hachinai_card_set) { create(:card_set, set_type: "hachinai61", series: "hachinai", name: "ハチナイ6.1") }
    let(:pm2027_card_set) { create(:card_set, year: 2027, set_type: "pm2027", name: "PM2027") }
    let!(:base_player) { create(:player, name: "リン・レイファ", short_name: "リン", number: "F34", series: "hachinai") }
    let!(:ur_player) { create(:player, name: "リン・レイファ (UR)", number: "38", series: "original") }

    before do
      create(:player_card, player: base_player, card_set: hachinai_card_set, card_type: "batter", is_pitcher: false)
      create(:player_card, player: ur_player, card_set: pm2027_card_set, card_type: "batter", is_pitcher: false)
    end

    it 'PM2027 だけを持つ選手でも、canonical なハチナイ選手を参照して二刀流扱いにできる（set_type の文字列でなく series で見る）' do
      expect(pm2027_card_set.series).to eq("original")
      expect(ur_player.hachinai_two_way?).to be true
      expect(ur_player.available_cost_types).to include("two_way_cost", "pitcher_only_cost", "fielder_only_cost")
    end

    it 'PM2028 のような次の版でも、コードの変更なしに同じ判定になる' do
      pm2028 = create(:card_set, year: 2028, set_type: "pm2028", name: "PM2028")
      expect(pm2028.series).to eq("original")
      player = create(:player, name: "リン・レイファ (2028)", number: "38", series: "original")
      create(:player_card, player: player, card_set: pm2028, card_type: "batter", is_pitcher: false)
      expect(player.send(:has_original_series_card?)).to be true
    end

    it 'series が original でないカードしか持たない選手では偽' do
      annual = create(:card_set, set_type: "annual")
      player = create(:player, name: "リン・レイファ (東方)", number: "1", series: "touhou")
      create(:player_card, player: player, card_set: annual, card_type: "batter", is_pitcher: false)
      expect(player.send(:has_original_series_card?)).to be false
    end
  end

  describe 'PM（オリジナル）の版違いで、投手カードと野手カードに分かれる選手（二刀流ではない）' do
    # Operator 裁定（2026-11-14）: 「PM は全く別のカードに変更されることがある」。PM2026 は野手・PM2027 は投手の 你 藍翠 は二刀流ではない
    let(:pm2026) { create(:card_set, year: 2026, set_type: "pm2026", name: "PM2026") }
    let(:pm2027) { create(:card_set, year: 2027, set_type: "pm2027", name: "PM2027") }
    let(:annual) { create(:card_set, year: 2025, set_type: "annual", name: "2025THBIG") }

    it 'PM2026 の野手カードと PM2027 の投手カードを持っても、二刀流のコスト種別を出さない' do
      player = create(:player, name: "你 藍翠", number: "088", series: "original")
      create(:player_card, player: player, card_set: pm2026, card_type: "batter", is_pitcher: false)
      pitcher = create(:player_card, player: player, card_set: pm2027, card_type: "pitcher", is_pitcher: true)
      player = Player.find(player.id)
      expect(player.available_cost_types).to eq([ "normal_cost" ])
      expect(player.available_cost_types_for_card(pitcher)).to eq([ "normal_cost" ])
    end

    it '逆（PM2026 が投手・PM2027 が野手）でも同じ' do
      player = create(:player, name: "版違い", number: "1", series: "original")
      create(:player_card, player: player, card_set: pm2026, card_type: "pitcher", is_pitcher: true)
      create(:player_card, player: player, card_set: pm2027, card_type: "batter", is_pitcher: false)
      expect(Player.find(player.id).available_cost_types).not_to include("two_way_cost")
    end

    it '同じ版（同じカードセット）の中に投手と野手の両方があれば、従来どおり二刀流' do
      player = create(:player, name: "同じ版", number: "2", series: "original")
      create(:player_card, player: player, card_set: pm2027, card_type: "pitcher", is_pitcher: true, variant: "a")
      create(:player_card, player: player, card_set: pm2027, card_type: "batter", is_pitcher: false, variant: "b")
      expect(Player.find(player.id).available_cost_types).to include("two_way_cost", "pitcher_only_cost", "fielder_only_cost")
    end

    it 'PM 以外のセット（2025THBIG）の投手カードと PM の野手カードは、従来どおり二刀流（東風谷 早苗・天弓 千亦 と同じ）' do
      player = create(:player, name: "他系列", number: "3", series: "touhou")
      create(:player_card, player: player, card_set: annual, card_type: "pitcher", is_pitcher: true)
      create(:player_card, player: player, card_set: pm2026, card_type: "batter", is_pitcher: false, variant: "エイプリル")
      create(:player_card, player: player, card_set: pm2027, card_type: "batter", is_pitcher: false, variant: "エイプリル")
      expect(Player.find(player.id).available_cost_types).to include("two_way_cost")
    end

    it '冴月 麟 は投手と野手が別の Player（名前に（投手）（野手））で、二刀流ではない' do
      batter = create(:player, name: "冴月 麟 (野手)", number: "000", series: "original")
      pitcher = create(:player, name: "冴月 麟 (投手)", number: "000", series: "original")
      create(:player_card, player: batter, card_set: pm2026, card_type: "batter", is_pitcher: false, variant: "野手")
      create(:player_card, player: pitcher, card_set: pm2026, card_type: "pitcher", is_pitcher: true, variant: "投手")
      expect(Player.find(batter.id).available_cost_types).to eq([ "normal_cost" ])
      expect(Player.find(pitcher.id).available_cost_types).to eq([ "normal_cost" ])
    end
  end
end
