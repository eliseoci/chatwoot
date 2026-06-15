class Pipelines::Reports::AttributionSnapshot
  def initialize(pipeline:)
    @pipeline = pipeline
  end

  def perform
    {
      sources: source_rows,
      inboxes: inbox_rows,
      channels: channel_rows
    }
  end

  private

  attr_reader :pipeline

  def links
    @links ||= PipelineItemConversation
               .joins(:pipeline_item)
               .where(pipeline_items: { pipeline_id: pipeline.id })
               .includes(conversation: :inbox)
               .to_a
  end

  def source_rows
    grouped_rows(links.group_by(&:source)) do |source, item_count|
      { key: source, item_count: item_count }
    end
  end

  def inbox_rows
    rows = grouped_rows(links.group_by { |link| link.conversation.inbox }) do |inbox, item_count|
      { id: inbox.id, name: inbox.name, item_count: item_count }
    end
    rows.sort_by { |row| [row[:name], row[:id]] }
  end

  def channel_rows
    grouped_rows(links.group_by { |link| link.conversation.inbox.channel_type }) do |channel, item_count|
      { key: channel, item_count: item_count }
    end
  end

  def grouped_rows(groups)
    rows = groups.map do |key, grouped_links|
      yield(key, grouped_links.pluck(:pipeline_item_id).uniq.length)
    end
    rows.sort_by { |row| row[:key].to_s }
  end
end
