require 'rails_helper'

RSpec.describe Player, type: :model do
  describe 'アソシエーション' do
    it { is_expected.to have_many(:team_memberships).dependent(:destroy) }
    it { is_expected.to have_many(:teams).through(:team_memberships) }
    it { is_expected.to belong_to(:batting_style).optional }
    it { is_expected.to have_many(:player_batting_skills).dependent(:destroy) }
    it { is_expected.to have_many(:batting_skills).through(:player_batting_skills) }
    it { is_expected.to belong_to(:pitching_style).optional }
    it { is_expected.to belong_to(:pinch_pitching_style).optional }
    it { is_expected.to have_many(:player_pitching_skills).dependent(:destroy) }
    it { is_expected.to have_many(:pitching_skills).through(:player_pitching_skills) }
    it { is_expected.to have_many(:player_player_types).dependent(:destroy) }
    it { is_expected.to have_many(:player_types).through(:player_player_types) }
    it { is_expected.to have_many(:player_biorhythms).dependent(:destroy) }
    it { is_expected.to have_many(:biorhythms).through(:player_biorhythms) }
    it { is_expected.to have_many(:cost_players).dependent(:destroy) }
    it { is_expected.to have_many(:catchers_players).dependent(:destroy) }
    it { is_expected.to have_many(:catchers).through(:catchers_players) }
    it { is_expected.to belong_to(:catcher_pitching_style).optional }
  end

  describe 'enum' do
    it { is_expected.to define_enum_for(:position).backed_by_column_of_type(:string).with_values(pitcher: "pitcher", catcher: "catcher", infielder: "infielder", outfielder: "outfielder") }
    it { is_expected.to define_enum_for(:throwing_hand).backed_by_column_of_type(:string).with_values(right_throw: "right_throw", left_throw: "left_throw") }
    it { is_expected.to define_enum_for(:batting_hand).backed_by_column_of_type(:string).with_values(right_bat: "right_bat", left_bat: "left_bat", switch_hitter: "switch_hitter") }
  end

  describe 'バリデーション' do
    context '守備力（DEFENSE_RATING_FORMAT）' do
      let(:defense_attributes) do
        %i[defense_p defense_c defense_1b defense_2b defense_3b defense_ss
           defense_of defense_lf defense_cf defense_rf special_defense_c]
      end

      it 'フォーマット適合値（数字0-5 + A-E）は有効' do
        %w[0A 1B 2C 3D 4E 5A].each do |val|
          player = build(:player)
          defense_attributes.each { |attr| player.send("#{attr}=", val) }
          player.valid?
          defense_attributes.each do |attr|
            expect(player.errors[attr]).to be_empty, "#{attr}=#{val} should be valid"
          end
        end
      end

      it 'Sランク（数字 + S）は有効' do
        %w[0S 3S 5S].each do |val|
          player = build(:player)
          defense_attributes.each { |attr| player.send("#{attr}=", val) }
          player.valid?
          defense_attributes.each do |attr|
            expect(player.errors[attr]).to be_empty, "#{attr}=#{val} should be valid"
          end
        end
      end

      it '空白は許容（allow_blank）' do
        player = build(:player)
        defense_attributes.each { |attr| player.send("#{attr}=", nil) }
        player.valid?
        defense_attributes.each do |attr|
          expect(player.errors[attr]).to be_empty, "#{attr}=nil should be valid (allow_blank)"
        end
      end

      it '不正フォーマット（数字範囲外）はエラー' do
        %w[6A 7B 9C].each do |val|
          player = build(:player, defense_p: val)
          player.valid?
          expect(player.errors[:defense_p]).to be_present, "defense_p=#{val} should be invalid"
        end
      end

      it '不正フォーマット（文字のみ）はエラー' do
        %w[AA BC SS].each do |val|
          player = build(:player, defense_p: val)
          player.valid?
          expect(player.errors[:defense_p]).to be_present, "defense_p=#{val} should be invalid"
        end
      end

      it '不正フォーマット（3文字以上）はエラー' do
        player = build(:player, defense_p: "3AB")
        player.valid?
        expect(player.errors[:defense_p]).to be_present
      end

      it '不正フォーマット（1文字のみ）はエラー' do
        player = build(:player, defense_p: "3")
        player.valid?
        expect(player.errors[:defense_p]).to be_present
      end

      it '不正フォーマット（小文字）はエラー' do
        player = build(:player, defense_p: "3b")
        player.valid?
        expect(player.errors[:defense_p]).to be_present
      end
    end

    context '外野守備の排他性（DESIGN-004）' do
      it 'defense_of のみ設定は有効' do
        player = build(:player, defense_of: "3B", throwing_of: "B", defense_lf: nil, defense_cf: nil, defense_rf: nil)
        expect(player).to be_valid
      end

      it 'defense_lf + defense_cf + defense_rf のみ設定は有効' do
        player = build(:player,
          defense_of: nil, throwing_of: nil,
          defense_lf: "3B", throwing_lf: "B",
          defense_cf: "4A", throwing_cf: "A",
          defense_rf: "2C", throwing_rf: "C"
        )
        expect(player).to be_valid
      end

      it 'defense_of と defense_lf の同時設定は無効' do
        player = build(:player,
          defense_of: "3B", throwing_of: "B",
          defense_lf: "2C", throwing_lf: "B"
        )
        expect(player).not_to be_valid
        expect(player.errors[:base].any? { |e| e.include?("exclusive") || e.include?("排他") || e.include?("of_and_individual") }).to be true
      end

      it 'defense_of と defense_cf の同時設定は無効' do
        player = build(:player,
          defense_of: "3B", throwing_of: "B",
          defense_cf: "4A", throwing_cf: "A"
        )
        expect(player).not_to be_valid
        expect(player.errors[:base]).to be_present
      end

      it 'defense_of と defense_rf の同時設定は無効' do
        player = build(:player,
          defense_of: "3B", throwing_of: "B",
          defense_rf: "2C", throwing_rf: "B"
        )
        expect(player).not_to be_valid
        expect(player.errors[:base]).to be_present
      end

      it 'どちらも未設定は有効' do
        player = build(:player,
          defense_of: nil, defense_lf: nil, defense_cf: nil, defense_rf: nil
        )
        expect(player).to be_valid
      end
    end

    context '捕手の送球値' do
      it 'defense_c が設定されている場合、throwing_c は必須' do
        player = build(:player, defense_c: "4A", throwing_c: nil)
        expect(player).not_to be_valid
        expect(player.errors[:throwing_c]).to be_present
      end

      it 'defense_c が未設定の場合、throwing_c は不要' do
        player = build(:player, defense_c: nil, throwing_c: nil)
        player.valid?
        expect(player.errors[:throwing_c]).to be_empty
      end

      it 'throwing_c の有効範囲（-5..5）' do
        (-5..5).each do |val|
          player = build(:player, defense_c: "4A", throwing_c: val)
          player.valid?
          expect(player.errors[:throwing_c]).to be_empty, "throwing_c=#{val} should be valid"
        end
      end

      it 'throwing_c が範囲外（-6）はエラー' do
        player = build(:player, defense_c: "4A", throwing_c: -6)
        expect(player).not_to be_valid
        expect(player.errors[:throwing_c]).to be_present
      end

      it 'throwing_c が範囲外（6）はエラー' do
        player = build(:player, defense_c: "4A", throwing_c: 6)
        expect(player).not_to be_valid
        expect(player.errors[:throwing_c]).to be_present
      end
    end

    context '特別捕手守備・送球値' do
      it 'special_defense_c が設定されている場合、special_throwing_c は必須' do
        player = build(:player, special_defense_c: "5S", special_throwing_c: nil)
        expect(player).not_to be_valid
        expect(player.errors[:special_throwing_c]).to be_present
      end

      it 'special_defense_c が未設定の場合、special_throwing_c は不要' do
        player = build(:player, special_defense_c: nil, special_throwing_c: nil)
        player.valid?
        expect(player.errors[:special_throwing_c]).to be_empty
      end

      it 'special_throwing_c の有効範囲（-5..5）' do
        player = build(:player, special_defense_c: "5S", special_throwing_c: 3)
        player.valid?
        expect(player.errors[:special_throwing_c]).to be_empty
      end

      it 'special_throwing_c が範囲外はエラー' do
        player = build(:player, special_defense_c: "5S", special_throwing_c: 6)
        expect(player).not_to be_valid
      end
    end

    context '外野手の送球値' do
      let(:of_throwing_attrs) { %i[throwing_of throwing_lf throwing_cf throwing_rf] }

      it '有効値（S, A, B, C）は通る' do
        %w[S A B C].each do |val|
          player = build(:player, defense_of: "3B", throwing_of: val)
          player.valid?
          expect(player.errors[:throwing_of]).to be_empty, "throwing_of=#{val} should be valid"
        end
      end

      it '無効値（D, E等）はエラー' do
        %w[D E F].each do |val|
          player = build(:player, defense_of: "3B", throwing_of: val)
          player.valid?
          expect(player.errors[:throwing_of]).to be_present, "throwing_of=#{val} should be invalid"
        end
      end

      it '空白は許容（allow_blank）' do
        player = build(:player, defense_of: nil, throwing_of: nil)
        player.valid?
        expect(player.errors[:throwing_of]).to be_empty
      end

      it '外野守備が設定されている場合、対応する送球値は必須' do
        player = build(:player, defense_of: "3B", throwing_of: nil)
        expect(player).not_to be_valid
        expect(player.errors[:throwing_of]).to be_present
      end

      it 'defense_lf がある場合、throwing_lf は必須' do
        player = build(:player, defense_lf: "3B", throwing_lf: nil)
        expect(player).not_to be_valid
        expect(player.errors[:throwing_lf]).to be_present
      end
    end

    context 'スタミナ（疲労P）' do
      context '先発スタミナ' do
        it '有効範囲（4..9）' do
          (4..9).each do |val|
            player = build(:player, :pitcher, starter_stamina: val)
            player.valid?
            expect(player.errors[:starter_stamina]).to be_empty, "starter_stamina=#{val} should be valid"
          end
        end

        it '範囲外（3）はエラー' do
          player = build(:player, :pitcher, starter_stamina: 3)
          expect(player).not_to be_valid
          expect(player.errors[:starter_stamina]).to be_present
        end

        it '範囲外（10）はエラー' do
          player = build(:player, :pitcher, starter_stamina: 10)
          expect(player).not_to be_valid
          expect(player.errors[:starter_stamina]).to be_present
        end

        it 'リリーフ専門（is_relief_only）の場合はバリデーション対象外' do
          player = build(:player, :relief_only, starter_stamina: nil)
          player.valid?
          expect(player.errors[:starter_stamina]).to be_empty
        end

        it '空白は許容' do
          player = build(:player, is_pitcher: false, starter_stamina: nil)
          player.valid?
          expect(player.errors[:starter_stamina]).to be_empty
        end
      end

      context 'リリーフスタミナ' do
        it '有効範囲（0..3）' do
          (0..3).each do |val|
            player = build(:player, :pitcher, relief_stamina: val)
            player.valid?
            expect(player.errors[:relief_stamina]).to be_empty, "relief_stamina=#{val} should be valid"
          end
        end

        it '範囲外（-1）はエラー' do
          player = build(:player, :pitcher, relief_stamina: -1)
          expect(player).not_to be_valid
          expect(player.errors[:relief_stamina]).to be_present
        end

        it '範囲外（4）はエラー' do
          player = build(:player, :pitcher, relief_stamina: 4)
          expect(player).not_to be_valid
          expect(player.errors[:relief_stamina]).to be_present
        end

        it '空白は許容' do
          player = build(:player, relief_stamina: nil)
          player.valid?
          expect(player.errors[:relief_stamina]).to be_empty
        end
      end
    end

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

      it '有効範囲（1..7）' do
        (1..7).each do |val|
          player = build(:player, injury_rate: val)
          player.valid?
          expect(player.errors[:injury_rate]).to be_empty, "injury_rate=#{val} should be valid"
        end
      end

      it '範囲外（0）はエラー' do
        player = build(:player, injury_rate: 0)
        expect(player).not_to be_valid
      end

      it '範囲外（8）はエラー' do
        player = build(:player, injury_rate: 8)
        expect(player).not_to be_valid
      end
    end
  end
end
