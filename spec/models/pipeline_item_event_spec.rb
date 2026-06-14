require 'rails_helper'

RSpec.describe PipelineItemEvent do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:pipeline_item) }
    it { is_expected.to belong_to(:conversation).optional }
    it { is_expected.to belong_to(:actor).class_name('User').optional }
    it { is_expected.to belong_to(:pipeline_activity).optional }
  end

  describe 'validations' do
    it 'rejects records that mix accounts' do
      pipeline_item = create(:pipeline_item)
      event = build(
        :pipeline_item_event,
        account: pipeline_item.account,
        pipeline_item: pipeline_item,
        conversation: create(:conversation),
        actor: create(:user, account: pipeline_item.account)
      )

      expect(event).not_to be_valid
      expect(event.errors[:conversation]).to be_present
    end

    it 'rejects an activity from another item in the same account' do
      pipeline_item = create(:pipeline_item)
      other_item = create(:pipeline_item, account: pipeline_item.account)
      event = build(
        :pipeline_item_event,
        account: pipeline_item.account,
        pipeline_item: pipeline_item,
        pipeline_activity: create(
          :pipeline_activity,
          account: other_item.account,
          pipeline_item: other_item
        ),
        conversation: nil
      )

      expect(event).not_to be_valid
      expect(event.errors[:pipeline_activity]).to be_present
    end
  end
end
