class Pipelines::Automations::ActionExecutor
  ACTIONS = {
    'create_activity' => Pipelines::Automations::Actions::CreateActivity,
    'assign_owner' => Pipelines::Automations::Actions::AssignOwner,
    'assign_team' => Pipelines::Automations::Actions::AssignTeam,
    'update_field' => Pipelines::Automations::Actions::UpdateField,
    'add_labels' => Pipelines::Automations::Actions::AddLabels,
    'remove_labels' => Pipelines::Automations::Actions::RemoveLabels,
    'send_internal_notification' => Pipelines::Automations::Actions::SendInternalNotification,
    'send_webhook' => Pipelines::Automations::Actions::SendWebhook,
    'update_attention' => Pipelines::Automations::Actions::UpdateAttention
  }.freeze

  def initialize(action:, action_run:, pipeline_item:)
    @action = action
    @action_run = action_run
    @pipeline_item = pipeline_item
  end

  def perform
    ACTIONS.fetch(action.action_type).new(
      action: action,
      action_run: action_run,
      pipeline_item: pipeline_item
    ).perform
  end

  private

  attr_reader :action, :action_run, :pipeline_item
end
