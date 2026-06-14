require 'rails_helper'

RSpec.describe Pipelines::Automations::RuleEvaluator do
  let(:transition) { create(:pipeline_item_stage_transition) }
  let(:item) { transition.pipeline_item }
  let(:rule) do
    create(
      :pipeline_automation_rule,
      account: item.account,
      pipeline: item.pipeline,
      target_stage: transition.to_stage
    )
  end

  def evaluate
    described_class.new(rule: rule, stage_transition: transition).perform
  end

  it 'matches enabled target-stage rules with satisfied conditions' do
    item.update!(priority: :high)
    rule.update!(conditions: [{ attribute: 'priority', operator: 'equals', value: 'high' }])

    expect(evaluate).to have_attributes(matched?: true, reason: nil)
  end

  it 'inspects stage, contact, inbox, channel, labels, and activity state' do
    conversation = create(:conversation, account: item.account, contact: item.contact)
    create(:label, account: item.account, title: 'vip')
    conversation.update!(label_list: %w[vip renewal])
    create(
      :pipeline_item_conversation,
      account: item.account,
      pipeline_item: item,
      conversation: conversation
    )
    create(
      :pipeline_activity,
      account: item.account,
      pipeline_item: item,
      due_at: 1.hour.ago
    )
    rule.update!(
      conditions: [
        { attribute: 'stage_id', operator: 'equals', value: transition.to_stage_id },
        { attribute: 'contact_id', operator: 'equals', value: item.contact_id },
        { attribute: 'inbox_id', operator: 'equals', value: conversation.inbox_id },
        { attribute: 'channel', operator: 'equals', value: conversation.inbox.channel_type },
        { attribute: 'label', operator: 'equals', value: 'vip' },
        { attribute: 'activity_state', operator: 'equals', value: 'overdue' }
      ]
    )

    expect(evaluate).to have_attributes(matched?: true, reason: nil)
  end

  it 'skips disabled, nonmatching, and unsatisfied rules with explicit reasons' do
    rule.update!(enabled: false)
    expect(evaluate.reason).to eq('disabled')

    rule.update!(enabled: true, target_stage: item.pipeline.stages.first)
    expect(evaluate.reason).to eq('target_stage_mismatch')

    rule.update!(
      target_stage: transition.to_stage,
      conditions: [{ attribute: 'priority', operator: 'equals', value: 'urgent' }]
    )
    expect(evaluate.reason).to eq('conditions_not_met')
  end
end
