class Api::V1::ScheduleDetailsController < Api::V1::BaseController
  before_action :set_schedule

  def index
    schedule_details = @schedule.schedule_details.order(:date)
    render json: schedule_details
  end

  def upsert_all
    schedule_details_params = params.require(:schedule_details).map do |p|
      p.permit(:id, :date, :date_type, :schedule_id, :priority)
    end

    # ノーゲームは種別ではなく真偽値で表す（種別 no_game は作れない。upsert_all はモデルの検証を通らないのでここで断る）
    if schedule_details_params.any? { |p| p[:date_type] == SeasonSchedule::NO_GAME_DATE_TYPE }
      return render json: { errors: [ "日付の種類に no_game は指定できません。ノーゲームは試合結果の「ノーゲーム」で表します" ] }, status: :unprocessable_content
    end

    ScheduleDetail.upsert_all(schedule_details_params, unique_by: [ :schedule_id, :date ])

    # 日程の完全性の検算（AMB-11。レギュラーの試合日が 143 か）。止めずに、合わない時だけ応答に warnings を付ける（合う時は本文なしの 200）
    warnings = ScheduleMasterCheck.warnings(@schedule)
    return head :ok if warnings.empty?

    render json: { warnings: warnings }, status: :ok
  end

  private

  def set_schedule
    @schedule = Schedule.find(params[:schedule_id])
  end
end
