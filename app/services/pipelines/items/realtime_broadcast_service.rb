class Pipelines::Items::RealtimeBroadcastService
  def self.call(pipeline_item, event_name:)
    Rails.configuration.dispatcher.dispatch(
      event_name,
      Time.zone.now,
      pipeline_item: pipeline_item
    )
  end
end
