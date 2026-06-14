class Pipelines::Items::LinkConversationService
  def initialize(pipeline_item:, conversation:, actor:, source:)
    @pipeline_item = pipeline_item
    @conversation = conversation
    @actor = actor
    @source = source
  end

  def perform
    PipelineItemConversation.transaction do
      pipeline_item.lock!
      existing_link = pipeline_item.conversation_links.find_by(conversation: conversation)
      next existing_link if existing_link.present?

      conversation_link = pipeline_item.conversation_links.create!(
        account: pipeline_item.account,
        conversation: conversation,
        linked_by: actor,
        source: source
      )
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
      event_type: :conversation_linked,
      source: source
    )
  end
end
