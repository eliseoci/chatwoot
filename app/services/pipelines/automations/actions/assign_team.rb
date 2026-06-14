class Pipelines::Automations::Actions::AssignTeam
  def initialize(action:, action_run:, pipeline_item:)
    @action = action
    @action_run = action_run
    @pipeline_item = pipeline_item
  end

  def perform
    team = pipeline_item.account.teams.find_by(id: action.config['team_id'])
    pipeline_item.update!(team: team)
    { team_id: team&.id }
  end

  private

  attr_reader :action, :action_run, :pipeline_item
end
