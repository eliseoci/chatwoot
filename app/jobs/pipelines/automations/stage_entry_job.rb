class Pipelines::Automations::StageEntryJob < ApplicationJob
  queue_as :default
  retry_on Pipelines::Automations::ExecutionError, wait: :polynomially_longer, attempts: 5

  discard_on ActiveRecord::RecordNotFound

  def perform(stage_transition_id)
    stage_transition = PipelineItemStageTransition.includes(pipeline_item: :pipeline).find(stage_transition_id)
    errors = execute_rules(stage_transition)
    return if errors.empty?

    raise Pipelines::Automations::ExecutionError, errors.join(', ')
  end

  private

  def execute_rules(stage_transition)
    stage_transition.pipeline_item.pipeline.automation_rules.filter_map do |rule|
      Pipelines::Automations::ExecuteRuleService.new(
        rule: rule,
        stage_transition: stage_transition
      ).perform
      nil
    rescue StandardError => e
      "#{rule.id}: #{e.message}"
    end
  end
end
