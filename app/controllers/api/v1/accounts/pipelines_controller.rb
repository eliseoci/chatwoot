class Api::V1::Accounts::PipelinesController < Api::V1::Accounts::BaseController
  before_action :fetch_pipeline, only: [:show]
  before_action :check_authorization

  def index
    @pipelines = Current.account.pipelines.includes(:stages).order(:name)
  end

  def show; end

  def create
    @pipeline = Pipelines::CreateFromTemplateService.new(
      account: Current.account,
      attributes: pipeline_params
    ).perform
  end

  def templates
    @templates = Pipelines::Templates.all
  end

  private

  def fetch_pipeline
    @pipeline = Current.account.pipelines.includes(:stages).find(params[:id])
  end

  def pipeline_params
    params.require(:pipeline).permit(
      :name,
      :description,
      :template_key,
      stages: [:name, :color, :terminal, :outcome_key]
    )
  end
end
