class Pipelines::Authorization::Access
  VIEWER_CAPABILITIES = %i[view].freeze
  OPERATOR_CAPABILITIES = %i[
    view create_item update_item move_item archive_item
  ].freeze
  ADMINISTRATOR_CAPABILITIES = %i[
    view create update archive configure export automate manage_access
    create_item update_item move_item archive_item
  ].freeze

  def self.scope_for(user_context, scope)
    account_user = user_context[:account_user]
    return scope.none if account_user.blank?
    return scope if account_user.administrator?

    user = user_context[:user]
    account = user_context[:account]
    team_ids = user.teams.where(account: account).select(:id)
    direct_grants = PipelineAccessGrant.where(account: account, user_id: user.id)
    team_grants = PipelineAccessGrant.where(account: account, team_id: team_ids)
    granted_pipeline_ids = direct_grants.or(team_grants).select(:pipeline_id)

    scope.where(access_mode: Pipeline.access_modes[:all_agents])
         .or(scope.where(id: granted_pipeline_ids))
  end

  def initialize(user_context, pipeline)
    @user_context = user_context
    @pipeline = pipeline
  end

  def allowed?(capability)
    capabilities.include?(capability.to_sym)
  end

  def capability_map
    ADMINISTRATOR_CAPABILITIES.index_with do |capability|
      allowed?(capability)
    end
  end

  private

  attr_reader :pipeline, :user_context

  def user
    user_context[:user]
  end

  def account
    user_context[:account]
  end

  def account_user
    user_context[:account_user]
  end

  def capabilities
    return ADMINISTRATOR_CAPABILITIES if account_user&.administrator?
    return [] unless account_user&.agent?
    return OPERATOR_CAPABILITIES if pipeline.access_mode_all_agents?

    grant_level == 'operator' ? OPERATOR_CAPABILITIES : viewer_capabilities
  end

  def viewer_capabilities
    grant_level == 'viewer' ? VIEWER_CAPABILITIES : []
  end

  def grant_level
    @grant_level ||= PipelineAccessGrant.access_levels.key(access_grants.maximum(:access_level))
  end

  def access_grants
    team_ids = user.teams.where(account: account).select(:id)
    direct_grants = pipeline.access_grants.where(user_id: user.id)
    team_grants = pipeline.access_grants.where(team_id: team_ids)
    direct_grants.or(team_grants)
  end
end
