require 'rails_helper'

RSpec.describe CostValidator, type: :service do
  let(:cost) { create(:cost) }
  let(:competition) { create(:competition) }
  let(:team) { create(:team) }
  let(:entry) { create(:competition_entry, competition: competition, team: team) }

  def create_player_card_with_cost(normal_cost: 5, is_pitcher: false, is_relief_only: false)
    player = create(:player)
    create(:cost_player, cost: cost, player: player, normal_cost: normal_cost)
    create(:player_card, player: player, is_pitcher: is_pitcher, is_relief_only: is_relief_only)
  end

  def add_to_roster(player_card, squad: :first_squad, count: 1)
    count.times do
      pc = player_card || create_player_card_with_cost
      create(:competition_roster, competition_entry: entry, player_card: pc, squad: squad)
    end
  end

  describe '#validate' do
    context '1軍が24人以下の場合' do
      before do
        24.times do
          pc = create_player_card_with_cost(normal_cost: 4)
          create(:competition_roster, competition_entry: entry, player_card: pc, squad: :first_squad)
        end
      end

      it 'valid: false でエラーを返す' do
        result = described_class.new(entry.id).validate
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(a_string_matching(/1軍人数/))
      end

      it 'first_squad_count は 24 を返す' do
        result = described_class.new(entry.id).validate
        expect(result[:first_squad_count]).to eq(24)
      end
    end

    context '1軍が25人でコスト以内の場合' do
      before do
        # 25人 × normal_cost=4 → 合計100 (上限114以内)
        25.times do
          pc = create_player_card_with_cost(normal_cost: 4)
          create(:competition_roster, competition_entry: entry, player_card: pc, squad: :first_squad)
        end
      end

      it 'valid: true を返す' do
        result = described_class.new(entry.id).validate
        expect(result[:valid]).to be true
        expect(result[:errors]).to be_empty
      end

      it '正しい upper limit を返す（25人=114）' do
        result = described_class.new(entry.id).validate
        expect(result[:first_squad_limit]).to eq(114)
      end
    end

    context '1軍が26人でコスト以内の場合' do
      before do
        26.times do
          pc = create_player_card_with_cost(normal_cost: 4)
          create(:competition_roster, competition_entry: entry, player_card: pc, squad: :first_squad)
        end
      end

      it 'first_squad_limit は 117' do
        result = described_class.new(entry.id).validate
        expect(result[:first_squad_limit]).to eq(117)
      end
    end

    context '1軍が27人でコスト以内の場合' do
      before do
        27.times do
          pc = create_player_card_with_cost(normal_cost: 4)
          create(:competition_roster, competition_entry: entry, player_card: pc, squad: :first_squad)
        end
      end

      it 'first_squad_limit は 119' do
        result = described_class.new(entry.id).validate
        expect(result[:first_squad_limit]).to eq(119)
      end
    end

    context '1軍が28人以上でコスト以内の場合' do
      before do
        28.times do
          pc = create_player_card_with_cost(normal_cost: 4)
          create(:competition_roster, competition_entry: entry, player_card: pc, squad: :first_squad)
        end
      end

      it 'first_squad_limit は 120' do
        result = described_class.new(entry.id).validate
        expect(result[:first_squad_limit]).to eq(120)
      end
    end

    context '1軍コストが超過する場合' do
      before do
        # 25人 × normal_cost=5 = 125 > 上限114
        25.times do
          pc = create_player_card_with_cost(normal_cost: 5)
          create(:competition_roster, competition_entry: entry, player_card: pc, squad: :first_squad)
        end
      end

      it 'valid: false でコストエラーを返す' do
        result = described_class.new(entry.id).validate
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(a_string_matching(/1軍コスト/))
      end
    end

    context 'チーム全体コストが超過する場合' do
      before do
        # 1軍25人 × 4 = 100, 2軍25人 × 5 = 125, 合計225 > 200
        25.times do
          pc = create_player_card_with_cost(normal_cost: 4)
          create(:competition_roster, competition_entry: entry, player_card: pc, squad: :first_squad)
        end
        25.times do
          pc = create_player_card_with_cost(normal_cost: 5)
          create(:competition_roster, competition_entry: entry, player_card: pc, squad: :second_squad)
        end
      end

      it 'valid: false でチーム全体コストエラーを返す' do
        result = described_class.new(entry.id).validate
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(a_string_matching(/チーム全体コスト/))
      end

      it 'total_limit は 200 を返す' do
        result = described_class.new(entry.id).validate
        expect(result[:total_limit]).to eq(200)
      end
    end
  end
end
