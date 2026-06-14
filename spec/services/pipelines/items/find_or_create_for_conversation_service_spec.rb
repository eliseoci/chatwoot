require 'rails_helper'

RSpec.describe Pipelines::Items::FindOrCreateForConversationService do
  let(:conversation) { create(:conversation, status: :open) }
  let(:intake_rule) do
    create(
      :pipeline_intake_rule,
      account: conversation.account,
      inbox: conversation.inbox
    )
  end

  def perform(allow_parallel: false, actor: nil, source: 'conversation_created')
    described_class.new(
      conversation: conversation,
      intake_rule: intake_rule,
      allow_parallel: allow_parallel,
      actor: actor,
      source: source
    ).perform
  end

  it 'creates and links an item in the configured initial stage' do
    original_status = conversation.status

    expect { perform }.to change(conversation.account.pipeline_items, :count).by(1)

    pipeline_item = conversation.account.pipeline_items.last
    expect(pipeline_item).to have_attributes(
      pipeline: intake_rule.pipeline,
      stage: intake_rule.initial_stage,
      contact: conversation.contact
    )
    expect(pipeline_item.linked_conversations).to contain_exactly(conversation)
    expect(pipeline_item.events.pluck(:event_type)).to include(
      'conversation_linked',
      'automatic_item_created'
    )
    expect(conversation.reload.status).to eq(original_status)
  end

  it 'reuses an active item for the same account, contact, and pipeline' do
    active_item = create(
      :pipeline_item,
      account: conversation.account,
      pipeline: intake_rule.pipeline,
      stage: intake_rule.pipeline.stages.detect { |stage| !stage.terminal? },
      contact: conversation.contact
    )

    expect { perform }.not_to change(conversation.account.pipeline_items, :count)

    expect(active_item.reload.linked_conversations).to contain_exactly(conversation)
    expect(active_item.events.conversation_deduplicated.count).to eq(1)
  end

  it 'creates a new item when prior items are terminal' do
    terminal_stage = intake_rule.pipeline.stages.detect(&:terminal?)
    create(
      :pipeline_item,
      account: conversation.account,
      pipeline: intake_rule.pipeline,
      stage: terminal_stage,
      contact: conversation.contact
    )

    expect { perform }.to change(conversation.account.pipeline_items, :count).by(1)
  end

  it 'creates an explicit parallel item when deduplication is bypassed' do
    actor = create(:user, account: conversation.account)
    create(
      :pipeline_item,
      account: conversation.account,
      pipeline: intake_rule.pipeline,
      stage: intake_rule.initial_stage,
      contact: conversation.contact
    )

    expect do
      perform(allow_parallel: true, actor: actor, source: 'manual_override')
    end.to change(conversation.account.pipeline_items, :count).by(1)

    expect(conversation.account.pipeline_items.last.events.parallel_item_created.count).to eq(1)
  end

  it 'is idempotent when the same conversation is delivered again' do
    first_item = perform

    expect { perform }.not_to change(conversation.account.pipeline_items, :count)
    expect(first_item.reload.conversation_links.count).to eq(1)
    expect(first_item.events.automatic_item_created.count).to eq(1)
  end

  it 'locks the contact before evaluating deduplication' do
    expect(conversation.contact).to receive(:lock!).and_call_original

    perform
  end
end
