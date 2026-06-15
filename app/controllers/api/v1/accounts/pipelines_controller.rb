class Api::V1::Accounts::PipelinesController < Api::V1::Accounts::BaseController
  before_action :fetch_pipeline, only: [:show, :update]
  before_action :authorize_collection, only: [:index]
  before_action :authorize_pipeline, only: [:show, :update]
  before_action :check_authorization, only: [:create, :templates]

  def index
    @pipelines = policy_scope(Current.account.pipelines)
                 .includes(:stages, :field_definitions)
                 .order(:name)
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

  def update
    @pipeline.update!(pipeline_update_params)
  end

  private

  def fetch_pipeline
    @pipeline = policy_scope(Current.account.pipelines)
                .includes(:stages, :field_definitions)
                .find(params[:id])
  end

  def authorize_collection
    authorize Pipeline, :index?
  end

  def authorize_pipeline
    authorize @pipeline
  end

  def pipeline_params
    params.require(:pipeline).permit(
      :name,
      :description,
      :template_key,
      stages: [:name, :color, :terminal, :outcome_key]
    )
  end

  def pipeline_update_params
    params.require(:pipeline).permit(:access_mode)
  end
end
