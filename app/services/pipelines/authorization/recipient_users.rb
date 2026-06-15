class Pipelines::Authorization::RecipientUsers
  def initialize(pipeline)
    @pipeline = pipeline
  end

  def perform
    return account.agents if pipeline.access_mode_all_agents?

    account.agents.where(id: granted_user_ids)
  end

  private

  attr_reader :pipeline

  delegate :account, to: :pipeline

  def granted_user_ids
    direct_user_ids | team_user_ids
  end

  def direct_user_ids
    pipeline.access_grants.where.not(user_id: nil).pluck(:user_id)
  end

  def team_user_ids
    TeamMember.where(team_id: granted_team_ids).pluck(:user_id)
  end

  def granted_team_ids
    pipeline.access_grants.where.not(team_id: nil).pluck(:team_id)
  end
end
