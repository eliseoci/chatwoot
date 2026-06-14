require 'rails_helper'

RSpec.describe Pipelines::Automations::Actions::CreateActivity do
  let(:item) { create(:pipeline_item) }
  let(:rule) do
    create(
      :pipeline_automation_rule,
      account: item.account,
      pipeline: item.pipeline,
      target_stage: item.stage
    )
  end
  let(:action) { rule.actions.first }
  let(:action_run) { instance_double(PipelineAutomationActionRun) }

  it 'supports a fixed due time without sending a customer message' do
    action.update!(
      config: {
        title: 'Prepare proposal',
        activity_type: 'task',
        due_mode: 'fixed',
        due_at: '2099-06-15T09:30:00-03:00'
      }
    )

    message_count = Message.count
    expect do
      described_class.new(
        action: action,
        action_run: action_run,
        pipeline_item: item
      ).perform
    end.to change(item.activities, :count).by(1)

    expect(item.activities.last.due_at).to eq(Time.zone.parse('2099-06-15T12:30:00Z'))
    expect(Message.count).to eq(message_count)
  end
end
