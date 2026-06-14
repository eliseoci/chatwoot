require 'rails_helper'

RSpec.describe PipelineStage do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:pipeline) }
  end

  describe 'validations' do
    subject { build(:pipeline_stage) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_numericality_of(:position).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_uniqueness_of(:position).scoped_to(:pipeline_id) }

    it 'requires an outcome key for terminal stages' do
      stage = build(:pipeline_stage, terminal: true, outcome_key: nil)

      expect(stage).not_to be_valid
      expect(stage.errors[:outcome_key]).to be_present
    end

    it 'rejects an outcome key for active stages' do
      stage = build(:pipeline_stage, terminal: false, outcome_key: 'won')

      expect(stage).not_to be_valid
      expect(stage.errors[:outcome_key]).to be_present
    end

    it 'requires the pipeline and stage to belong to the same account' do
      pipeline = create(:pipeline)
      stage = build(:pipeline_stage, pipeline: pipeline, account: create(:account))

      expect(stage).not_to be_valid
      expect(stage.errors[:account]).to be_present
    end
  end
end
