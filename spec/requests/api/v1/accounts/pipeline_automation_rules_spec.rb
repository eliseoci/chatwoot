require 'rails_helper'

RSpec.describe 'Pipeline Automation Rules API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:pipeline) { create(:pipeline, :with_stages, account: account) }
  let(:assignee) { create(:user, account: account) }

  it 'allows administrators to configure and list a stage-entry rule' do
    post rules_path,
         params: { pipeline_automation_rule: rule_params },
         headers: administrator.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include(
      'name' => 'Qualified follow-up',
      'pipeline_id' => pipeline.id,
      'target_stage_id' => pipeline.stages.second.id,
      'enabled' => true,
      'conditions' => [{ 'attribute' => 'priority', 'operator' => 'equals', 'value' => 'high' }]
    )
    expect(response.parsed_body.fetch('actions').first).to include(
      'action_type' => 'create_activity',
      'config' => hash_including('title' => 'Call qualified lead')
    )

    get rules_path, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.pluck('id')).to eq([PipelineAutomationRule.last.id])
  end

  it 'allows administrators to pause, resume, and delete a rule' do
    rule = create(:pipeline_automation_rule, account: account, pipeline: pipeline)

    patch "#{rules_path}/#{rule.id}",
          params: { pipeline_automation_rule: { enabled: false } },
          headers: administrator.create_new_auth_token,
          as: :json

    expect(response).to have_http_status(:success)
    expect(rule.reload).not_to be_enabled

    delete "#{rules_path}/#{rule.id}",
           headers: administrator.create_new_auth_token,
           as: :json

    expect(response).to have_http_status(:no_content)
    expect(PipelineAutomationRule.exists?(rule.id)).to be(false)
  end

  it 'returns recent structured action runs for administrators' do
    transition = create(:pipeline_item_stage_transition)
    item = transition.pipeline_item
    rule = create(
      :pipeline_automation_rule,
      account: item.account,
      pipeline: item.pipeline,
      target_stage: transition.to_stage
    )
    run = create(
      :pipeline_automation_run,
      account: item.account,
      pipeline_item: item,
      pipeline_automation_rule: rule,
      stage_transition: transition,
      status: :failed,
      attempt_count: 2,
      error_message: 'Webhook unavailable'
    )
    create(
      :pipeline_automation_action_run,
      account: item.account,
      pipeline_automation_run: run,
      pipeline_automation_action: rule.actions.first,
      status: :failed,
      attempt_count: 2,
      error_message: 'Webhook unavailable'
    )
    administrator = create(:user, account: item.account, role: :administrator)

    get "/api/v1/accounts/#{item.account_id}/pipeline_automation_rules",
        headers: administrator.create_new_auth_token,
        as: :json

    recent_run = response.parsed_body.first.fetch('recent_runs').first
    expect(recent_run).to include(
      'status' => 'failed',
      'attempt_count' => 2,
      'error_message' => 'Webhook unavailable'
    )
    expect(recent_run.fetch('actions').first).to include(
      'status' => 'failed',
      'attempt_count' => 2
    )
  end

  it 'rejects non-administrators and cross-account references' do
    get rules_path, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)

    invalid_params = rule_params.deep_dup
    invalid_params[:actions][0][:config][:assignee_id] = create(:user).id
    post rules_path,
         params: {
           pipeline_automation_rule: invalid_params
         },
         headers: administrator.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(account.pipeline_automation_rules).to be_empty
  end

  def rule_params
    {
      name: 'Qualified follow-up',
      pipeline_id: pipeline.id,
      target_stage_id: pipeline.stages.second.id,
      enabled: true,
      trigger_type: 'pipeline_item_stage_changed',
      conditions: [{ attribute: 'priority', operator: 'equals', value: 'high' }],
      actions: [activity_action_params]
    }
  end

  def activity_action_params
    {
      position: 0,
      action_type: 'create_activity',
      config: {
        title: 'Call qualified lead',
        activity_type: 'call',
        assignee_id: assignee.id,
        due_mode: 'relative',
        due_in_minutes: 120
      }
    }
  end

  def rules_path
    "/api/v1/accounts/#{account.id}/pipeline_automation_rules"
  end
end
