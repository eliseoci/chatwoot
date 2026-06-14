require 'rails_helper'

RSpec.describe PipelineAutomationRule do
  let(:account) { create(:account) }
  let(:pipeline) { create(:pipeline, :with_stages, account: account) }

  it 'accepts a stage-entry activity rule with optional conditions' do
    rule = build(
      :pipeline_automation_rule,
      account: account,
      pipeline: pipeline,
      target_stage: pipeline.stages.second,
      conditions: [{ attribute: 'priority', operator: 'equals', value: 'high' }]
    )

    expect(rule).to be_valid
  end

  it 'rejects cross-account stages' do
    rule = build(
      :pipeline_automation_rule,
      target_stage: create(:pipeline_stage)
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:target_stage]).to be_present
  end

  it 'validates supported condition configuration' do
    rule = build(
      :pipeline_automation_rule,
      conditions: [{ attribute: 'unsupported', operator: 'equals', value: 'x' }]
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:conditions]).to be_present
  end

  it 'requires at least one ordered action' do
    rule = build(
      :pipeline_automation_rule,
      account: account,
      pipeline: pipeline,
      target_stage: pipeline.stages.second
    )
    rule.actions.clear

    expect(rule).not_to be_valid
    expect(rule.errors[:actions]).to be_present
  end
end
