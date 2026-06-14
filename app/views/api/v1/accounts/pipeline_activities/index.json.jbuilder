json.array! @pipeline_activities do |pipeline_activity|
  json.partial! 'api/v1/models/pipeline_activity',
                formats: [:json],
                resource: pipeline_activity
end
