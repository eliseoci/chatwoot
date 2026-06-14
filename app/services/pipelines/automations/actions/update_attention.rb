class Pipelines::Automations::Actions::UpdateAttention
  def initialize(action:, action_run:, pipeline_item:)
    @action = action
    @action_run = action_run
    @pipeline_item = pipeline_item
  end

  def perform
    required = action.config.fetch('state') == 'required'
    pipeline_item.update!(
      attention_required: required,
      attention_note: required ? action.config['note'].presence : nil
    )
    {
      attention_required: required,
      attention_note: pipeline_item.attention_note
    }
  end

  private

  attr_reader :action, :action_run, :pipeline_item
end
