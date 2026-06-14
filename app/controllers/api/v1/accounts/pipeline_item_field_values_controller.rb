class Api::V1::Accounts::PipelineItemFieldValuesController < Api::V1::Accounts::BaseController
  before_action :fetch_pipeline_item
  before_action :authorize_pipeline_item

  def update
    @pipeline_item = Pipelines::Items::UpdateFieldValuesService.new(
      pipeline_item: @pipeline_item,
      values: field_values_params,
      actor: Current.user,
      source: params.dig(:pipeline_item, :source).presence || 'item_detail'
    ).perform
  end

  private

  def fetch_pipeline_item
    @pipeline_item = Current.account.pipeline_items.find(params[:pipeline_item_id])
  end

  def authorize_pipeline_item
    authorize @pipeline_item, :field_values?
  end

  def field_values_params
    params.require(:pipeline_item).require(:field_values).permit!.to_h
  end
end
