require 'rails_helper'

RSpec.describe Pipelines::Activities::LifecycleService do
  let(:item) { create(:pipeline_item) }
  let(:actor) { create(:user, account: item.account) }
  let(:assignee) { create(:user, account: item.account) }
  let(:service) { described_class.new(pipeline_item: item, actor: actor, source: 'item_detail') }

  it 'creates an activity and its audit event atomically' do
    expect do
      service.create(
        attributes: {
          activity_type: :call,
          title: 'Qualification call',
          due_at: 1.hour.from_now,
          notes: 'Ask about budget.'
        },
        assignee: assignee
      )
    end.to change(PipelineActivity, :count).by(1).and change(PipelineItemEvent, :count).by(1)

    activity = item.activities.last
    expect(activity).to have_attributes(assignee: assignee, created_by: actor, activity_type: 'call')
    expect(item.events.last).to have_attributes(
      event_type: 'activity_created',
      actor: actor,
      pipeline_activity: activity,
      source: 'item_detail'
    )
    expect(item.events.last.metadata).to include(
      'title' => 'Qualification call',
      'activity_type' => 'call',
      'assignee_id' => assignee.id
    )
  end

  it 'updates only scheduled work and records the change' do
    activity = create(:pipeline_activity, pipeline_item: item, account: item.account)

    service.update(
      activity: activity,
      attributes: {
        title: 'Updated follow-up',
        due_at: 2.days.from_now,
        assignee: nil
      }
    )

    expect(activity.reload).to have_attributes(title: 'Updated follow-up', assignee: nil)
    expect(item.events.last.event_type).to eq('activity_updated')
  end

  it 'completes an activity idempotently' do
    activity = create(:pipeline_activity, pipeline_item: item, account: item.account)

    expect { service.complete(activity: activity) }.to change(PipelineItemEvent, :count).by(1)
    expect { service.complete(activity: activity.reload) }.not_to change(PipelineItemEvent, :count)

    expect(activity.reload).to be_status_completed
    expect(activity.completed_at).to be_present
  end

  it 'cancels an activity and prevents later edits' do
    activity = create(:pipeline_activity, pipeline_item: item, account: item.account)
    service.cancel(activity: activity)

    expect do
      service.update(
        activity: activity.reload,
        attributes: { title: 'Too late', assignee: assignee }
      )
    end.to raise_error(ActiveRecord::RecordInvalid)

    expect(activity.reload).to be_status_canceled
    expect(item.events.last.event_type).to eq('activity_canceled')
  end

  it 'rolls back the activity when the event is invalid' do
    invalid_service = described_class.new(
      pipeline_item: item,
      actor: actor,
      source: 'invalid'
    )

    expect do
      invalid_service.create(
        attributes: { title: 'Call', due_at: 1.hour.from_now },
        assignee: assignee
      )
    end.to raise_error(ActiveRecord::RecordInvalid)
      .and not_change(PipelineActivity, :count)
  end
end
