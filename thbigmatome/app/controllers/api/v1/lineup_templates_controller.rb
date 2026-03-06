module Api
  module V1
    class LineupTemplatesController < Api::V1::BaseController
      before_action :set_team
      before_action :set_lineup_template, only: [ :show, :update, :destroy ]

      # GET /api/v1/teams/:team_id/lineup_templates
      def index
        @templates = @team.lineup_templates.includes(lineup_template_entries: :player)
        render json: @templates.map { |t| serialize_template(t) }
      end

      # GET /api/v1/teams/:team_id/lineup_templates/:id
      def show
        render json: serialize_template(@lineup_template)
      end

      # POST /api/v1/teams/:team_id/lineup_templates
      def create
        @lineup_template = @team.lineup_templates.new(
          dh_enabled: params.dig(:lineup_template, :dh_enabled),
          opponent_pitcher_hand: params.dig(:lineup_template, :opponent_pitcher_hand)
        )

        ActiveRecord::Base.transaction do
          @lineup_template.save!
          build_entries(@lineup_template, params.dig(:lineup_template, :entries_attributes))
        end

        @lineup_template.reload
        render json: serialize_template(@lineup_template), status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: [ e.message ] }, status: :unprocessable_content
      end

      # PUT /api/v1/teams/:team_id/lineup_templates/:id
      def update
        entries_attrs = params.dig(:lineup_template, :entries_attributes)

        ActiveRecord::Base.transaction do
          if entries_attrs
            @lineup_template.lineup_template_entries.delete_all
            build_entries(@lineup_template, entries_attrs)
          end

          base_dh = params.dig(:lineup_template, :dh_enabled)
          base_hand = params.dig(:lineup_template, :opponent_pitcher_hand)
          update_attrs = {}
          update_attrs[:dh_enabled] = base_dh unless base_dh.nil?
          update_attrs[:opponent_pitcher_hand] = base_hand unless base_hand.nil?
          @lineup_template.update!(update_attrs) if update_attrs.any?
        end

        @lineup_template.reload
        render json: serialize_template(@lineup_template)
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: [ e.message ] }, status: :unprocessable_content
      end

      # DELETE /api/v1/teams/:team_id/lineup_templates/:id
      def destroy
        @lineup_template.destroy
        head :no_content
      end

      private

      def set_team
        @team = Team.find(params[:team_id])
      end

      def set_lineup_template
        @lineup_template = @team.lineup_templates.find(params[:id])
      end

      def build_entries(template, entries_attrs)
        return unless entries_attrs.present?

        entries_attrs.each do |entry|
          template.lineup_template_entries.create!(
            batting_order: entry[:batting_order],
            player_id: entry[:player_id],
            position: entry[:position]
          )
        end
      end

      def serialize_template(template)
        {
          id: template.id,
          dh_enabled: template.dh_enabled,
          opponent_pitcher_hand: template.opponent_pitcher_hand,
          entries: template.lineup_template_entries.order(:batting_order).map do |entry|
            {
              id: entry.id,
              batting_order: entry.batting_order,
              player_id: entry.player_id,
              position: entry.position,
              player_name: entry.player&.name,
              player_number: entry.player&.number
            }
          end
        }
      end
    end
  end
end
