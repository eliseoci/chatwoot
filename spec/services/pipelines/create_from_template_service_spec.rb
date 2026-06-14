require 'rails_helper'

RSpec.describe Pipelines::CreateFromTemplateService do
  let(:account) { create(:account) }

  it 'creates an editable pipeline and ordered stages from a predefined template' do
    pipeline = described_class.new(
      account: account,
      attributes: { name: 'Sales', description: 'New business', template_key: 'sales' }
    ).perform

    expect(pipeline).to be_persisted
    expect(pipeline.stages.pluck(:name)).to eq(['New lead', 'Qualified', 'Proposal', 'Won', 'Lost'])
    expect(pipeline.stages.last).to be_terminal
    expect(pipeline.stages.last.outcome_key).to eq('lost')
  end

  it 'creates a custom pipeline from supplied stages' do
    pipeline = described_class.new(
      account: account,
      attributes: {
        name: 'Renewals',
        template_key: 'custom',
        stages: [{ name: 'Upcoming' }, { name: 'Renewed', terminal: true, outcome_key: 'renewed' }]
      }
    ).perform

    expect(pipeline.stages.pluck(:name, :position)).to eq([['Upcoming', 0], ['Renewed', 1]])
    expect(pipeline.stages.last.outcome_key).to eq('renewed')
  end

  it 'rejects a custom pipeline without stages' do
    service = described_class.new(
      account: account,
      attributes: { name: 'Empty', template_key: 'custom', stages: [] }
    )

    expect { service.perform }.to raise_error(ActiveRecord::RecordInvalid, /Add at least one stage/)
    expect(Pipeline.exists?).to be(false)
  end
end
