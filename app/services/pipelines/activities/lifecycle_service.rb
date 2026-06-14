class Pipelines::Activities::LifecycleService
  EVENT_TYPES = {
    create: :activity_created,
    update: :activity_updated,
    complete: :activity_completed,
    cancel: :activity_canceled
  }.freeze

  def initialize(pipeline_item:, actor:, source: 'api')
    @pipeline_item = pipeline_item
    @actor = actor
    @source = source
  end

  def create(attributes:, assignee: nil)
    activity = pipeline_item.activities.new(
      attributes.merge(
        account: pipeline_item.account,
        assignee: assignee,
        created_by: actor
      )
    )
    persist(activity, :create)
  end

  def update(activity:, attributes:)
    activity.with_lock do
      ensure_scheduled!(activity)
      activity.assign_attributes(attributes)
      persist(activity, :update)
    end
  end

  def complete(activity:)
    activity.with_lock do
      if activity.status_completed?
        activity
      else
        ensure_scheduled!(activity)
        activity.assign_attributes(status: :completed, completed_at: Time.current)
        persist(activity, :complete)
      end
    end
  end

  def cancel(activity:)
    activity.with_lock do
      if activity.status_canceled?
        activity
      else
        ensure_scheduled!(activity)
        activity.assign_attributes(status: :canceled, canceled_at: Time.current)
        persist(activity, :cancel)
      end
    end
  end

  private

  attr_reader :pipeline_item, :actor, :source

  def persist(activity, action)
    PipelineActivity.transaction do
      activity.save!
      pipeline_item.events.create!(
        account: pipeline_item.account,
        actor: actor,
        pipeline_activity: activity,
        event_type: EVENT_TYPES.fetch(action),
        source: source,
        metadata: {
          title: activity.title,
          activity_type: activity.activity_type,
          due_at: activity.due_at.iso8601,
          assignee_id: activity.assignee_id
        }
      )
    end
    activity
  end

  def ensure_scheduled!(activity)
    return if activity.status_scheduled?

    activity.errors.add(:status, I18n.t('errors.pipeline_activity.terminal'))
    raise ActiveRecord::RecordInvalid, activity
  end
end
