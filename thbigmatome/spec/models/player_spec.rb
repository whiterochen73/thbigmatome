require 'rails_helper'

RSpec.describe Player, type: :model do
  describe 'アソシエーション' do
    it { is_expected.to have_many(:team_memberships).dependent(:destroy) }
    it { is_expected.to have_many(:teams).through(:team_memberships) }
    it { is_expected.to have_many(:cost_players).dependent(:destroy) }
  end

  describe 'バリデーション' do
    context '走力・バント・盗塁値' do
      describe 'speed' do
        it { is_expected.to validate_presence_of(:speed) }

        it '有効範囲（1..5）' do
          (1..5).each do |val|
            player = build(:player, speed: val)
            player.valid?
            expect(player.errors[:speed]).to be_empty, "speed=#{val} should be valid"
          end
        end

        it '範囲外（0）はエラー' do
          player = build(:player, speed: 0)
          expect(player).not_to be_valid
        end

        it '範囲外（6）はエラー' do
          player = build(:player, speed: 6)
          expect(player).not_to be_valid
        end
      end

      describe 'bunt' do
        it { is_expected.to validate_presence_of(:bunt) }

        it '有効範囲（1..10）' do
          [ 1, 5, 10 ].each do |val|
            player = build(:player, bunt: val)
            player.valid?
            expect(player.errors[:bunt]).to be_empty, "bunt=#{val} should be valid"
          end
        end

        it '範囲外（0）はエラー' do
          player = build(:player, bunt: 0)
          expect(player).not_to be_valid
        end

        it '範囲外（11）はエラー' do
          player = build(:player, bunt: 11)
          expect(player).not_to be_valid
        end
      end

      describe 'steal_start' do
        it { is_expected.to validate_presence_of(:steal_start) }

        it '有効範囲（1..22）' do
          [ 1, 11, 22 ].each do |val|
            player = build(:player, steal_start: val)
            player.valid?
            expect(player.errors[:steal_start]).to be_empty, "steal_start=#{val} should be valid"
          end
        end

        it '範囲外（0）はエラー' do
          player = build(:player, steal_start: 0)
          expect(player).not_to be_valid
        end

        it '範囲外（23）はエラー' do
          player = build(:player, steal_start: 23)
          expect(player).not_to be_valid
        end
      end

      describe 'steal_end' do
        it { is_expected.to validate_presence_of(:steal_end) }

        it '有効範囲（1..22）' do
          [ 1, 11, 22 ].each do |val|
            player = build(:player, steal_end: val)
            player.valid?
            expect(player.errors[:steal_end]).to be_empty, "steal_end=#{val} should be valid"
          end
        end

        it '範囲外（0）はエラー' do
          player = build(:player, steal_end: 0)
          expect(player).not_to be_valid
        end

        it '範囲外（23）はエラー' do
          player = build(:player, steal_end: 23)
          expect(player).not_to be_valid
        end
      end
    end

    context '怪我特徴（injury_rate）' do
      it { is_expected.to validate_presence_of(:injury_rate) }

      it '有効範囲（0..7）' do
        (0..7).each do |val|
          player = build(:player, injury_rate: val)
          player.valid?
          expect(player.errors[:injury_rate]).to be_empty, "injury_rate=#{val} should be valid"
        end
      end

      it '範囲外（8）はエラー' do
        player = build(:player, injury_rate: 8)
        expect(player).not_to be_valid
      end

      it '範囲外（-1）はエラー' do
        player = build(:player, injury_rate: -1)
        expect(player).not_to be_valid
      end
    end
  end
end
