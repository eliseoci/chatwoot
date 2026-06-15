class Api::V1::Accounts::PipelineReportsController < Api::V1::Accounts::BaseController
  before_action :fetch_pipeline
  before_action :authorize_pipeline

  def show
    render json: Pipelines::Reports::OperationalSnapshot.new(
      pipeline: @pipeline,
      generated_at: Time.current
    ).perform
  end

  private

  def fetch_pipeline
    @pipeline = policy_scope(Current.account.pipelines).find(params[:pipeline_id])
  end

  def authorize_pipeline
    authorize @pipeline, :show?
  end
end
