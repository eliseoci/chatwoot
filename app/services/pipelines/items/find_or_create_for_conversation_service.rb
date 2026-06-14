class Pipelines::Items::FindOrCreateForConversationService
  def initialize(conversation:, intake_rule:, allow_parallel: false, actor: nil, source: 'conversation_created')
    @conversation = conversation
    @intake_rule = intake_rule
    @allow_parallel = allow_parallel
    @actor = actor
    @source = source
  end

  def perform
    PipelineItem.transaction do
      conversation.contact.lock!
      existing_link = existing_conversation_link
      next existing_link.pipeline_item if existing_link.present?

      pipeline_item = reusable_item unless allow_parallel
      event_type = pipeline_item.present? ? :conversation_deduplicated : creation_event_type
      pipeline_item ||= create_pipeline_item
      link_conversation(pipeline_item)
      record_decision(pipeline_item, event_type)
      pipeline_item
    end
  end

  private

  attr_reader :conversation, :intake_rule, :allow_parallel, :actor, :source

  def existing_conversation_link
    PipelineItemConversation
      .joins(:pipeline_item)
      .find_by(
        conversation: conversation,
        pipeline_items: { pipeline_id: intake_rule.pipeline_id }
      )
  end

  def reusable_item
    conversation.account.pipeline_items
                .joins(:stage)
                .where(
                  contact: conversation.contact,
                  pipeline: intake_rule.pipeline,
                  pipeline_stages: { terminal: false }
                )
                .order(updated_at: :desc, id: :desc)
                .first
  end

  def create_pipeline_item
    conversation.account.pipeline_items.create!(
      pipeline: intake_rule.pipeline,
      stage: intake_rule.initial_stage,
      contact: conversation.contact
    )
  end

  def link_conversation(pipeline_item)
    Pipelines::Items::LinkConversationService.new(
      pipeline_item: pipeline_item,
      conversation: conversation,
      actor: actor,
      source: source
    ).perform
  end

  def record_decision(pipeline_item, event_type)
    pipeline_item.events.create!(
      account: pipeline_item.account,
      conversation: conversation,
      actor: actor,
      event_type: event_type,
      source: source
    )
  end

  def creation_event_type
    allow_parallel ? :parallel_item_created : :automatic_item_created
  end
end
