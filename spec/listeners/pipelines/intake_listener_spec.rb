require 'rails_helper'

RSpec.describe Pipelines::IntakeListener do
  include ActiveJob::TestHelper

  let(:conversation) { create(:conversation) }
  let(:event) do
    Events::Base.new(
      Events::Types::CONVERSATION_CREATED,
      Time.current,
      conversation: conversation
    )
  end

  it 'enqueues intake when the account has an enabled rule' do
    create(:pipeline_intake_rule, account: conversation.account)

    expect do
      described_class.instance.conversation_created(event)
    end.to have_enqueued_job(Pipelines::IntakeConversationJob)
      .with(conversation.account_id, conversation.id)
  end

  it 'does not enqueue intake without an enabled rule' do
    create(:pipeline_intake_rule, account: conversation.account, enabled: false)

    expect do
      described_class.instance.conversation_created(event)
    end.not_to have_enqueued_job(Pipelines::IntakeConversationJob)
  end
end
