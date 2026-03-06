module Api
  module V1
    class SquadTextSettingsController < Api::V1::BaseController
      before_action :set_team

      # GET /api/v1/teams/:team_id/squad_text_settings
      # 存在すれば取得、なければデフォルト値で新規作成
      def show
        @setting = @team.squad_text_setting || @team.build_squad_text_setting
        @setting.save! unless @setting.persisted?
        render json: serialize_setting(@setting)
      end

      # PUT /api/v1/teams/:team_id/squad_text_settings
      def update
        @setting = @team.squad_text_setting || @team.build_squad_text_setting
        if @setting.update(setting_params)
          render json: serialize_setting(@setting)
        else
          render json: { errors: @setting.errors.full_messages }, status: :unprocessable_content
        end
      end

      private

      def set_team
        @team = Team.find(params[:team_id])
      end

      def setting_params
        params.require(:squad_text_setting).permit(
          :position_format,
          :handedness_format,
          :date_format,
          :section_header_format,
          :show_number_prefix,
          batting_stats_config: {},
          pitching_stats_config: {}
        )
      end

      def serialize_setting(setting)
        {
          id: setting.id,
          team_id: setting.team_id,
          position_format: setting.position_format,
          handedness_format: setting.handedness_format,
          date_format: setting.date_format,
          section_header_format: setting.section_header_format,
          show_number_prefix: setting.show_number_prefix,
          batting_stats_config: setting.batting_stats_config,
          pitching_stats_config: setting.pitching_stats_config,
          updated_at: setting.updated_at
        }
      end
    end
  end
end
