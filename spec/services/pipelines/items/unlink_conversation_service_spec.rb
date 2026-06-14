require 'rails_helper'

RSpec.describe Pipelines::Items::UnlinkConversationService do
  let(:conversation_link) { create(:pipeline_item_conversation) }
  let(:pipeline_item) { conversation_link.pipeline_item }
  let(:conversation) { conversation_link.conversation }
  let(:actor) { create(:user, account: pipeline_item.account) }

  it 'removes only the link and records an audit event' do
    expect do
      described_class.new(
        pipeline_item: pipeline_item,
        conversation: conversation,
        actor: actor,
        source: 'item_detail'
      ).perform
    end.to change(pipeline_item.conversation_links, :count).by(-1)
       .and change(pipeline_item.events.conversation_unlinked, :count).by(1)

    expect(conversation.reload).to be_present
    expect(pipeline_item.events.last).to have_attributes(
      actor: actor,
      conversation: conversation,
      source: 'item_detail'
    )
  end

  it 'rejects an unlink when no active link exists' do
    conversation_link.destroy!

    expect do
      described_class.new(
        pipeline_item: pipeline_item,
        conversation: conversation,
        actor: actor,
        source: 'api'
      ).perform
    end.to raise_error(ActiveRecord::RecordNotFound)
  end
end
