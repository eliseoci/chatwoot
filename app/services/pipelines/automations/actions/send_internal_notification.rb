class Pipelines::Automations::Actions::SendInternalNotification
  def initialize(action:, action_run:, pipeline_item:)
    @action = action
    @action_run = action_run
    @pipeline_item = pipeline_item
  end

  def perform
    recipient = pipeline_item.account.users.find(action.config.fetch('recipient_id'))
    notification = recipient.notifications.create!(
      account: pipeline_item.account,
      primary_actor: pipeline_item,
      notification_type: :pipeline_item_notification,
      meta: {
        message: action.config.fetch('message'),
        pipeline_automation_action_run_id: action_run.id
      }
    )
    {
      notification_id: notification.id,
      recipient_id: recipient.id
    }
  end

  private

  attr_reader :action, :action_run, :pipeline_item
end
