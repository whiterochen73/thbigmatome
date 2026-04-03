require 'rails_helper'

RSpec.describe AtBatRecordBuilder, type: :service do
  describe '.build_source_events' do
    subject { described_class.build_source_events(params) }

    context 'eventsフィールド（宣言）がある場合' do
      let(:params) do
        {
          events: [
            { type: "pitcher_change", speaker: "monitor", text: "投手交代" },
            { event_type: "pinch_hitter" }
          ]
        }.with_indifferent_access
      end

      it '宣言イベントを生成する' do
        expect(subject.length).to eq(2)
        expect(subject[0]).to include(seq: 1, type: "declaration", subtype: "pitcher_change", speaker: "monitor", text: "投手交代")
        expect(subject[1]).to include(seq: 2, type: "declaration", subtype: "pinch_hitter")
      end

      it 'typeが空のイベントをスキップする' do
        params[:events] << { type: "" }
        expect(subject.length).to eq(2)
      end
    end

    context 'strategy（宣言）がある場合' do
      %w[endrun bunt bunt_fc intentional_walk steal].each do |s|
        it "#{s} を宣言イベントとして生成する" do
          result = described_class.build_source_events({ strategy: s })
          expect(result).to include(a_hash_including(type: "declaration", subtype: s))
        end
      end

      it '対象外のstrategyは生成しない' do
        result = described_class.build_source_events({ strategy: "normal" })
        expect(result).to be_empty
      end
    end

    context '前進守備（宣言）がある場合' do
      it '内野のみ' do
        result = described_class.build_source_events({ infield_forward: true })
        expect(result).to include(a_hash_including(subtype: "infield_forward"))
        expect(result).not_to include(a_hash_including(subtype: "outfield_forward"))
      end

      it '外野のみ' do
        result = described_class.build_source_events({ outfield_forward: true })
        expect(result).to include(a_hash_including(subtype: "outfield_forward"))
        expect(result).not_to include(a_hash_including(subtype: "infield_forward"))
      end

      it '内野+外野両方' do
        result = described_class.build_source_events({ infield_forward: true, outfield_forward: true })
        expect(result).to include(a_hash_including(subtype: "infield_outfield_forward"))
      end

      it '"false"文字列は前進守備扱いしない' do
        result = described_class.build_source_events({ infield_forward: "false" })
        expect(result).to be_empty
      end
    end

    context '盗塁試み（ダイス）がある場合' do
      let(:params) do
        {
          steal_attempts: [
            { base: 2, st_dice: 5, st_result: "safe", ed_dice: 3, ed_result: "safe" }
          ]
        }
      end

      it 'st_dice と ed_dice の両方を生成する' do
        expect(subject.length).to eq(2)
        expect(subject[0]).to include(type: "dice", subtype: "steal_st", roll: 5, base: 2, result: "safe")
        expect(subject[1]).to include(type: "dice", subtype: "steal_ed", roll: 3, base: 2, result: "safe")
      end

      it 'st_diceがなければ生成しない' do
        params[:steal_attempts] = [ { base: 2, ed_dice: 3, ed_result: "out" } ]
        expect(subject.length).to eq(1)
        expect(subject[0]).to include(subtype: "steal_ed")
      end
    end

    context '投球ダイスがある場合' do
      let(:params) { { pitch_roll: 8, pitch_result: "BB" } }

      it '投球ダイスイベントを生成する' do
        expect(subject).to include(a_hash_including(type: "dice", subtype: "pitch", roll: 8, result: "BB"))
      end
    end

    context '打撃ダイスがある場合' do
      let(:params) { { bat_roll: 12, bat_result: "HR" } }

      it '打撃ダイスイベントを生成する' do
        expect(subject).to include(a_hash_including(type: "dice", subtype: "bat", roll: 12, result: "HR"))
      end
    end

    context 'extra_rollsがある場合' do
      let(:params) do
        {
          extra_rolls: [
            { roll: 5, result: "ok", event_type: "range_check" },
            { roll: 3, result: "error", event_type: "error_check" },
            { roll: 7, result: "up", event_type: "up_table" },
            { roll: 2, result: "ok", event_type: "shoulder_check" },
            { roll: 9, result: "safe", event_type: "bunt" },
            { roll: 4, result: "x", event_type: "unknown_type" }
          ]
        }
      end

      it 'subtypeを正しくマッピングする' do
        subtypes = subject.map { |e| e[:subtype] }
        expect(subtypes).to eq(%w[range_check error_check up_table shoulder_check bunt_roll extra])
      end

      it 'extraタイプはevent_typeフィールドを保持する' do
        extra_event = subject.find { |e| e[:subtype] == "extra" }
        expect(extra_event[:event_type]).to eq("unknown_type")
      end

      it 'dice_listがあれば保持する' do
        params[:extra_rolls] = [ { roll: 5, result: "ok", event_type: "range_check", dice_list: [ 3, 2 ] } ]
        expect(subject[0][:dice_list]).to eq([ 3, 2 ])
      end
    end

    context '走者進塁（自動計算）がある場合' do
      let(:params) { { runners_before: [ 1 ], runners_after: [ 2, 3 ] } }

      it 'runner_advanceイベントを生成する' do
        expect(subject).to include(a_hash_including(type: "auto", subtype: "runner_advance",
                                                     runners_before: [ 1 ], runners_after: [ 2, 3 ]))
      end

      it '走者変化がなければ生成しない' do
        result = described_class.build_source_events({ runners_before: [ 1 ], runners_after: [ 1 ] })
        expect(result).to be_empty
      end
    end

    context '得点（自動計算）がある場合' do
      it '得点イベントを生成する' do
        result = described_class.build_source_events({ runs_scored: 2 })
        expect(result).to include(a_hash_including(type: "auto", subtype: "scoring", runs: 2))
      end

      it '0点は生成しない' do
        result = described_class.build_source_events({ runs_scored: 0 })
        expect(result).to be_empty
      end
    end

    context 'アウトカウント変化（自動計算）がある場合' do
      it 'out_recordedイベントを生成する' do
        result = described_class.build_source_events({ outs_before: 0, outs_after: 1 })
        expect(result).to include(a_hash_including(type: "auto", subtype: "out_recorded",
                                                    outs_before: 0, outs_after: 1))
      end

      it '変化がなければ生成しない' do
        result = described_class.build_source_events({ outs_before: 1, outs_after: 1 })
        expect(result).to be_empty
      end
    end

    context 'seqが連番で振られること' do
      let(:params) do
        {
          strategy: "bunt",
          pitch_roll: 5, pitch_result: "strike",
          bat_roll: 8, bat_result: "H",
          runs_scored: 1,
          outs_before: 0, outs_after: 1
        }
      end

      it 'seqは1始まりの連番' do
        seqs = subject.map { |e| e[:seq] }
        expect(seqs).to eq((1..seqs.length).to_a)
      end
    end

    context '空パラメータの場合' do
      let(:params) { {} }

      it '空配列を返す' do
        expect(subject).to eq([])
      end
    end
  end

  describe '.normalize_discrepancies' do
    subject { described_class.normalize_discrepancies(raw) }

    context '通常のdiscrepanciesがある場合' do
      let(:raw) do
        [
          { field: "score", text: "3-2", gsm: "3-1", cause: "score_mismatch", resolution: "gsm_wins" },
          { "field" => "outs", "text" => "2", "gsm" => "1" }
        ]
      end

      it 'DB格納形式に変換する' do
        expect(subject[0]).to eq({
          "field" => "score",
          "text_value" => "3-2",
          "gsm_value" => "3-1",
          "cause" => "score_mismatch",
          "resolution" => "gsm_wins"
        })
      end

      it '文字列キーも正しく処理する' do
        expect(subject[1]).to include("field" => "outs", "text_value" => "2", "gsm_value" => "1")
      end

      it 'causeがなければunknownを補完する' do
        expect(subject[1]["cause"]).to eq("unknown")
      end
    end

    context 'nilフィールドはcompactで除外されること' do
      let(:raw) { [ { field: "score", text: "3-2" } ] }

      it 'nilのgsm_value, resolution, noteは含まれない' do
        result = subject[0]
        expect(result).not_to have_key("gsm_value")
        expect(result).not_to have_key("resolution")
        expect(result).not_to have_key("note")
      end
    end

    context 'nilを渡した場合' do
      let(:raw) { nil }

      it '空配列を返す' do
        expect(subject).to eq([])
      end
    end

    context '空配列を渡した場合' do
      let(:raw) { [] }

      it '空配列を返す' do
        expect(subject).to eq([])
      end
    end
  end

  describe 'インスタンスメソッドでの呼び出し' do
    it 'build_source_eventsをインスタンスメソッドとして呼べる' do
      builder = described_class.new
      result = builder.build_source_events({ pitch_roll: 6, pitch_result: "K" })
      expect(result).to include(a_hash_including(subtype: "pitch", roll: 6))
    end

    it 'normalize_discrepanciesをインスタンスメソッドとして呼べる' do
      builder = described_class.new
      result = builder.normalize_discrepancies([ { field: "f", text: "t", gsm: "g" } ])
      expect(result[0]["field"]).to eq("f")
    end
  end
end
