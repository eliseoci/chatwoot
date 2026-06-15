class Pipelines::Reports::ActivitySnapshot
  BUCKETS = %i[due overdue completed canceled].freeze

  def initialize(pipeline:, generated_at:)
    @pipeline = pipeline
    @generated_at = generated_at
  end

  def perform
    {
      summary: counts_for(activities),
      owners: owner_rows
    }
  end

  private

  attr_reader :pipeline, :generated_at

  def activities
    @activities ||= PipelineActivity
                    .joins(:pipeline_item)
                    .where(pipeline_items: { pipeline_id: pipeline.id })
                    .includes(:assignee)
                    .to_a
  end

  def owner_rows
    rows = activities.group_by(&:assignee).map do |assignee, assigned_activities|
      {
        assignee_id: assignee&.id,
        assignee_name: assignee&.name
      }.merge(counts_for(assigned_activities))
    end
    rows.sort_by { |row| [row[:assignee_id].nil? ? 1 : 0, row[:assignee_name].to_s] }
  end

  def counts_for(records)
    counts = BUCKETS.index_with { 0 }
    records.each { |activity| counts[activity_bucket(activity)] += 1 }
    counts
  end

  def activity_bucket(activity)
    return :completed if activity.status_completed?
    return :canceled if activity.status_canceled?
    return :overdue if activity.due_at < generated_at

    :due
  end
end
