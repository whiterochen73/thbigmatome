require 'rails_helper'

RSpec.describe PlayerAbsence, type: :model do
  describe 'アソシエーション' do
    it { is_expected.to belong_to(:team_membership) }
    it { is_expected.to belong_to(:season) }
  end

  describe 'バリデーション' do
    describe 'absence_type' do
      it { is_expected.to validate_presence_of(:absence_type) }
      it { is_expected.to define_enum_for(:absence_type).with_values(injury: 0, suspension: 1, reconditioning: 2) }
    end

    describe 'start_date' do
      it { is_expected.to validate_presence_of(:start_date) }
    end

    describe 'duration' do
      it { is_expected.to validate_presence_of(:duration) }
      it { is_expected.to validate_numericality_of(:duration).only_integer }

      it 'duration > 0 のみ有効' do
        absence = build(:player_absence, duration: 0)
        expect(absence).not_to be_valid
        expect(absence.errors[:duration]).to be_present
      end

      it '負の値は無効' do
        absence = build(:player_absence, duration: -1)
        expect(absence).not_to be_valid
      end

      it '正の整数は有効' do
        absence = build(:player_absence, duration: 1)
        expect(absence).to be_valid
      end
    end

    describe 'duration_unit' do
      it { is_expected.to validate_presence_of(:duration_unit) }

      it 'days は有効' do
        absence = build(:player_absence, duration_unit: "days")
        expect(absence).to be_valid
      end

      it 'games は有効' do
        absence = build(:player_absence, duration_unit: "games")
        expect(absence).to be_valid
      end

      it 'その他の値は無効' do
        absence = build(:player_absence, duration_unit: "weeks")
        expect(absence).not_to be_valid
      end
    end
  end

  describe 'phase（試合前 / 試合中。AMB-25）' do
    it '未指定なら pre_game（既存の離脱と同じ振る舞い）' do
      expect(PlayerAbsence.new.phase).to eq('pre_game')
      expect(build(:player_absence)).to be_valid
    end

    it 'pre_game / in_game は有効' do
      %w[pre_game in_game].each do |phase|
        expect(build(:player_absence, phase: phase)).to be_valid
      end
    end

    it '不正な値・空・nil は無効' do
      [ 'during', 'PRE_GAME', '', nil ].each do |phase|
        absence = build(:player_absence, phase: phase)
        expect(absence).not_to be_valid
        expect(absence.errors[:phase]).to be_present
      end
    end

    it 'DB の既定値は pre_game で null 不可' do
      column = PlayerAbsence.columns_hash['phase']
      expect(column.default).to eq('pre_game')
      expect(column.null).to be false
    end
  end

  describe '#effective_start_date' do
    it 'pre_game は start_date そのまま' do
      absence = build(:player_absence, start_date: Date.new(2026, 4, 1), phase: 'pre_game')
      expect(absence.effective_start_date).to eq(Date.new(2026, 4, 1))
    end

    it 'in_game は start_date の翌日（月末をまたぐ）' do
      absence = build(:player_absence, start_date: Date.new(2026, 4, 30), phase: 'in_game')
      expect(absence.effective_start_date).to eq(Date.new(2026, 5, 1))
    end
  end

  describe 'days: 試合前と試合中の数え始め（AMB-25）' do
    let(:d) { Date.new(2026, 4, 10) }

    def absence(phase:, n:)
      build(:player_absence, start_date: d, duration: n, duration_unit: 'days', phase: phase)
    end

    it '試合前 N=1: D は離脱中、D+1 に復帰' do
      a = absence(phase: 'pre_game', n: 1)
      expect(a.effective_end_date).to eq(d + 1)
      expect(a.active_on?(d - 1)).to be false
      expect(a.active_on?(d)).to be true
      expect(a.active_on?(d + 1)).to be false
    end

    it '試合中 N=1: D は離脱中でなく、D+1 に離脱中、D+2 に復帰' do
      a = absence(phase: 'in_game', n: 1)
      expect(a.effective_end_date).to eq(d + 2)
      expect(a.active_on?(d)).to be false
      expect(a.active_on?(d + 1)).to be true
      expect(a.active_on?(d + 2)).to be false
    end

    it '試合前 N=3 は D〜D+2 が離脱で D+3 に復帰、試合中 N=3 は D+1〜D+3 が離脱で D+4 に復帰' do
      pre = absence(phase: 'pre_game', n: 3)
      expect((d..d + 4).select { |x| pre.active_on?(x) }).to eq([ d, d + 1, d + 2 ])
      expect(pre.effective_end_date).to eq(d + 3)

      mid = absence(phase: 'in_game', n: 3)
      expect((d..d + 5).select { |x| mid.active_on?(x) }).to eq([ d + 1, d + 2, d + 3 ])
      expect(mid.effective_end_date).to eq(d + 4)
    end

    it 'active_on? は DateTime / Time でも日付で判定する' do
      a = absence(phase: 'in_game', n: 1)
      expect(a.active_on?(Time.zone.local(2026, 4, 11, 23, 59))).to be true
      expect(a.active_on?(Time.zone.local(2026, 4, 10, 23, 59))).to be false
    end

    it '残り日数: 試合前は D に N、試合中は D でも D+1 でも N（試合に出た日は離脱に数えない）' do
      pre = absence(phase: 'pre_game', n: 3)
      expect(pre.remaining_days_on(d)).to eq(3)
      expect(pre.remaining_days_on(d + 1)).to eq(2)
      expect(pre.remaining_days_on(d + 2)).to eq(1)

      mid = absence(phase: 'in_game', n: 3)
      expect(mid.remaining_days_on(d)).to eq(3)
      expect(mid.remaining_days_on(d + 1)).to eq(3)
      expect(mid.remaining_days_on(d + 2)).to eq(2)
      expect(mid.remaining_days_on(d + 3)).to eq(1)
    end

    it '残り日数: 開始前の試合前離脱は従来どおり復帰日までの日数のまま（区分追加前から変えない）' do
      pre = absence(phase: 'pre_game', n: 3)
      expect(pre.remaining_days_on(d - 2)).to eq(5)
    end
  end

  describe 'games: 試合数の単位でも同じ区分で数える（AMB-25）' do
    let(:team) { create(:team) }
    let(:season) { create(:season, team: team) }
    let(:membership) { create(:team_membership, team: team, player: create(:player)) }
    # 4/1(試合) 4/2(移動日) 4/3(試合) 4/4(試合) 4/5(試合)
    let(:d) { Date.new(2026, 4, 1) }

    before do
      [ [ 1, 'game_day' ], [ 2, 'off_day' ], [ 3, 'game_day' ], [ 4, 'interleague_game_day' ], [ 5, 'game_day' ] ].each do |day, type|
        create(:season_schedule, season: season, date: Date.new(2026, 4, day), date_type: type)
      end
    end

    def absence(phase:, n:)
      build(:player_absence, team_membership: membership, season: season,
            start_date: d, duration: n, duration_unit: 'games', phase: phase)
    end

    it '試合前 N=1: D の試合を数える。D に離脱中、D+1 に復帰' do
      a = absence(phase: 'pre_game', n: 1)
      expect(a.effective_end_date).to eq(Date.new(2026, 4, 2))
      expect(a.active_on?(d)).to be true
      expect(a.active_on?(Date.new(2026, 4, 2))).to be false
    end

    it '試合中 N=1: D の試合は数えない。翌日が移動日でも次の試合日（4/3）まで数え、4/4 に復帰' do
      a = absence(phase: 'in_game', n: 1)
      expect(a.effective_start_date).to eq(Date.new(2026, 4, 2))
      expect(a.effective_end_date).to eq(Date.new(2026, 4, 4))
      expect(a.active_on?(d)).to be false
      expect(a.active_on?(Date.new(2026, 4, 2))).to be true # 移動日も離脱中
      expect(a.active_on?(Date.new(2026, 4, 3))).to be true
      expect(a.active_on?(Date.new(2026, 4, 4))).to be false
    end

    it '試合中 N=2: D より後の試合日 2 個（4/3, 4/4）→ 4/5 に復帰' do
      expect(absence(phase: 'in_game', n: 2).effective_end_date).to eq(Date.new(2026, 4, 5))
      expect(absence(phase: 'pre_game', n: 2).effective_end_date).to eq(Date.new(2026, 4, 4))
    end

    it '離脱中の日の並び（D・D+N−1 相当・復帰日・復帰翌日）を試合前 / 試合中で比べる（N=2 試合）' do
      days = (Date.new(2026, 3, 31)..Date.new(2026, 4, 6)).to_a
      active = ->(a) { days.select { |x| a.active_on?(x) }.map(&:day) }

      # 試合前: 4/1(試合) 4/2(移動日) 4/3(試合) → 4/1〜4/3 が離脱、4/4 に復帰
      expect(active.call(absence(phase: 'pre_game', n: 2))).to eq([ 1, 2, 3 ])
      # 試合中: 4/1 は出場。4/3(試合) 4/4(試合) を数える → 4/2〜4/4 が離脱、4/5 に復帰
      expect(active.call(absence(phase: 'in_game', n: 2))).to eq([ 2, 3, 4 ])
    end

    it '試合中は D より後の試合日が足りなければ復帰日未定（nil）で離脱が続く' do
      a = absence(phase: 'in_game', n: 4) # D より後は 3 試合しかない
      expect(a.effective_end_date).to be_nil
      expect(a.active_on?(Date.new(2026, 4, 30))).to be true
      expect(absence(phase: 'pre_game', n: 4).effective_end_date).to eq(Date.new(2026, 4, 6))
    end

    it '残り日数は復帰日までの日数。試合中は D から見ても翌日起点' do
      a = absence(phase: 'in_game', n: 1)
      expect(a.remaining_days_on(d)).to eq(2) # 4/2 〜 4/3 の 2 日（移動日 + 試合日）
    end
  end

  describe '#effective_end_date' do
    context 'daysベース（duration_unit: days）' do
      it 'start_date + duration日 を返す' do
        absence = build(:player_absence, start_date: Date.new(2026, 4, 1), duration: 5, duration_unit: "days")
        expect(absence.effective_end_date).to eq(Date.new(2026, 4, 6))
      end

      it 'duration=1 の場合、翌日を返す' do
        absence = build(:player_absence, start_date: Date.new(2026, 4, 1), duration: 1, duration_unit: "days")
        expect(absence.effective_end_date).to eq(Date.new(2026, 4, 2))
      end

      it '月をまたぐケース' do
        absence = build(:player_absence, start_date: Date.new(2026, 4, 28), duration: 5, duration_unit: "days")
        expect(absence.effective_end_date).to eq(Date.new(2026, 5, 3))
      end

      it '年をまたぐケース' do
        absence = build(:player_absence, start_date: Date.new(2026, 12, 29), duration: 5, duration_unit: "days")
        expect(absence.effective_end_date).to eq(Date.new(2027, 1, 3))
      end

      it '大きなduration値' do
        absence = build(:player_absence, start_date: Date.new(2026, 4, 1), duration: 30, duration_unit: "days")
        expect(absence.effective_end_date).to eq(Date.new(2026, 5, 1))
      end
    end

    context 'gamesベース（duration_unit: games）' do
      let(:team) { create(:team) }
      let(:player) { create(:player) }
      let(:team_membership) { create(:team_membership, team: team, player: player) }
      let(:season) { create(:season, team: team) }

      it '離脱開始日以降のN試合目の翌日を返す' do
        # 4/1, 4/3, 4/5, 4/7, 4/9 にゲームを配置
        [ 1, 3, 5, 7, 9 ].each do |day|
          create(:season_schedule, season: season, date: Date.new(2026, 4, day), date_type: "game_day")
        end

        absence = build(:player_absence,
          team_membership: team_membership,
          season: season,
          start_date: Date.new(2026, 4, 1),
          duration: 3,
          duration_unit: "games"
        )

        # 4/1, 4/3, 4/5 の3試合 → 4/5の翌日 = 4/6
        expect(absence.effective_end_date).to eq(Date.new(2026, 4, 6))
      end

      it 'game_dayとinterleague_game_dayの両方をカウントする' do
        create(:season_schedule, season: season, date: Date.new(2026, 4, 1), date_type: "game_day")
        create(:season_schedule, season: season, date: Date.new(2026, 4, 3), date_type: "interleague_game_day")
        create(:season_schedule, season: season, date: Date.new(2026, 4, 5), date_type: "game_day")

        absence = build(:player_absence,
          team_membership: team_membership,
          season: season,
          start_date: Date.new(2026, 4, 1),
          duration: 3,
          duration_unit: "games"
        )

        expect(absence.effective_end_date).to eq(Date.new(2026, 4, 6))
      end

      it 'off_day, event_day はカウントしない' do
        create(:season_schedule, season: season, date: Date.new(2026, 4, 1), date_type: "game_day")
        create(:season_schedule, season: season, date: Date.new(2026, 4, 2), date_type: "off_day")
        create(:season_schedule, season: season, date: Date.new(2026, 4, 3), date_type: "event_day")
        create(:season_schedule, season: season, date: Date.new(2026, 4, 4), date_type: "game_day")
        create(:season_schedule, season: season, date: Date.new(2026, 4, 5), date_type: "game_day")

        absence = build(:player_absence,
          team_membership: team_membership,
          season: season,
          start_date: Date.new(2026, 4, 1),
          duration: 3,
          duration_unit: "games"
        )

        # game_day: 4/1, 4/4, 4/5 → 4/5の翌日 = 4/6
        expect(absence.effective_end_date).to eq(Date.new(2026, 4, 6))
      end

      it '離脱開始日より前のゲームはカウントしない' do
        create(:season_schedule, season: season, date: Date.new(2026, 3, 28), date_type: "game_day")
        create(:season_schedule, season: season, date: Date.new(2026, 3, 30), date_type: "game_day")
        create(:season_schedule, season: season, date: Date.new(2026, 4, 1), date_type: "game_day")
        create(:season_schedule, season: season, date: Date.new(2026, 4, 3), date_type: "game_day")

        absence = build(:player_absence,
          team_membership: team_membership,
          season: season,
          start_date: Date.new(2026, 4, 1),
          duration: 2,
          duration_unit: "games"
        )

        # 4/1, 4/3 の2試合 → 4/3の翌日 = 4/4
        expect(absence.effective_end_date).to eq(Date.new(2026, 4, 4))
      end

      it 'スケジュール不足（game_dates < duration）の場合はnilを返す' do
        create(:season_schedule, season: season, date: Date.new(2026, 4, 1), date_type: "game_day")
        create(:season_schedule, season: season, date: Date.new(2026, 4, 3), date_type: "game_day")

        absence = build(:player_absence,
          team_membership: team_membership,
          season: season,
          start_date: Date.new(2026, 4, 1),
          duration: 5,
          duration_unit: "games"
        )

        expect(absence.effective_end_date).to be_nil
      end

      it 'スケジュールが全くない場合はnilを返す' do
        absence = build(:player_absence,
          team_membership: team_membership,
          season: season,
          start_date: Date.new(2026, 4, 1),
          duration: 3,
          duration_unit: "games"
        )

        expect(absence.effective_end_date).to be_nil
      end

      it 'duration=1（1試合離脱）の境界値' do
        create(:season_schedule, season: season, date: Date.new(2026, 4, 5), date_type: "game_day")

        absence = build(:player_absence,
          team_membership: team_membership,
          season: season,
          start_date: Date.new(2026, 4, 5),
          duration: 1,
          duration_unit: "games"
        )

        expect(absence.effective_end_date).to eq(Date.new(2026, 4, 6))
      end

      it '離脱開始日当日が試合日の場合、その試合もカウントに含む' do
        create(:season_schedule, season: season, date: Date.new(2026, 4, 1), date_type: "game_day")
        create(:season_schedule, season: season, date: Date.new(2026, 4, 2), date_type: "game_day")

        absence = build(:player_absence,
          team_membership: team_membership,
          season: season,
          start_date: Date.new(2026, 4, 1),
          duration: 2,
          duration_unit: "games"
        )

        # where("date >= ?", start_date) なので4/1もカウント
        expect(absence.effective_end_date).to eq(Date.new(2026, 4, 3))
      end
    end
  end
end
