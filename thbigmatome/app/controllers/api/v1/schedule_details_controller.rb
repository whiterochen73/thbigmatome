class Api::V1::ScheduleDetailsController < ApplicationController
  before_action :set_schedule

  def index
    schedule_details = @schedule.schedule_details.order(:date)
    render json: schedule_details
  end

  def upsert_all
    schedule_details_params = params.require(:schedule_details).map do |p|
      p.permit(:id, :date, :date_type, :schedule_id, :priority)
    end

    ScheduleDetail.upsert_all(schedule_details_params, unique_by: [:schedule_id, :date])

    head :ok
  end

  private

  def set_schedule
    @schedule = Schedule.find(params[:schedule_id])
  end
end
