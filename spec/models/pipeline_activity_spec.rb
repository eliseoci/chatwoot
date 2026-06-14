require 'rails_helper'

RSpec.describe PipelineActivity do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:pipeline_item) }
    it { is_expected.to belong_to(:assignee).class_name('User').optional }
    it { is_expected.to belong_to(:created_by).class_name('User').optional }
    it { is_expected.to have_many(:events).class_name('PipelineItemEvent').dependent(:nullify) }
  end

  describe 'validations' do
    it 'rejects an item from another account' do
      activity = build(
        :pipeline_activity,
        account: create(:account),
        pipeline_item: create(:pipeline_item)
      )

      expect(activity).not_to be_valid
      expect(activity.errors[:pipeline_item]).to be_present
    end

    it 'rejects an assignee from another account' do
      item = create(:pipeline_item)
      activity = build(
        :pipeline_activity,
        account: item.account,
        pipeline_item: item,
        assignee: create(:user)
      )

      expect(activity).not_to be_valid
      expect(activity.errors[:assignee]).to be_present
    end

    it 'requires a terminal timestamp for completed activities' do
      activity = build(:pipeline_activity, status: :completed, completed_at: nil)

      expect(activity).not_to be_valid
      expect(activity.errors[:completed_at]).to be_present
    end
  end

  describe '#overdue?' do
    it 'is true only for scheduled work before the comparison time' do
      activity = build(:pipeline_activity, due_at: Time.zone.parse('2026-06-14 10:00:00'))

      expect(activity.overdue?(at: Time.zone.parse('2026-06-14 10:01:00'))).to be(true)
      activity.status = :completed
      activity.completed_at = Time.current
      expect(activity.overdue?(at: Time.zone.parse('2026-06-14 10:01:00'))).to be(false)
    end
  end
end
