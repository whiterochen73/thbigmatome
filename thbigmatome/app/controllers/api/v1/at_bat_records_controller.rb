class Api::V1::AtBatRecordsController < Api::V1::BaseController
  before_action :set_at_bat_record, only: [ :update ]

  # PATCH /api/v1/at_bat_records/:id
  def update
    permitted = at_bat_params

    changed_fields = {}
    permitted.each do |key, value|
      if @at_bat_record.send(key) != value
        changed_fields[key] = { from: @at_bat_record.send(key), to: value }
      end
    end

    modified_fields = @at_bat_record.modified_fields || {}
    modified_fields.merge!(changed_fields)

    recalculated_disc = recalculate_discrepancies(@at_bat_record.discrepancies, changed_fields)

    # Set adopted_value to the modified fields
    adopted_value = build_adopted_value(@at_bat_record, permitted)

    attrs = permitted.to_h.merge(
      is_modified: true,
      modified_fields: modified_fields,
      discrepancies: recalculated_disc,
      adopted_value: adopted_value
    )

    if @at_bat_record.update(attrs)
      # Recalculate affected at_bat_records (those from this record onwards in the same game)
      recalculate_affected_records(@at_bat_record)

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
    permitted = params.permit(
      :result_code, :runs_scored, :outs_before, :outs_after,
      :pitcher_name, :pitcher_id, :batter_name, :batter_id,
      :pitch_roll, :pitch_result, :bat_roll, :bat_result,
      :strategy, :play_description, :is_reviewed, :review_notes,
      extra_data: {}
    )
    # runners はArray形式 [1,2,3] を受け付ける (JSONB)。要素は1-3の整数のみ許可。
    if params.key?(:runners_before)
      val = params[:runners_before]
      permitted[:runners_before] = sanitize_runners(val)
    end
    if params.key?(:runners_after)
      val = params[:runners_after]
      permitted[:runners_after] = sanitize_runners(val)
    end
    permitted
  end

  def build_adopted_value(at_bat_record, permitted)
    # Snapshot of adopted (human-decided) values
    adopted = {
      result_code: permitted[:result_code] || at_bat_record.result_code,
      runs_scored: permitted[:runs_scored] || at_bat_record.runs_scored,
      runners_before: permitted[:runners_before] || at_bat_record.runners_before,
      runners_after: permitted[:runners_after] || at_bat_record.runners_after,
      outs_before: permitted[:outs_before] || at_bat_record.outs_before,
      outs_after: permitted[:outs_after] || at_bat_record.outs_after
    }
    adopted
  end

  def recalculate_affected_records(modified_record)
    # Recalculate all records from this one onwards in the same game
    game_record = modified_record.game_record
    affected_records = game_record.at_bat_records.where("ab_num >= ?", modified_record.ab_num)

    # For now, store gsm_value as a snapshot of the current computed values
    # In a full implementation, this would call the Python GSM
    affected_records.each do |record|
      gsm_snapshot = {
        result_code: record.result_code,
        runs_scored: record.runs_scored,
        runners_before: record.runners_before,
        runners_after: record.runners_after,
        outs_before: record.outs_before,
        outs_after: record.outs_after
      }
      record.update_column(:gsm_value, gsm_snapshot) unless record.gsm_value.present?
    end
  end

  def sanitize_runners(val)
    return [] unless val.is_a?(Array)
    val.filter_map { |n| Integer(n) rescue nil }.select { |n| [ 1, 2, 3 ].include?(n) }.uniq
  end

  def recalculate_discrepancies(existing_discrepancies, changed_fields)
    return existing_discrepancies if existing_discrepancies.blank? || changed_fields.blank?

    existing_discrepancies.map do |d|
      field = d["field"].to_s
      if changed_fields.key?(field)
        d.merge("resolution" => "manual", "resolution_value" => changed_fields[field][:to])
      else
        d
      end
    end
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
      is_reviewed: ab.is_reviewed,
      review_notes: ab.review_notes,
      play_description: ab.play_description,
      extra_data: ab.extra_data,
      discrepancies: ab.discrepancies,
      gsm_value: ab.gsm_value,
      adopted_value: ab.adopted_value,
      source_events: ab.source_events,
      created_at: ab.created_at,
      updated_at: ab.updated_at
    }
  end
end
