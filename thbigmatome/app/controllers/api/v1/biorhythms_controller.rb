module Api
  module V1
    class BiorhythmsController < Api::V1::BaseController
      before_action :set_biorhythm, only: [ :update, :destroy ]

      # GET /api/v1/biorhythms
      def index
        @biorhythms = Biorhythm.all.order(:start_date, :name)
        render json: @biorhythms.to_json
      end

      # POST /api/v1/biorhythms
      def create
        @biorhythm = Biorhythm.new(biorhythm_params)
        if @biorhythm.save
          render json: @biorhythm, status: :created
        else
          render json: { errors: @biorhythm.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/biorhythms/:id
      def update
        if @biorhythm.update(biorhythm_params)
          render json: @biorhythm
        else
          render json: { errors: @biorhythm.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/biorhythms/:id
      def destroy
        @biorhythm.destroy
        head :no_content
      end

      private

      def set_biorhythm
        @biorhythm = Biorhythm.find(params[:id])
      end

      def biorhythm_params
        params.require(:biorhythm).permit(:name, :start_date, :end_date)
      end
    end
  end
end
