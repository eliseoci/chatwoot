require 'rails_helper'

RSpec.describe PipelineItemConversation do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:pipeline_item) }
    it { is_expected.to belong_to(:conversation) }
    it { is_expected.to belong_to(:linked_by).class_name('User') }
  end

  describe 'validations' do
    subject { create(:pipeline_item_conversation) }

    it { is_expected.to validate_uniqueness_of(:conversation_id).scoped_to(:pipeline_item_id) }

    it 'rejects a conversation from another account' do
      link = build(:pipeline_item_conversation, conversation: create(:conversation))

      expect(link).not_to be_valid
      expect(link.errors[:conversation]).to be_present
    end

    it 'rejects a conversation for another contact' do
      pipeline_item = create(:pipeline_item)
      conversation = create(:conversation, account: pipeline_item.account)
      link = build(
        :pipeline_item_conversation,
        account: pipeline_item.account,
        pipeline_item: pipeline_item,
        conversation: conversation
      )

      expect(link).not_to be_valid
      expect(link.errors[:conversation]).to be_present
    end

    it 'rejects an actor outside the account' do
      pipeline_item = create(:pipeline_item)
      conversation = create(
        :conversation,
        account: pipeline_item.account,
        contact: pipeline_item.contact
      )
      link = build(
        :pipeline_item_conversation,
        account: pipeline_item.account,
        pipeline_item: pipeline_item,
        conversation: conversation,
        linked_by: create(:user)
      )

      expect(link).not_to be_valid
      expect(link.errors[:linked_by]).to be_present
    end
  end

  it 'does not delete the linked conversation when the item is deleted' do
    link = create(:pipeline_item_conversation)
    conversation = link.conversation

    link.pipeline_item.destroy!

    expect(conversation.reload).to be_present
  end
end
