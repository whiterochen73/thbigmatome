class Api::V1::AtBatRecordsController < Api::V1::BaseController
  before_action :set_at_bat_record, only: [ :update ]

  # PATCH /api/v1/at_bat_records/:id
  def update
    changed_fields = {}
    at_bat_params.each do |key, value|
      if @at_bat_record.send(key) != value
        changed_fields[key] = { from: @at_bat_record.send(key), to: value }
      end
    end

    modified_fields = @at_bat_record.modified_fields || {}
    modified_fields.merge!(changed_fields)

    if @at_bat_record.update(at_bat_params.merge(is_modified: true, modified_fields: modified_fields))
      render json: serialize_at_bat_record(@at_bat_record)
    else
      render json: { errors: @at_bat_record.errors.full_messages }, status: :unprocessable_content
    end
  end

  private

  def set_at_bat_record
    @at_bat_record = AtBatRecord.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "At bat record not found" }, status: :not_found
  end

  def at_bat_params
    params.permit(
      :result_code, :runs_scored, :outs_before, :outs_after,
      :pitcher_name, :pitcher_id, :batter_name, :batter_id,
      :pitch_roll, :pitch_result, :bat_roll, :bat_result,
      :strategy, :play_description,
      runners_before: {}, runners_after: {}, extra_data: {}
    )
  end

  def serialize_at_bat_record(ab)
    {
      id: ab.id,
      game_record_id: ab.game_record_id,
      inning: ab.inning,
      half: ab.half,
      ab_num: ab.ab_num,
      pitcher_name: ab.pitcher_name,
      pitcher_id: ab.pitcher_id,
      batter_name: ab.batter_name,
      batter_id: ab.batter_id,
      pitch_roll: ab.pitch_roll,
      pitch_result: ab.pitch_result,
      bat_roll: ab.bat_roll,
      bat_result: ab.bat_result,
      result_code: ab.result_code,
      strategy: ab.strategy,
      runners_before: ab.runners_before,
      runners_after: ab.runners_after,
      outs_before: ab.outs_before,
      outs_after: ab.outs_after,
      runs_scored: ab.runs_scored,
      is_modified: ab.is_modified,
      modified_fields: ab.modified_fields,
      play_description: ab.play_description,
      extra_data: ab.extra_data,
      discrepancies: ab.discrepancies,
      source_events: ab.source_events,
      created_at: ab.created_at,
      updated_at: ab.updated_at
    }
  end
end
