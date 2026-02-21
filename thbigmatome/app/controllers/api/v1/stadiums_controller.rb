class Api::V1::StadiumsController < Api::V1::BaseController
  def index
    stadiums = Stadium.all.order(:id)
    render json: stadiums, each_serializer: StadiumSerializer
  end

  def show
    stadium = Stadium.find(params[:id])
    render json: stadium, serializer: StadiumSerializer
  end

  def create
    stadium = Stadium.new(stadium_params)
    if stadium.save
      render json: stadium, serializer: StadiumSerializer, status: :created
    else
      render json: { errors: stadium.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    stadium = Stadium.find(params[:id])
    if stadium.update(stadium_params)
      render json: stadium, serializer: StadiumSerializer
    else
      render json: { errors: stadium.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def stadium_params
    params.require(:stadium).permit(:code, :name, :up_table_ids, :indoor)
  end
end
