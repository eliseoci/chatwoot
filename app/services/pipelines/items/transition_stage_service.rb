class Pipelines::Items::TransitionStageService
  def initialize(pipeline_item:, target_stage_id:, actor:, source:)
    @pipeline_item = pipeline_item
    @target_stage_id = target_stage_id
    @actor = actor
    @source = source
  end

  def perform
    transition = nil
    PipelineItem.transaction do
      pipeline_item.lock!
      target_stage = pipeline_item.pipeline.stages.find(target_stage_id)
      previous_stage = pipeline_item.stage
      next pipeline_item if previous_stage == target_stage

      validate_required_fields!(target_stage)
      pipeline_item.update!(stage: target_stage)
      transition = record_transition(previous_stage, target_stage)
    end
    Pipelines::Automations::StageEntryJob.perform_later(transition.id) if transition.present?
    pipeline_item
  end

  private

  attr_reader :pipeline_item, :target_stage_id, :actor, :source

  def validate_required_fields!(target_stage)
    definitions = target_stage.pipeline.field_definitions.active
                              .where(key: target_stage.required_field_keys)
                              .index_by(&:key)
    missing_definitions = target_stage.required_field_keys.filter_map do |key|
      definition = definitions[key]
      definition if definition.present? && missing_value?(pipeline_item.field_values[key])
    end
    return if missing_definitions.empty?

    raise Pipelines::Items::MissingRequiredFieldsError, missing_definitions
  end

  def missing_value?(value)
    value.nil? || (value.respond_to?(:empty?) && value.empty?)
  end

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
