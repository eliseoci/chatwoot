class Api::V1::Accounts::PipelineItemsController < Api::V1::Accounts::BaseController
  before_action :fetch_pipeline_item, only: [:show, :timeline, :transition]
  before_action :check_authorization

  def index
    @pipeline_items = pipeline_items_scope
    @pipeline_items = @pipeline_items.where(pipeline: fetch_pipeline) if params[:pipeline_id].present?
  end

  def show; end

  def timeline
    @transitions = @pipeline_item.stage_transitions
                                 .includes(:from_stage, :to_stage, :actor)
                                 .order(created_at: :desc)
  end

  def create
    @pipeline_item = Current.account.pipeline_items.new(pipeline_item_attributes)
    assign_account_scoped_associations
    @pipeline_item.save!
  end

  def transition
    @pipeline_item = Pipelines::Items::TransitionStageService.new(
      pipeline_item: @pipeline_item,
      target_stage_id: transition_params[:stage_id],
      actor: Current.user,
      source: transition_params[:source].presence || 'api'
    ).perform
  end

  private

  def pipeline_items_scope
    Current.account.pipeline_items
           .includes(:pipeline, :stage, :contact, :owner, :team)
           .order(created_at: :desc)
  end

  def fetch_pipeline_item
    @pipeline_item = pipeline_items_scope.find(params[:id])
  end

  def fetch_pipeline
    Current.account.pipelines.find(params[:pipeline_id].presence || params.dig(:pipeline_item, :pipeline_id))
  end

  def assign_account_scoped_associations
    @pipeline_item.pipeline = fetch_pipeline
    @pipeline_item.stage = @pipeline_item.pipeline.stages.find(params.dig(:pipeline_item, :stage_id))
    @pipeline_item.contact = Current.account.contacts.find(params.dig(:pipeline_item, :contact_id))
    assign_owner
    assign_team
  end

  def assign_owner
    owner_id = params.dig(:pipeline_item, :owner_id)
    @pipeline_item.owner = Current.account.users.find(owner_id) if owner_id.present?
  end

  def assign_team
    team_id = params.dig(:pipeline_item, :team_id)
    @pipeline_item.team = Current.account.teams.find(team_id) if team_id.present?
  end

  def pipeline_item_attributes
    params.require(:pipeline_item).permit(:title, :priority, :value, :due_date)
  end

  def transition_params
    params.require(:transition).permit(:stage_id, :source)
  end
end
