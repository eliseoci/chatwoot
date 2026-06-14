class Pipelines::Items::WorkspaceContextService
  STALLED_AFTER = 7.days

  def initialize(pipeline_items, at: Time.current)
    @pipeline_items = pipeline_items.to_a
    @at = at
  end

  def perform
    unread_counts = unread_counts_by_conversation

    pipeline_items.to_h do |pipeline_item|
      [pipeline_item.id, build_context(pipeline_item, unread_counts)]
    end
  end

  private

  attr_reader :pipeline_items, :at

  def build_context(pipeline_item, unread_counts)
    conversations = pipeline_item.conversation_links.map(&:conversation)
    last_activity_at = ([pipeline_item.updated_at] + conversations.map(&:last_activity_at)).compact.max
    unread_count = conversations.sum { |conversation| unread_counts.fetch(conversation.id, 0) }
    attention_reasons = attention_reasons_for(
      pipeline_item,
      conversations,
      last_activity_at,
      unread_count
    )

    {
      last_activity_at: last_activity_at,
      unread_count: unread_count,
      conversation_ids: conversations.map(&:display_id),
      channels: channels_for(conversations),
      labels: labels_for(conversations),
      inboxes: inboxes_for(conversations),
      attention_reasons: attention_reasons,
      attention_note: pipeline_item.attention_note
    }
  end

  def attention_reasons_for(pipeline_item, conversations, last_activity_at, unread_count)
    [
      ['overdue_activity', overdue_activity?(pipeline_item)],
      ['unread_conversation', unread_count.positive?],
      ['handoff', conversations.any? { |conversation| handoff?(conversation) }],
      ['missing_next_activity', pipeline_item.next_activity.blank?],
      ['stalled', stalled?(last_activity_at)],
      ['manual_attention', pipeline_item.attention_required?],
      ['failed_automation', pipeline_item.automation_runs.any?(&:status_failed?)]
    ].filter_map { |reason, active| reason if active }
  end

  def overdue_activity?(pipeline_item)
    pipeline_item.next_activity&.overdue?(at: at)
  end

  def stalled?(last_activity_at)
    last_activity_at < at - STALLED_AFTER
  end

  def channels_for(conversations)
    conversations.filter_map { |conversation| conversation.inbox&.channel_type }.uniq
  end

  def labels_for(conversations)
    conversations.flat_map(&:cached_label_list_array).uniq
  end

  def inboxes_for(conversations)
    conversations.filter_map { |conversation| inbox_summary(conversation.inbox) }.uniq
  end

  def handoff?(conversation)
    conversation.waiting_since.present? && conversation.assignee_agent_bot_id.present?
  end

  def inbox_summary(inbox)
    return if inbox.blank?

    {
      id: inbox.id,
      name: inbox.name,
      channel_type: inbox.channel_type
    }
  end

  def unread_counts_by_conversation
    conversation_ids = pipeline_items.flat_map do |pipeline_item|
      pipeline_item.conversation_links.map(&:conversation_id)
    end.uniq
    return {} if conversation_ids.empty?

    Message.incoming
           .joins(:conversation)
           .where(messages: { account_id: pipeline_items.first.account_id, conversation_id: conversation_ids })
           .where(
             'messages.created_at > COALESCE(conversations.agent_last_seen_at, ?)',
             Time.zone.at(0)
           )
           .reorder(nil)
           .group('messages.conversation_id')
           .count
  end
end
