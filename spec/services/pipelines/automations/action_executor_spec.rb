require 'rails_helper'

RSpec.describe Pipelines::Automations::ActionExecutor do
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
  let(:run) do
    create(
      :pipeline_automation_run,
      account: item.account,
      pipeline_item: item,
      pipeline_automation_rule: rule,
      stage_transition: transition
    )
  end

  def perform(action)
    action_run = create(
      :pipeline_automation_action_run,
      account: item.account,
      pipeline_automation_run: run,
      pipeline_automation_action: action
    )
    described_class.new(
      action: action,
      action_run: action_run,
      pipeline_item: item
    ).perform
  end

  it 'assigns an owner and team with structured results' do
    owner = create(:user, account: item.account)
    team = create(:team, account: item.account)
    owner_action = create_action(:assign_owner, owner_id: owner.id)
    team_action = create_action(:assign_team, team_id: team.id)

    expect(perform(owner_action)).to include(owner_id: owner.id)
    expect(perform(team_action)).to include(team_id: team.id)
    expect(item.reload).to have_attributes(owner: owner, team: team)
  end

  it 'updates a pipeline custom field through the field lifecycle service' do
    field = create(:pipeline_field_definition, account: item.account, pipeline: item.pipeline)
    action = create_action(:update_field, field_key: field.key, value: 'Qualified')

    expect(perform(action)).to include(field_key: field.key, value: 'Qualified')
    expect(item.reload.field_values).to include(field.key => 'Qualified')
  end

  it 'adds and removes labels without replacing unrelated conversation labels' do
    conversation = create(:conversation, account: item.account, contact: item.contact)
    conversation.update!(label_list: %w[existing remove-me])
    create(
      :pipeline_item_conversation,
      account: item.account,
      pipeline_item: item,
      conversation: conversation
    )
    create(:label, account: item.account, title: 'vip')
    create(:label, account: item.account, title: 'remove-me')

    perform(create_action(:add_labels, labels: ['vip']))
    expect(conversation.reload.label_list).to contain_exactly('existing', 'remove-me', 'vip')

    perform(create_action(:remove_labels, labels: ['remove-me']))
    expect(conversation.reload.label_list).to contain_exactly('existing', 'vip')
  end

  it 'creates an in-app operator notification without sending a customer message' do
    recipient = create(:user, account: item.account)
    action = create_action(
      :send_internal_notification,
      recipient_id: recipient.id,
      message: 'Review this qualified lead'
    )

    expect { perform(action) }
      .to change(recipient.notifications, :count).by(1)
      .and not_change(Message, :count)
    notification = recipient.notifications.last
    expect(notification).to have_attributes(
      notification_type: 'pipeline_item_notification',
      primary_actor: item
    )
    expect(notification.meta).to include('message' => 'Review this qualified lead')
  end

  it 'marks and clears explicit attention state' do
    mark_action = create_action(
      :update_attention,
      state: 'required',
      note: 'Review before sending proposal'
    )
    clear_action = create_action(:update_attention, state: 'cleared')

    expect(perform(mark_action)).to include(attention_required: true)
    expect(item.reload).to have_attributes(
      attention_required: true,
      attention_note: 'Review before sending proposal'
    )

    expect(perform(clear_action)).to include(attention_required: false)
    expect(item.reload).to have_attributes(attention_required: false, attention_note: nil)
  end

  private

  def create_action(action_type, config)
    rule.actions.create!(
      account: item.account,
      position: rule.actions.maximum(:position).to_i + 1,
      action_type: action_type,
      config: config
    )
  end
end
