class Api::V1::Accounts::PipelineStagesController < Api::V1::Accounts::BaseController
  before_action :fetch_pipeline
  before_action :fetch_stage
  before_action :check_authorization

  def update
    @stage.update!(required_field_keys: stage_params[:required_field_keys])
  end

  private

  def fetch_pipeline
    @pipeline = Current.account.pipelines.find(params[:pipeline_id])
  end

  def fetch_stage
    @stage = @pipeline.stages.find(params[:id])
  end

  def stage_params
    params.require(:pipeline_stage).permit(required_field_keys: [])
  end
end
