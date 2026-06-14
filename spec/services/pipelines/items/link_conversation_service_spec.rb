require 'rails_helper'

RSpec.describe Pipelines::Items::LinkConversationService do
  let(:pipeline_item) { create(:pipeline_item) }
  let(:actor) { create(:user, account: pipeline_item.account) }
  let(:conversation) do
    create(
      :conversation,
      :with_assignee,
      account: pipeline_item.account,
      contact: pipeline_item.contact,
      status: :pending
    )
  end

  it 'links a compatible conversation and records an audit event' do
    original_attributes = conversation.attributes.slice('status', 'assignee_id', 'team_id')

    expect do
      described_class.new(
        pipeline_item: pipeline_item,
        conversation: conversation,
        actor: actor,
        source: 'item_detail'
      ).perform
    end.to change(pipeline_item.conversation_links, :count).by(1)
       .and change(pipeline_item.events.conversation_linked, :count).by(1)

    expect(conversation.reload.attributes.slice('status', 'assignee_id', 'team_id')).to eq(original_attributes)
    expect(pipeline_item.events.last).to have_attributes(
      actor: actor,
      conversation: conversation,
      source: 'item_detail'
    )
  end

  it 'rejects an incompatible contact without writing an event' do
    incompatible_conversation = create(:conversation, account: pipeline_item.account)
    event_count = PipelineItemEvent.count

    expect do
      described_class.new(
        pipeline_item: pipeline_item,
        conversation: incompatible_conversation,
        actor: actor,
        source: 'api'
      ).perform
    end.to raise_error(ActiveRecord::RecordInvalid)
    expect(PipelineItemEvent.count).to eq(event_count)
  end

  it 'returns an existing link without duplicating the link or audit event' do
    existing_link = create(
      :pipeline_item_conversation,
      pipeline_item: pipeline_item,
      conversation: conversation,
      linked_by: actor
    )
    event_count = pipeline_item.events.count

    result = described_class.new(
      pipeline_item: pipeline_item,
      conversation: conversation,
      actor: actor,
      source: 'api'
    ).perform

    expect(result).to eq(existing_link)
    expect(pipeline_item.conversation_links.count).to eq(1)
    expect(pipeline_item.events.count).to eq(event_count)
  end
end
