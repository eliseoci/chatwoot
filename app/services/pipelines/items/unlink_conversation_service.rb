class Pipelines::Items::UnlinkConversationService
  def initialize(pipeline_item:, conversation:, actor:, source:)
    @pipeline_item = pipeline_item
    @conversation = conversation
    @actor = actor
    @source = source
  end

  def perform
    PipelineItemConversation.transaction do
      pipeline_item.lock!
      conversation_link = pipeline_item.conversation_links.find_by!(conversation: conversation)
      conversation_link.destroy!
      record_event
      conversation_link
    end
  end

  private

  attr_reader :pipeline_item, :conversation, :actor, :source

  def record_event
    pipeline_item.events.create!(
      account: pipeline_item.account,
      conversation: conversation,
      actor: actor,
      event_type: :conversation_unlinked,
      source: source
    )
  end
end
