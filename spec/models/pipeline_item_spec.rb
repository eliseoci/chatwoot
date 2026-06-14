require 'rails_helper'

RSpec.describe PipelineItem do
  let(:account) { create(:account) }
  let(:pipeline) { create(:pipeline, account: account) }
  let(:stage) { create(:pipeline_stage, account: account, pipeline: pipeline) }
  let(:contact) { create(:contact, account: account) }

  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:pipeline) }
    it { is_expected.to belong_to(:stage).class_name('PipelineStage') }
    it { is_expected.to belong_to(:contact) }
    it { is_expected.to belong_to(:owner).class_name('User').optional }
    it { is_expected.to belong_to(:team).optional }
  end

  describe 'validations' do
    subject { create(:pipeline_item) }

    it { is_expected.to validate_numericality_of(:value).is_greater_than_or_equal_to(0).allow_nil }

    it 'rejects a pipeline from another account' do
      item = build_pipeline_item(pipeline: create(:pipeline))

      expect(item).not_to be_valid
      expect(item.errors[:pipeline]).to be_present
    end

    it 'rejects a stage from another account' do
      item = build_pipeline_item(stage: create(:pipeline_stage))

      expect(item).not_to be_valid
      expect(item.errors[:stage]).to be_present
    end

    it 'rejects a stage from another pipeline in the same account' do
      item = build_pipeline_item
      item.stage = create(:pipeline_stage, account: item.account)

      expect(item).not_to be_valid
      expect(item.errors[:stage]).to be_present
    end

    it 'rejects a contact from another account' do
      item = build_pipeline_item(contact: create(:contact))

      expect(item).not_to be_valid
      expect(item.errors[:contact]).to be_present
    end

    it 'rejects an owner from another account' do
      item = build_pipeline_item(owner: create(:user))

      expect(item).not_to be_valid
      expect(item.errors[:owner]).to be_present
    end

    it 'rejects a team from another account' do
      item = build_pipeline_item(team: create(:team))

      expect(item).not_to be_valid
      expect(item.errors[:team]).to be_present
    end
  end

  describe '#display_title' do
    it 'uses the contact name when the optional title is blank' do
      item = build_pipeline_item(title: nil)

      expect(item.display_title).to eq(item.contact.name)
    end
  end

  def build_pipeline_item(attributes = {})
    build(
      :pipeline_item,
      { account: account, pipeline: pipeline, stage: stage, contact: contact }.merge(attributes)
    )
  end
end
