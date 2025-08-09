class Api::V1::SchedulesController < ApplicationController
  before_action :set_schedule, only: [:update, :destroy]

  def index
    schedules = Schedule.all
    render json: schedules
  end

  def create
    schedule = Schedule.new(schedule_params)
    if schedule.save
      render json: schedule, status: :created
    else
      render json: schedule.errors, status: :unprocessable_entity
    end
  end

  def update
    if @schedule.update(schedule_params)
      render json: @schedule
    else
      render json: @schedule.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @schedule.destroy
    head :no_content
  end

  private

  def set_schedule
    @schedule = Schedule.find(params[:id])
  end

  def schedule_params
    params.require(:schedule).permit(:name, :start_date, :end_date, :effective_date)
  end
end