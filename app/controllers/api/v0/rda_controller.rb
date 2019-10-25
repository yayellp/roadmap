# frozen_string_literal: true

# TODO: Replace the v0 plans_controller logic with this RDA compliant JSON
class Api::V0::RdaController < Api::V0::BaseController

  before_action :authenticate

  def export_dmp
    plan = Plan.find(params[:id])
    render json: Dmphub::ConversionService.plan_to_rda_json(plan: plan)
  end

end
