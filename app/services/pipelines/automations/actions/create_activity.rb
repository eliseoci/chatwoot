class Pipelines::Automations::Actions::CreateActivity
  def initialize(action:, action_run:, pipeline_item:)
    @action = action
    @action_run = action_run
    @pipeline_item = pipeline_item
  end

  def perform
    activity = Pipelines::Activities::LifecycleService.new(
      pipeline_item: pipeline_item,
      actor: nil,
      source: 'automation'
    ).create(
      attributes: activity_attributes,
      assignee: assignee
    )
    { pipeline_activity_id: activity.id }
  end

  private

  attr_reader :action, :action_run, :pipeline_item

  delegate :config, to: :action

  def activity_attributes
    {
      title: config.fetch('title'),
      activity_type: config.fetch('activity_type'),
      due_at: due_at,
      notes: config['notes'].presence
    }
  end

  def assignee
    assignee_id = config['assignee_id']
    pipeline_item.account.users.find(assignee_id) if assignee_id.present?
  end

  def due_at
    return Time.current + config.fetch('due_in_minutes').to_i.minutes if config['due_mode'] == 'relative'

    Time.zone.parse(config.fetch('due_at'))
  end
end
