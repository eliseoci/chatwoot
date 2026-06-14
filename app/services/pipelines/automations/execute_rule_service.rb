class Pipelines::Automations::ExecuteRuleService
  ADVISORY_LOCK_NAMESPACE = 15_409

  def initialize(rule:, stage_transition:)
    @rule = rule
    @stage_transition = stage_transition
  end

  def perform
    run = find_or_create_run
    with_execution_lock(run) do
      return run if run.reload.terminal?

      claim(run)
      execute_claimed_run(run)
    end
  rescue StandardError => e
    record_failure(run, e) if run.present?
    raise
  end

  private

  attr_reader :rule, :stage_transition

  delegate :pipeline_item, to: :stage_transition

  def find_or_create_run
    PipelineAutomationRun.create_or_find_by!(
      account: pipeline_item.account,
      pipeline_automation_rule: rule,
      pipeline_item: pipeline_item,
      stage_transition: stage_transition
    )
  end

  def claim(run)
    run.with_lock do
      run.update!(
        status: :processing,
        attempt_count: run.attempt_count + 1,
        error_message: nil
      )
    end
  end

  def with_execution_lock(run)
    connection = ActiveRecord::Base.connection
    locked = connection.select_value(
      "SELECT pg_try_advisory_lock(#{ADVISORY_LOCK_NAMESPACE}, #{run.id})"
    )
    return run unless ActiveModel::Type::Boolean.new.cast(locked)

    yield
  ensure
    if locked
      connection.select_value(
        "SELECT pg_advisory_unlock(#{ADVISORY_LOCK_NAMESPACE}, #{run.id})"
      )
    end
  end

  def execute_claimed_run(run)
    result = Pipelines::Automations::RuleEvaluator.new(
      rule: rule,
      stage_transition: stage_transition
    ).perform
    return skip(run, result.reason) unless result.matched?

    execute_actions(run)
    succeed(run)
  end

  def execute_actions(run)
    rule.actions.each do |action|
      execute_action(run, action)
    end
  end

  def execute_action(run, action)
    action_run = find_action_run(run, action)
    perform_action(run, action_run, action)
    action_run
  rescue StandardError => e
    record_action_failure(action_run, e)
    raise
  end

  def find_action_run(run, action)
    run.action_runs.create_or_find_by!(
      account: pipeline_item.account,
      pipeline_automation_action: action
    )
  end

  def perform_action(run, action_run, action)
    action_run.with_lock do
      next if action_run.status_succeeded?

      result = Pipelines::Automations::ActionExecutor.new(
        action: action,
        action_run: action_run,
        pipeline_item: pipeline_item
      ).perform
      action_run.update!(
        status: :succeeded,
        attempt_count: action_run.attempt_count + 1,
        result: result,
        error_message: nil
      )
      attach_activity(run, result)
    end
  end

  def succeed(run)
    run.update!(
      status: :succeeded,
      skip_reason: nil,
      error_message: nil,
      metadata: run_metadata
    )
    run
  end

  def skip(run, reason)
    run.update!(
      status: :skipped,
      skip_reason: reason,
      error_message: nil,
      metadata: run_metadata
    )
    run
  end

  def record_failure(run, error)
    run.reload
    return if run.terminal?

    run.update!(
      status: :failed,
      error_message: error.message.to_s.first(2000),
      metadata: run_metadata
    )
  end

  def record_action_failure(action_run, error)
    return if action_run.blank?

    action_run.reload.update!(
      status: :failed,
      attempt_count: action_run.attempt_count + 1,
      error_message: error.message.to_s.first(2000)
    )
  end

  def attach_activity(run, result)
    activity_id = result[:pipeline_activity_id] || result['pipeline_activity_id']
    return if activity_id.blank? || run.pipeline_activity_id.present?

    run.update!(pipeline_activity_id: activity_id)
  end

  def run_metadata
    {
      rule_name: rule.name,
      target_stage_id: rule.target_stage_id,
      action_types: rule.actions.pluck(:action_type)
    }
  end
end
