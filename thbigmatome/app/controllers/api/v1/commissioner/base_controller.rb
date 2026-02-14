class Api::V1::Commissioner::BaseController < Api::V1::BaseController
  before_action :check_commissioner

  private

  def check_commissioner
    head :forbidden unless current_user.commissioner?
  end
end
