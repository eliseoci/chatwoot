require 'rails_helper'

RSpec.describe PipelineIntakeRule do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:pipeline) }
    it { is_expected.to belong_to(:initial_stage).class_name('PipelineStage') }
    it { is_expected.to belong_to(:inbox).optional }
  end

  describe 'validations' do
    it 'rejects a stage outside the selected pipeline' do
      rule = build(:pipeline_intake_rule)
      rule.initial_stage = create(:pipeline_stage, account: rule.account)

      expect(rule).not_to be_valid
      expect(rule.errors[:initial_stage]).to be_present
    end

    it 'rejects an inbox from another account' do
      account = create(:account)
      pipeline = create(:pipeline, :with_stages, account: account)
      rule = build(
        :pipeline_intake_rule,
        account: account,
        pipeline: pipeline,
        initial_stage: pipeline.stages.first,
        inbox: create(:inbox)
      )

      expect(rule).not_to be_valid
      expect(rule.errors[:inbox]).to be_present
    end
  end

  describe '#matches?' do
    let(:conversation) { create(:conversation) }

    it 'matches all conversations when no filters are configured' do
      rule = build(
        :pipeline_intake_rule,
        account: conversation.account,
        inbox: nil,
        channel_type: nil
      )

      expect(rule.matches?(conversation)).to be(true)
    end

    it 'requires every configured inbox and channel filter to match' do
      rule = build(
        :pipeline_intake_rule,
        account: conversation.account,
        inbox: conversation.inbox,
        channel_type: conversation.inbox.channel_type
      )

      expect(rule.matches?(conversation)).to be(true)
      rule.channel_type = 'Channel::Email'
      expect(rule.matches?(conversation)).to be(false)
    end
  end
end
