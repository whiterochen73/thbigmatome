class Api::V1::CompetitionsController < Api::V1::BaseController
  before_action :authorize_commissioner!, only: [ :create, :update, :destroy ]

  def index
    competitions = Competition.all.order(year: :desc, id: :asc)
    render json: competitions, each_serializer: CompetitionSerializer
  end

  def show
    competition = Competition.includes(:competition_entries).find(params[:id])
    render json: competition, serializer: CompetitionSerializer
  end

  def create
    competition = Competition.new(competition_params)
    if competition.save
      render json: competition, serializer: CompetitionSerializer, status: :created
    else
      render json: { errors: competition.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    competition = Competition.find(params[:id])
    if competition.update(competition_params)
      render json: competition, serializer: CompetitionSerializer
    else
      render json: { errors: competition.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    competition = Competition.find(params[:id])
    competition.destroy
    head :no_content
  end

  private

  def competition_params
    params.require(:competition).permit(:name, :year, :competition_type)
  end
end
