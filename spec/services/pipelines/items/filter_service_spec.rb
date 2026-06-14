require 'rails_helper'

RSpec.describe Pipelines::Items::FilterService do
  let(:account) { create(:account) }
  let(:pipeline) { create(:pipeline, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Acme Corp') }
  let(:item) { create(:pipeline_item, account: account, pipeline: pipeline, contact: contact, title: 'Renewal') }
  let(:scope) { account.pipeline_items }

  it 'filters searchable contact and item fields' do
    item
    create(:pipeline_item, account: account, title: 'Unrelated')

    expect(filtered(q: 'acme')).to contain_exactly(item)
    expect(filtered(q: 'renew')).to contain_exactly(item)
  end

  it 'filters ownership, stage, and team assignments' do
    owner = create(:user, account: account)
    team = create(:team, account: account)
    item.update!(owner: owner, team: team)
    unassigned = create(:pipeline_item, account: account)

    expect(filtered(owner_id: owner.id)).to contain_exactly(item)
    expect(filtered(team_id: team.id)).to contain_exactly(item)
    expect(filtered(stage_id: item.stage_id)).to include(item)
    expect(filtered(owner_id: 'unassigned')).to include(unassigned)
  end

  it 'filters linked inboxes, channels, and exact labels' do
    conversation = create(:conversation, account: account, contact: contact)
    conversation.update!(label_list: %w[vip renewal])
    create(
      :pipeline_item_conversation,
      account: account,
      pipeline_item: item,
      conversation: conversation
    )

    expect(filtered(inbox_id: conversation.inbox_id)).to contain_exactly(item)
    expect(filtered(channel: conversation.inbox.channel_type)).to contain_exactly(item)
    expect(filtered(label: 'vip')).to contain_exactly(item)
    expect(filtered(label: 'vi')).to be_empty
  end

  it 'filters overdue, upcoming, and missing next activities' do
    overdue_item = item
    upcoming_item = create(:pipeline_item, account: account)
    missing_item = create(:pipeline_item, account: account)
    create(
      :pipeline_activity,
      account: account,
      pipeline_item: overdue_item,
      due_at: 1.hour.ago
    )
    create(
      :pipeline_activity,
      account: account,
      pipeline_item: upcoming_item,
      due_at: 1.hour.from_now
    )

    expect(filtered(due_state: 'overdue')).to contain_exactly(overdue_item)
    expect(filtered(due_state: 'upcoming')).to contain_exactly(upcoming_item)
    expect(filtered(due_state: 'missing')).to contain_exactly(missing_item)
  end

  def filtered(params)
    described_class.new(scope: scope, params: params).perform
  end
end
