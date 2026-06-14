class Pipelines::Automations::Actions::RemoveLabels < Pipelines::Automations::Actions::UpdateLabels
  def perform
    conversations.find_each do |conversation|
      conversation.update!(label_list: conversation.reload.label_list - labels)
    end
    result
  end
end
