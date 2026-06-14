require 'rails_helper'

RSpec.describe Pipelines::Items::UpdateOwnershipService do
  let(:item) { create(:pipeline_item) }
  let(:actor) { create(:user, account: item.account) }
  let(:owner) { create(:user, account: item.account) }

  it 'changes ownership and records an immutable audit snapshot' do
    described_class.new(
      pipeline_item: item,
      owner: owner,
      actor: actor,
      source: 'conversation_sidebar'
    ).perform

    expect(item.reload.owner).to eq(owner)
    expect(item.events.last).to have_attributes(
      event_type: 'ownership_changed',
      actor: actor,
      source: 'conversation_sidebar'
    )
    expect(item.events.last.metadata).to include(
      'from_owner_id' => nil,
      'to_owner_id' => owner.id,
      'to_owner_name' => owner.available_name
    )
  end

  it 'is idempotent when the owner is unchanged' do
    item.update!(owner: owner)
    service = described_class.new(pipeline_item: item, owner: owner, actor: actor)

    expect { service.perform }.not_to change(PipelineItemEvent, :count)
  end

  it 'rolls back ownership when the audit event is invalid' do
    service = described_class.new(
      pipeline_item: item,
      owner: owner,
      actor: actor,
      source: 'invalid'
    )

    expect { service.perform }.to raise_error(ActiveRecord::RecordInvalid)
      .and(not_change { item.reload.owner_id })
  end
end
