module Api
  module V1
    class SeasonsController < Api::V1::BaseController
      include TeamAccessible

      before_action :authorize_team_access!, only: [ :create ]
      before_action :authorize_commissioner!, only: [ :destroy ]

      def create
        ActiveRecord::Base.transaction do
          team = Team.find(params[:team_id])
          schedule = Schedule.find(params[:schedule_id])

          season = Season.new(
            team: team,
            name: params[:name],
            current_date: schedule.start_date,
            team_type: team.team_type,
          )
          season.save!

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
        render json: { error: e.message }, status: :unprocessable_content
      end

      def destroy
        season = Season.find(params[:id])
        season.destroy!
        head :no_content
      rescue ActiveRecord::RecordNotFound => e
        render json: { error: e.message }, status: :not_found
      end
    end
  end
end
