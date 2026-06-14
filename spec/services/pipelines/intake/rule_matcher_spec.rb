require 'rails_helper'

RSpec.describe Pipelines::Intake::RuleMatcher do
  let(:conversation) { create(:conversation) }

  it 'returns the first enabled matching rule' do
    create(
      :pipeline_intake_rule,
      account: conversation.account,
      inbox: conversation.inbox,
      position: 2
    )
    expected_rule = create(
      :pipeline_intake_rule,
      account: conversation.account,
      channel_type: conversation.inbox.channel_type,
      position: 1
    )

    expect(described_class.new(conversation: conversation).perform).to eq(expected_rule)
  end

  it 'ignores disabled and non-matching rules' do
    create(
      :pipeline_intake_rule,
      account: conversation.account,
      enabled: false
    )
    create(
      :pipeline_intake_rule,
      account: conversation.account,
      channel_type: 'Channel::Email'
    )

    expect(described_class.new(conversation: conversation).perform).to be_nil
  end
end
