class Pipelines::Automations::Actions::AddLabels < Pipelines::Automations::Actions::UpdateLabels
  def perform
    conversations.find_each { |conversation| conversation.reload.add_labels(labels) }
    result
  end
end
