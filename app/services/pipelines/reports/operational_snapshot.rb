class Pipelines::Reports::OperationalSnapshot
  def initialize(pipeline:, generated_at:)
    @pipeline = pipeline
    @generated_at = generated_at
  end

  def perform
    {
      generated_at: generated_at.utc.iso8601,
      timezone: reporting_timezone,
      pipeline: {
        id: pipeline.id,
        name: pipeline.name
      },
      stages: stage_rows,
      outcomes: outcome_rows
    }
  end

  private

  attr_reader :pipeline, :generated_at

  def reporting_timezone
    pipeline.account.reporting_timezone.presence || 'UTC'
  end

  def stage_rows
    ages_by_stage = items.group_by(&:stage_id).transform_values do |stage_items|
      stage_items.map { |item| stage_age_seconds(item) }
    end

    pipeline.stages.order(:position).map do |stage|
      stage_row(stage, ages_by_stage.fetch(stage.id, []))
    end
  end

  def stage_row(stage, ages)
    {
      id: stage.id,
      name: stage.name,
      position: stage.position,
      terminal: stage.terminal,
      outcome_key: stage.outcome_key,
      item_count: ages.length,
      average_age_seconds: average_age(ages),
      oldest_age_seconds: ages.max || 0
    }
  end

  def stage_age_seconds(item)
    entered_at = current_stage_transition(item)&.created_at
    (generated_at - (entered_at || item.created_at)).to_i
  end

  def outcome_rows
    pipeline.stages.select(&:terminal?).map do |stage|
      outcome_row(stage, items.select { |item| item.stage_id == stage.id })
    end
  end

  def outcome_row(stage, outcome_items)
    reasons = outcome_items.map { |item| current_stage_transition(item)&.outcome_reason }
                           .tally
                           .sort_by { |reason, _count| [reason.present? ? 1 : 0, reason.to_s] }
                           .map { |reason, count| { reason: reason, item_count: count } }
    {
      stage_id: stage.id,
      stage_name: stage.name,
      outcome_key: stage.outcome_key,
      item_count: outcome_items.length,
      reasons: reasons
    }
  end

  def current_stage_transition(item)
    item.stage_transitions
        .select { |transition| transition.to_stage_id == item.stage_id }
        .max_by(&:created_at)
  end

  def items
    @items ||= pipeline.items.includes(:stage_transitions).to_a
  end

  def average_age(ages)
    return 0 if ages.empty?

    ages.sum / ages.length
  end
end
