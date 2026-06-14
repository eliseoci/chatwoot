class Api::V1::Accounts::PipelineActivitiesController < Api::V1::Accounts::BaseController
  before_action :fetch_pipeline_item
  before_action :fetch_activity, only: [:update, :complete, :cancel]
  before_action :check_authorization

  def index
    @pipeline_activities = activities_scope.operational_order
  end

  def create
    @pipeline_activity = lifecycle_service.create(
      attributes: activity_attributes,
      assignee: fetch_assignee
    )
  end

  def update
    @pipeline_activity = lifecycle_service.update(
      activity: @pipeline_activity,
      attributes: activity_update_attributes
    )
  end

  def complete
    @pipeline_activity = lifecycle_service.complete(activity: @pipeline_activity)
  end

  def cancel
    @pipeline_activity = lifecycle_service.cancel(activity: @pipeline_activity)
  end

  private

  def fetch_pipeline_item
    @pipeline_item = Current.account.pipeline_items.find(params[:pipeline_item_id])
  end

  def activities_scope
    @pipeline_item.activities.includes(:assignee, :created_by)
  end

  def fetch_activity
    @pipeline_activity = activities_scope.find(params[:id])
  end

  def fetch_assignee
    assignee_id = params.dig(:pipeline_activity, :assignee_id)
    Current.account.users.find(assignee_id) if assignee_id.present?
  end

  def activity_attributes
    params.require(:pipeline_activity).permit(:activity_type, :title, :due_at, :notes)
  end

  def activity_update_attributes
    attributes = activity_attributes
    return attributes unless params.require(:pipeline_activity).key?(:assignee_id)

    attributes.merge(assignee: fetch_assignee)
  end

  def lifecycle_service
    Pipelines::Activities::LifecycleService.new(
      pipeline_item: @pipeline_item,
      actor: Current.user,
      source: params.dig(:pipeline_activity, :source).presence || 'api'
    )
  end
end
