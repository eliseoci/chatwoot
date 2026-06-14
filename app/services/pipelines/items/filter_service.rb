class Pipelines::Items::FilterService
  DUE_STATES = %w[overdue upcoming missing].freeze

  def initialize(scope:, params:)
    @scope = scope
    @params = params
  end

  def perform
    filter_search
    filter_scalar(:stage_id)
    filter_assignment(:owner_id)
    filter_assignment(:team_id)
    filter_conversation(:inbox_id)
    filter_conversation(:channel)
    filter_label
    filter_due_state
    scope.distinct
  end

  private

  attr_accessor :scope
  attr_reader :params

  def filter_search
    return if params[:q].blank?

    query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].strip)}%"
    self.scope = scope.joins(:contact).where(
      'pipeline_items.title ILIKE :query OR contacts.name ILIKE :query OR ' \
      'contacts.email ILIKE :query OR contacts.phone_number ILIKE :query',
      query: query
    )
  end

  def filter_scalar(attribute)
    return if params[attribute].blank?

    self.scope = scope.where(attribute => params[attribute])
  end

  def filter_assignment(attribute)
    return if params[attribute].blank?

    value = params[attribute]
    self.scope = scope.where(attribute => value == 'unassigned' ? nil : value)
  end

  def filter_conversation(attribute)
    return if params[attribute].blank?

    self.scope = scope.joins(conversation_links: { conversation: :inbox })
    self.scope = if attribute == :channel
                   scope.where(inboxes: { channel_type: params[attribute] })
                 else
                   scope.where(conversations: { inbox_id: params[attribute] })
                 end
  end

  def filter_label
    return if params[:label].blank?

    self.scope = scope.joins(conversation_links: :conversation)
                      .where(
                        "? = ANY(regexp_split_to_array(conversations.cached_label_list, ',[[:space:]]*'))",
                        params[:label]
                      )
  end

  def filter_due_state
    return unless DUE_STATES.include?(params[:due_state])

    if params[:due_state] == 'missing'
      filter_missing_activity
    else
      filter_scheduled_activity
    end
  end

  def filter_missing_activity
    self.scope = scope.where(<<~SQL.squish)
      NOT EXISTS (
        SELECT 1
        FROM pipeline_activities
        WHERE pipeline_activities.pipeline_item_id = pipeline_items.id
          AND pipeline_activities.status = 0
      )
    SQL
  end

  def filter_scheduled_activity
    comparison = params[:due_state] == 'overdue' ? '<' : '>='
    condition = <<~SQL.squish
      EXISTS (
        SELECT 1
        FROM pipeline_activities
        WHERE pipeline_activities.pipeline_item_id = pipeline_items.id
          AND pipeline_activities.status = 0
          AND pipeline_activities.due_at #{comparison} :now
      )
    SQL
    self.scope = scope.where(condition, now: Time.current)
  end
end
