class Pipelines::Items::UpdateOwnershipService
  def initialize(pipeline_item:, owner:, actor:, source: 'api')
    @pipeline_item = pipeline_item
    @owner = owner
    @actor = actor
    @source = source
  end

  def perform
    pipeline_item.with_lock do
      previous_owner = pipeline_item.owner
      unless previous_owner == owner
        pipeline_item.update!(owner: owner)
        pipeline_item.events.create!(
          account: pipeline_item.account,
          actor: actor,
          event_type: :ownership_changed,
          source: source,
          metadata: {
            from_owner_id: previous_owner&.id,
            from_owner_name: previous_owner&.available_name,
            to_owner_id: owner&.id,
            to_owner_name: owner&.available_name
          }
        )
      end
    end

    pipeline_item
  end

  private

  attr_reader :pipeline_item, :owner, :actor, :source
end
