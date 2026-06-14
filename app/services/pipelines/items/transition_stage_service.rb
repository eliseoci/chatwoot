class Pipelines::Items::TransitionStageService
  def initialize(pipeline_item:, target_stage_id:, actor:, source:)
    @pipeline_item = pipeline_item
    @target_stage_id = target_stage_id
    @actor = actor
    @source = source
  end

  def perform
    PipelineItem.transaction do
      pipeline_item.lock!
      target_stage = pipeline_item.pipeline.stages.find(target_stage_id)
      previous_stage = pipeline_item.stage
      next pipeline_item if previous_stage == target_stage

      pipeline_item.update!(stage: target_stage)
      record_transition(previous_stage, target_stage)
      pipeline_item
    end
  end

  private

  attr_reader :pipeline_item, :target_stage_id, :actor, :source

  def record_transition(previous_stage, target_stage)
    PipelineItemStageTransition.create!(
      account: pipeline_item.account,
      pipeline_item: pipeline_item,
      from_stage: previous_stage,
      to_stage: target_stage,
      actor: actor,
      source: source
    )
  end
end
