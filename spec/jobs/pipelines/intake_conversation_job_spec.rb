require 'rails_helper'

RSpec.describe Pipelines::IntakeConversationJob do
  let(:conversation) { create(:conversation) }

  it 'applies the first matching rule' do
    rule = create(
      :pipeline_intake_rule,
      account: conversation.account,
      inbox: conversation.inbox
    )

    expect do
      described_class.perform_now(conversation.account_id, conversation.id)
    end.to change(conversation.account.pipeline_items, :count).by(1)

    expect(conversation.account.pipeline_items.last.pipeline).to eq(rule.pipeline)
  end

  it 'does nothing when no rule matches' do
    expect do
      described_class.perform_now(conversation.account_id, conversation.id)
    end.not_to change(PipelineItem, :count)
  end
end
