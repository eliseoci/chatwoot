class Api::V1::Accounts::PipelineItemsController < Api::V1::Accounts::BaseController
  before_action :fetch_pipeline_item,
                only: [
                  :show,
                  :timeline,
                  :ownership,
                  :linked_conversations,
                  :link_conversation,
                  :unlink_conversation
                ]
  before_action :check_authorization

  def index
    @pipeline_items = pipeline_items_scope
    @pipeline_items = @pipeline_items.where(pipeline: fetch_pipeline) if params[:pipeline_id].present?
    @pipeline_items = @pipeline_items.where(contact: fetch_contact) if params[:contact_id].present?
    @pipeline_items = filter_by_conversation(@pipeline_items) if params[:conversation_id].present?
    @pipeline_items = Pipelines::Items::FilterService.new(
      scope: @pipeline_items,
      params: filter_params
    ).perform
    @workspace_context = Pipelines::Items::WorkspaceContextService.new(@pipeline_items).perform
  end

  def show
    @conversation_links = authorized_conversation_links
  end

  def timeline
    @transitions = @pipeline_item.stage_transitions
                                 .includes(:from_stage, :to_stage, :actor)
                                 .order(created_at: :desc)
    @events = @pipeline_item.events.includes(:conversation, :actor, :pipeline_activity).order(created_at: :desc)
    @visible_conversation_ids = @events.filter_map(&:conversation).select do |conversation|
      policy(conversation).show?
    end.to_set(&:id)
  end

  def create
    ActiveRecord::Base.transaction do
      @pipeline_item = Current.account.pipeline_items.new(pipeline_item_attributes)
      assign_account_scoped_associations
      @pipeline_item.save!
      link_create_conversation if params.dig(:pipeline_item, :conversation_id).present?
    end
  end

  def ownership
    @pipeline_item = Pipelines::Items::UpdateOwnershipService.new(
      pipeline_item: @pipeline_item,
      owner: fetch_owner,
      actor: Current.user,
      source: ownership_params[:source].presence || 'api'
    ).perform
  end

  def linked_conversations
    @conversation_links = authorized_conversation_links
  end

  def link_conversation
    @conversation_link = Pipelines::Items::LinkConversationService.new(
      pipeline_item: @pipeline_item,
      conversation: fetch_conversation,
      actor: Current.user,
      source: conversation_params[:source].presence || 'api'
    ).perform
  end

  def unlink_conversation
    Pipelines::Items::UnlinkConversationService.new(
      pipeline_item: @pipeline_item,
      conversation: fetch_conversation,
      actor: Current.user,
      source: conversation_params[:source].presence || 'api'
    ).perform
    head :no_content
  end

  private

  def pipeline_items_scope
    Current.account.pipeline_items
           .preload(:pipeline, :stage, :contact, :owner, :team,
                    scheduled_activities: :assignee,
                    conversation_links: [:linked_by, { conversation: [:inbox, :assignee] }])
           .order(created_at: :desc)
  end

  def fetch_pipeline_item
    @pipeline_item = pipeline_items_scope.find(params[:id])
  end

  def fetch_pipeline
    Current.account.pipelines.find(params[:pipeline_id].presence || params.dig(:pipeline_item, :pipeline_id))
  end

  def fetch_contact
    Current.account.contacts.find(params[:contact_id])
  end

  def filter_by_conversation(scope)
    conversation = Current.account.conversations.find_by!(display_id: params[:conversation_id])
    authorize conversation, :show?
    scope.joins(:conversation_links)
         .where(pipeline_item_conversations: { conversation_id: conversation.id })
         .distinct
  end

  def fetch_conversation
    conversation = Current.account.conversations.find_by!(display_id: conversation_params[:conversation_id])
    authorize conversation, :show?
    conversation
  end

  def fetch_create_conversation
    conversation = Current.account.conversations.find_by!(
      display_id: params.dig(:pipeline_item, :conversation_id)
    )
    authorize conversation, :show?
    conversation
  end

  def conversation_links_scope
    @pipeline_item.conversation_links
                  .includes(:linked_by, conversation: [:inbox, :assignee])
                  .order(created_at: :desc)
  end

  def authorized_conversation_links
    conversation_links_scope.select { |conversation_link| policy(conversation_link.conversation).show? }
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

  def fetch_owner
    owner_id = ownership_params[:owner_id]
    Current.account.users.find(owner_id) if owner_id.present?
  end

  def link_create_conversation
    Pipelines::Items::LinkConversationService.new(
      pipeline_item: @pipeline_item,
      conversation: fetch_create_conversation,
      actor: Current.user,
      source: 'conversation_sidebar'
    ).perform
  end

  def assign_team
    team_id = params.dig(:pipeline_item, :team_id)
    @pipeline_item.team = Current.account.teams.find(team_id) if team_id.present?
  end

  def pipeline_item_attributes
    params.require(:pipeline_item).permit(:title, :priority, :value, :due_date)
  end

  def filter_params
    params.permit(
      :q,
      :stage_id,
      :owner_id,
      :team_id,
      :inbox_id,
      :channel,
      :label,
      :due_state
    )
  end

  def ownership_params
    params.require(:ownership).permit(:owner_id, :source)
  end

  def conversation_params
    params.require(:conversation_link).permit(:conversation_id, :source)
  end
end
