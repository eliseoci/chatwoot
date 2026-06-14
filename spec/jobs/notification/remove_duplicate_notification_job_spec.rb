require 'rails_helper'

RSpec.describe Notification::RemoveDuplicateNotificationJob do
  let(:user) { create(:user) }
  let(:conversation) { create(:conversation) }

  it 'enqueues the job' do
    duplicate_notification = create(:notification, user: user, notification_type: 'conversation_creation', primary_actor: conversation)
    expect do
      described_class.perform_later(duplicate_notification)
    end.to have_enqueued_job(described_class)
      .on_queue('default')
  end

  it 'removes duplicate notifications' do
    create(:notification, user: user, notification_type: 'conversation_creation', primary_actor: conversation)
    duplicate_notification = create(:notification, user: user, notification_type: 'conversation_creation', primary_actor: conversation)

    described_class.perform_now(duplicate_notification)
    expect(Notification.count).to eq(1)
  end

  it 'does not remove a different primary actor type with the same numeric id' do
    conversation_notification = create(
      :notification,
      user: user,
      notification_type: 'conversation_creation',
      primary_actor: conversation
    )
    pipeline_notification = create(
      :notification,
      user: user,
      account: conversation_notification.account,
      notification_type: 'pipeline_item_notification',
      primary_actor: create(:pipeline_item, account: conversation_notification.account)
    )
    pipeline_notification.update_column(:primary_actor_id, conversation.id)

    described_class.perform_now(conversation_notification)

    expect(Notification.exists?(pipeline_notification.id)).to be(true)
  end
end
