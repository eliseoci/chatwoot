require 'rails_helper'

RSpec.describe Pipeline do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to have_many(:stages).class_name('PipelineStage').dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:pipeline) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:account_id) }
    it { is_expected.to validate_inclusion_of(:template_key).in_array(described_class::TEMPLATE_KEYS) }
  end

  it 'returns stages in workflow order' do
    pipeline = create(:pipeline)
    create(:pipeline_stage, pipeline: pipeline, account: pipeline.account, position: 1)
    first_stage = create(:pipeline_stage, pipeline: pipeline, account: pipeline.account, position: 0)

    expect(pipeline.stages.reload.first).to eq(first_stage)
  end
end
