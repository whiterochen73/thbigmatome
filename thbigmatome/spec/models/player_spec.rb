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
end
