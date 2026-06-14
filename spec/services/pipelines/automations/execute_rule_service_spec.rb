require 'rails_helper'

RSpec.describe Pipelines::Automations::ExecuteRuleService do
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

  def execute
    described_class.new(rule: rule, stage_transition: transition).perform
  end

  it 'creates one assigned activity and one successful run across duplicate delivery' do
    assignee = create(:user, account: item.account)
    action = rule.actions.first
    action.update!(config: action.config.merge('assignee_id' => assignee.id))

    expect { execute }.to change(item.activities, :count).by(1).and change(PipelineAutomationRun, :count).by(1)
    expect { execute }.not_to change(item.activities, :count)

    run = rule.runs.reload.last
    expect(run).to have_attributes(status: 'succeeded', attempt_count: 1)
    expect(run.action_runs.first).to have_attributes(status: 'succeeded', attempt_count: 1)
    expect(run.pipeline_activity).to have_attributes(
      title: 'Follow up with customer',
      assignee: assignee
    )
    expect(Message.count).to eq(0)
  end

  it 'records disabled and nonmatching rules as skipped without creating work' do
    rule.update!(enabled: false)

    expect { execute }.not_to change(item.activities, :count)
    expect(rule.runs.reload.last).to have_attributes(status: 'skipped', skip_reason: 'disabled')
  end

  it 'preserves successful actions while retrying a partial failure', :aggregate_failures do
    webhook_action = rule.actions.create!(
      account: item.account,
      position: 1,
      action_type: :send_webhook,
      config: { url: 'https://example.com/pipeline-events' },
      secret: 'signing-secret'
    )
    allow(Webhooks::Trigger).to receive(:execute).and_raise(StandardError, 'temporary failure')

    expect { execute }.to raise_error(StandardError, 'temporary failure')
    run = rule.runs.reload.last
    expect(run).to have_attributes(status: 'failed', attempt_count: 1)
    expect(run.action_runs.order(:id).pluck(:status)).to eq(%w[succeeded failed])
    expect(item.activities.count).to eq(1)

    allow(Webhooks::Trigger).to receive(:execute)

    expect { execute }.not_to change(item.activities, :count)
    expect(run.reload).to have_attributes(status: 'succeeded', attempt_count: 2)
    expect(run.action_runs.find_by(pipeline_automation_action: webhook_action))
      .to have_attributes(status: 'succeeded', attempt_count: 2)
    expect(Webhooks::Trigger).to have_received(:execute).with(
      'https://example.com/pipeline-events',
      hash_including(event: 'pipeline.automation'),
      :pipeline_automation_webhook,
      secret: 'signing-secret',
      delivery_id: "pipeline-automation-action-run-#{run.action_runs.find_by(pipeline_automation_action: webhook_action).id}"
    ).twice
  end
end
