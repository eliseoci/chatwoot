require 'rails_helper'

RSpec.describe PipelineAutomationRun do
  it 'enforces one run for each rule and stage transition' do
    run = create(:pipeline_automation_run)
    duplicate = build(
      :pipeline_automation_run,
      pipeline_automation_rule: run.pipeline_automation_rule,
      stage_transition: run.stage_transition,
      pipeline_item: run.pipeline_item,
      account: run.account
    )

    expect { duplicate.save! }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'rejects records that mix pipeline contexts' do
    run = build(:pipeline_automation_run, pipeline_automation_rule: create(:pipeline_automation_rule))

    expect(run).not_to be_valid
    expect(run.errors[:base]).to be_present
  end
end
