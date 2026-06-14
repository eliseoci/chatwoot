class Pipelines::Automations::Actions::SendWebhook
  def initialize(action:, action_run:, pipeline_item:)
    @action = action
    @action_run = action_run
    @pipeline_item = pipeline_item
  end

  def perform
    Webhooks::Trigger.execute(
      action.config.fetch('url'),
      payload,
      :pipeline_automation_webhook,
      secret: action.secret,
      delivery_id: delivery_id
    )
    { delivery_id: delivery_id, url: action.config.fetch('url') }
  end

  private

  attr_reader :action, :action_run, :pipeline_item

  def delivery_id
    "pipeline-automation-action-run-#{action_run.id}"
  end

  def payload
    {
      event: 'pipeline.automation',
      account: { id: pipeline_item.account_id },
      pipeline_item: {
        id: pipeline_item.id,
        pipeline_id: pipeline_item.pipeline_id,
        stage_id: pipeline_item.stage_id,
        contact_id: pipeline_item.contact_id
      },
      automation: {
        rule_id: action.pipeline_automation_rule_id,
        action_id: action.id,
        action_run_id: action_run.id
      }
    }
  end
end
