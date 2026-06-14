require 'rails_helper'

RSpec.describe PipelineItemStageTransition do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:pipeline_item) }
    it { is_expected.to belong_to(:from_stage).class_name('PipelineStage') }
    it { is_expected.to belong_to(:to_stage).class_name('PipelineStage') }
    it { is_expected.to belong_to(:actor).class_name('User') }
  end

  describe 'validations' do
    subject { create(:pipeline_item_stage_transition) }

    it { is_expected.to validate_inclusion_of(:source).in_array(described_class::SOURCES) }

    it 'rejects stages outside the item pipeline' do
      transition = create(:pipeline_item_stage_transition)
      transition.to_stage = create(:pipeline_stage)

      expect(transition).not_to be_valid
      expect(transition.errors[:to_stage]).to be_present
    end

    it 'rejects actors outside the item account' do
      transition = create(:pipeline_item_stage_transition)
      transition.actor = create(:user)

      expect(transition).not_to be_valid
      expect(transition.errors[:actor]).to be_present
    end
  end
end
