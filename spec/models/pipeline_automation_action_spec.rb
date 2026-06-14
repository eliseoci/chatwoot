require 'rails_helper'

RSpec.describe PipelineAutomationAction do
  let(:account) { create(:account) }
  let(:pipeline) { create(:pipeline, :with_stages, account: account) }
  let(:rule) do
    create(
      :pipeline_automation_rule,
      account: account,
      pipeline: pipeline,
      target_stage: pipeline.stages.second
    )
  end

  it 'accepts account-scoped assignment actions' do
    owner = create(:user, account: account)
    team = create(:team, account: account)
    actions = [
      build_action(:assign_owner, { owner_id: owner.id }),
      build_action(:assign_team, { team_id: team.id })
    ]

    expect(actions).to all(be_valid)
  end

  it 'accepts account-scoped field and label actions' do
    field = create(:pipeline_field_definition, account: account, pipeline: pipeline)
    create(:label, account: account, title: 'vip')
    actions = [
      build_action(:update_field, { field_key: field.key, value: 'Qualified' }),
      build_action(:add_labels, { labels: ['vip'] })
    ]

    expect(actions).to all(be_valid)
  end

  it 'accepts notification, signed webhook, and attention actions' do
    recipient = create(:user, account: account)
    actions = [
      build_action(
        :send_internal_notification,
        { recipient_id: recipient.id, message: 'Review this item' }
      ),
      build_action(
        :send_webhook,
        { url: 'https://example.com/pipeline-events' },
        secret: 'signing-secret'
      ),
      build_action(
        :update_attention,
        { state: 'required', note: 'Automation requested review' }
      )
    ]

    expect(actions).to all(be_valid)
  end

  it 'rejects cross-account references, unknown labels, and unsigned webhooks' do
    owner_action = build(
      :pipeline_automation_action,
      account: account,
      pipeline_automation_rule: rule,
      action_type: :assign_owner,
      config: { owner_id: create(:user).id }
    )
    label_action = build(
      :pipeline_automation_action,
      account: account,
      pipeline_automation_rule: rule,
      action_type: :add_labels,
      config: { labels: ['missing'] }
    )
    webhook_action = build(
      :pipeline_automation_action,
      account: account,
      pipeline_automation_rule: rule,
      action_type: :send_webhook,
      config: { url: 'https://example.com/pipeline-events' },
      secret: nil
    )

    expect(owner_action).not_to be_valid
    expect(label_action).not_to be_valid
    expect(webhook_action).not_to be_valid
  end

  def build_action(action_type, config, secret: nil)
    build(
      :pipeline_automation_action,
      account: account,
      pipeline_automation_rule: rule,
      action_type: action_type,
      config: config,
      secret: secret
    )
  end
end
