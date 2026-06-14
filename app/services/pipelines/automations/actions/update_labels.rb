class Pipelines::Automations::Actions::UpdateLabels
  def initialize(action:, action_run:, pipeline_item:)
    @action = action
    @action_run = action_run
    @pipeline_item = pipeline_item
  end

  private

  attr_reader :action, :action_run, :pipeline_item

  def conversations
    pipeline_item.linked_conversations
  end

  def labels
    Array(action.config['labels'])
  end

  def result
    {
      conversation_ids: conversations.pluck(:id),
      labels: labels
    }
  end
end
