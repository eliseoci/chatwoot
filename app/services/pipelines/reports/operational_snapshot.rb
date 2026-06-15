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
      stages: stage_rows
    }
  end

  private

  attr_reader :pipeline, :generated_at

  def reporting_timezone
    pipeline.account.reporting_timezone.presence || 'UTC'
  end

  def stage_rows
    ages_by_stage = pipeline.items.includes(:stage_transitions).group_by(&:stage_id).transform_values do |items|
      items.map { |item| stage_age_seconds(item) }
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
    entered_at = item.stage_transitions
                     .select { |transition| transition.to_stage_id == item.stage_id }
                     .max_by(&:created_at)
                     &.created_at
    (generated_at - (entered_at || item.created_at)).to_i
  end

  def average_age(ages)
    return 0 if ages.empty?

    ages.sum / ages.length
  end
end
