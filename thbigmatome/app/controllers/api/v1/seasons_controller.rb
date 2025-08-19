module Api
  module V1
    class SeasonsController < ApplicationController
      def create
        ActiveRecord::Base.transaction do
          team = Team.find(params[:team_id])
          schedule = Schedule.find(params[:schedule_id])

          season = Season.create!(
            team: team,
            name: params[:name],
            current_date: schedule.start_date,
          )

          schedule.schedule_details.each do |detail|
            SeasonSchedule.create!(
              season: season,
              date: detail.date,
              date_type: detail.date_type
            )
          end

          render json: { season: season, schedule_count: season.season_schedules.count }, status: :created
        end
      rescue ActiveRecord::RecordNotFound => e
        render json: { error: e.message }, status: :not_found
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.message }, status: :unprocessable_entity
      end
    end
  end
end
