require 'rails_helper'

RSpec.describe Pipelines::Items::WorkspaceContextService do
  let(:account) { create(:account) }
  let(:item) { create(:pipeline_item, account: account) }
  let(:at) { Time.zone.parse('2026-06-14 12:00:00') }

  context 'with linked attention signals' do
    let(:conversation) do
      create(
        :conversation,
        account: account,
        contact: item.contact,
        agent_last_seen_at: at - 9.days
      )
    end

    before do
      conversation.update!(
        label_list: %w[vip renewal],
        waiting_since: at - 8.days,
        assignee_agent_bot: create(:agent_bot, account: account)
      )
      create(
        :pipeline_item_conversation,
        account: account,
        pipeline_item: item,
        conversation: conversation
      )
      create(
        :message,
        account: account,
        inbox: conversation.inbox,
        conversation: conversation,
        message_type: :incoming,
        created_at: at - 8.days
      )
      create(
        :pipeline_activity,
        account: account,
        pipeline_item: item,
        due_at: at - 1.hour
      )
      item.update!(updated_at: at - 8.days)
      conversation.update!(last_activity_at: at - 8.days)
    end

    it 'summarizes linked operational context and attention reasons' do
      context = described_class.new([item.reload], at: at).perform.fetch(item.id)

      expect(context).to include(
        unread_count: 1,
        conversation_ids: [conversation.display_id],
        channels: [conversation.inbox.channel_type],
        labels: %w[vip renewal]
      )
      expect(context[:inboxes]).to contain_exactly(
        id: conversation.inbox.id,
        name: conversation.inbox.name,
        channel_type: conversation.inbox.channel_type
      )
      expect(context[:attention_reasons]).to contain_exactly(
        'overdue_activity',
        'unread_conversation',
        'handoff',
        'stalled'
      )
    end
  end

  it 'flags items without a next activity' do
    context = described_class.new([item], at: at).perform.fetch(item.id)

    expect(context[:attention_reasons]).to include('missing_next_activity')
  end
end
