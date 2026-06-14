class Pipelines::Automations::Actions::UpdateField
  def initialize(action:, action_run:, pipeline_item:)
    @action = action
    @action_run = action_run
    @pipeline_item = pipeline_item
  end

  def perform
    field_key = action.config.fetch('field_key')
    Pipelines::Items::UpdateFieldValuesService.new(
      pipeline_item: pipeline_item,
      values: { field_key => action.config['value'] },
      actor: nil,
      source: 'automation'
    ).perform
    { field_key: field_key, value: pipeline_item.reload.field_values[field_key] }
  end

  private

  attr_reader :action, :action_run, :pipeline_item
end
