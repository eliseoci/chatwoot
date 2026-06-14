require 'rails_helper'

RSpec.describe PipelineFieldDefinition do
  it 'generates a stable unique key inside the pipeline' do
    pipeline = create(:pipeline)
    first = create(:pipeline_field_definition, pipeline: pipeline, account: pipeline.account, label: 'Contract value')
    second = create(:pipeline_field_definition, pipeline: pipeline, account: pipeline.account, label: 'Contract value')

    expect(first.key).to eq('contract_value')
    expect(second.key).to eq('contract_value_2')
  end

  it 'validates type-specific settings' do
    list = build(:pipeline_field_definition, field_type: :list, settings: { choices: %w[Duplicate Duplicate] })
    currency = build(:pipeline_field_definition, field_type: :currency, settings: { currency: 'dollars' })

    expect(list).not_to be_valid
    expect(currency).not_to be_valid
  end

  it 'rejects a pipeline from another account' do
    definition = build(
      :pipeline_field_definition,
      account: create(:account),
      pipeline: create(:pipeline)
    )

    expect(definition).not_to be_valid
    expect(definition.errors[:account]).to be_present
  end

  it 'keeps the field type immutable' do
    definition = create(:pipeline_field_definition)

    expect(definition.update(field_type: :date)).to be(false)
    expect(definition.errors[:field_type]).to be_present
  end
end
