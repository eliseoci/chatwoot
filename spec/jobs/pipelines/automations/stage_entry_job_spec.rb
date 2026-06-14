require 'rails_helper'

RSpec.describe Pipelines::Automations::StageEntryJob do
  include ActiveJob::TestHelper

  let(:transition) { create(:pipeline_item_stage_transition) }
  let(:item) { transition.pipeline_item }

  it 'evaluates every pipeline rule without executing successful deliveries twice' do
    matching_rule = create(
      :pipeline_automation_rule,
      account: item.account,
      pipeline: item.pipeline,
      target_stage: transition.to_stage
    )
    disabled_rule = create(
      :pipeline_automation_rule,
      account: item.account,
      pipeline: item.pipeline,
      target_stage: transition.to_stage,
      enabled: false
    )

    expect { described_class.perform_now(transition.id) }
      .to change(item.activities, :count).by(1)
      .and change(PipelineAutomationRun, :count).by(2)
    expect { described_class.perform_now(transition.id) }.not_to change(item.activities, :count)
    expect(matching_rule.runs.last).to be_status_succeeded
    expect(disabled_rule.runs.last).to be_status_skipped
  end

  it 'records a failed rule and schedules a bounded retry' do
    create(
      :pipeline_automation_rule,
      account: item.account,
      pipeline: item.pipeline,
      target_stage: transition.to_stage
    )
    allow(Pipelines::Automations::Actions::CreateActivity).to receive(:new).and_raise(StandardError, 'unavailable')

    expect { described_class.perform_now(transition.id) }
      .to have_enqueued_job(described_class)
    expect(PipelineAutomationRun.last).to be_status_failed
  end
end
