require 'rails_helper'

RSpec.describe Pipelines::Items::UpdateFieldValuesService do
  let(:item) { create(:pipeline_item) }
  let(:actor) { create(:user, account: item.account) }
  let(:referenced_user) { create(:user, account: item.account) }
  let(:definitions) do
    [
      create(:pipeline_field_definition, pipeline: item.pipeline, account: item.account, label: 'Summary'),
      create_definition('Score', :number),
      create(:pipeline_field_definition, :currency, pipeline: item.pipeline, account: item.account, label: 'Budget'),
      create_definition('Renewal', :date),
      create_definition('Approved', :boolean),
      create(:pipeline_field_definition, :list, pipeline: item.pipeline, account: item.account, label: 'Segment'),
      create_definition('Brief', :link),
      create_definition('Sponsor', :user_reference)
    ]
  end
  let(:values) do
    definitions.map(&:key).zip(
      [' Ready ', '12.50', '1250.75', '2026-07-01', false, 'New', 'https://example.com/brief', referenced_user.id]
    ).to_h
  end
  let(:normalized_values) do
    definitions.map(&:key).zip(
      ['Ready', '12.5', '1250.75', '2026-07-01', false, 'New', 'https://example.com/brief', referenced_user.id]
    ).to_h
  end

  def perform(values)
    described_class.new(
      pipeline_item: item,
      values: values,
      actor: actor,
      source: 'item_detail'
    ).perform
  end

  it 'normalizes supported values and records changed keys' do
    expect { perform(values) }.to change(item.events.field_values_updated, :count).by(1)

    expect(item.reload.field_values).to eq(normalized_values)
    expect(item.events.last.metadata['changed_field_keys']).to match_array(definitions.map(&:key))
  end

  it 'removes blank values without deleting values for omitted fields' do
    first = create(:pipeline_field_definition, pipeline: item.pipeline, account: item.account, label: 'First')
    second = create(:pipeline_field_definition, pipeline: item.pipeline, account: item.account, label: 'Second')
    item.update!(field_values: { first.key => 'One', second.key => 'Two' })

    perform(first.key => '')

    expect(item.reload.field_values).to eq(second.key => 'Two')
  end

  it 'rejects unknown, archived, invalid list, and cross-account user values' do
    list = create(:pipeline_field_definition, :list, pipeline: item.pipeline, account: item.account)
    archived = create(
      :pipeline_field_definition,
      pipeline: item.pipeline,
      account: item.account,
      archived_at: Time.current
    )
    user_reference = create(
      :pipeline_field_definition,
      pipeline: item.pipeline,
      account: item.account,
      field_type: :user_reference
    )

    expect { perform(unknown: 'value') }.to raise_error(ActiveRecord::RecordInvalid)
    expect { perform(archived.key => 'value') }.to raise_error(ActiveRecord::RecordInvalid)
    expect { perform(list.key => 'Unavailable') }.to raise_error(ActiveRecord::RecordInvalid)
    expect { perform(user_reference.key => create(:user).id) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(item.reload.field_values).to be_empty
  end

  def create_definition(label, field_type)
    create(
      :pipeline_field_definition,
      pipeline: item.pipeline,
      account: item.account,
      label: label,
      field_type: field_type
    )
  end
end
