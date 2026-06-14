class Api::V1::Accounts::PipelineItemTransitionsController < Api::V1::Accounts::BaseController
  before_action :fetch_pipeline_item
  before_action :authorize_pipeline_item

  def update
    @pipeline_item = Pipelines::Items::TransitionStageService.new(
      pipeline_item: @pipeline_item,
      target_stage_id: transition_params[:stage_id],
      actor: Current.user,
      source: transition_params[:source].presence || 'api'
    ).perform
  rescue Pipelines::Items::MissingRequiredFieldsError => e
    render_missing_fields(e)
  end

  private

  def fetch_pipeline_item
    @pipeline_item = Current.account.pipeline_items.find(params[:pipeline_item_id])
  end

  def authorize_pipeline_item
    authorize @pipeline_item, :transition?
  end

  def transition_params
    params.require(:transition).permit(:stage_id, :source)
  end

  def render_missing_fields(error)
    render json: {
      error: 'missing_required_fields',
      message: error.message,
      missing_field_keys: error.field_keys,
      missing_fields: error.field_definitions.map { |definition| field_summary(definition) }
    }, status: :unprocessable_entity
  end

  def field_summary(definition)
    { key: definition.key, label: definition.label }
  end
end
