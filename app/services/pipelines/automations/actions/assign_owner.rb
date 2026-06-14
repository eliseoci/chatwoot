class Pipelines::Automations::Actions::AssignOwner
  def initialize(action:, action_run:, pipeline_item:)
    @action = action
    @action_run = action_run
    @pipeline_item = pipeline_item
  end

  def perform
    owner = pipeline_item.account.users.find_by(id: action.config['owner_id'])
    Pipelines::Items::UpdateOwnershipService.new(
      pipeline_item: pipeline_item,
      owner: owner,
      actor: nil,
      source: 'automation'
    ).perform
    { owner_id: owner&.id }
  end

  private

  attr_reader :action, :action_run, :pipeline_item
end
