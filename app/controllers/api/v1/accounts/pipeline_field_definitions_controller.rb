class Api::V1::Accounts::PipelineFieldDefinitionsController < Api::V1::Accounts::BaseController
  before_action :fetch_pipeline
  before_action :fetch_field_definition, only: [:update, :destroy]
  before_action :check_authorization

  def index
    @field_definitions = @pipeline.field_definitions.active.ordered
  end

  def create
    @field_definition = @pipeline.field_definitions.create!(
      field_definition_params.merge(
        account: Current.account,
        position: next_position
      )
    )
  end

  def update
    @field_definition.update!(field_definition_params.except(:field_type))
  end

  def destroy
    PipelineFieldDefinition.transaction do
      @pipeline.stages.where('? = ANY(required_field_keys)', @field_definition.key).find_each do |stage|
        stage.update!(required_field_keys: stage.required_field_keys - [@field_definition.key])
      end
      @field_definition.update!(archived_at: Time.current)
    end
    head :no_content
  end

  def reorder
    ordered_ids = Array(params.require(:ordered_ids)).map(&:to_i)
    active_field_definitions = @pipeline.field_definitions.active
    raise ActiveRecord::RecordNotFound unless ordered_ids.sort == active_field_definitions.ids.sort

    field_definitions = active_field_definitions.index_by(&:id)

    PipelineFieldDefinition.transaction do
      ordered_ids.each_with_index do |id, position|
        field_definitions.fetch(id).update!(position: position)
      end
    end
    @field_definitions = @pipeline.field_definitions.active.ordered
    render :index
  end

  private

  def fetch_pipeline
    @pipeline = Current.account.pipelines.find(params[:pipeline_id])
  end

  def fetch_field_definition
    @field_definition = @pipeline.field_definitions.active.find(params[:id])
  end

  def field_definition_params
    params.require(:field_definition).permit(:label, :field_type, settings: {})
  end

  def next_position
    (@pipeline.field_definitions.active.maximum(:position) || -1) + 1
  end
end
