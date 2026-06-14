json.array! @pipeline_items do |pipeline_item|
  json.partial! 'api/v1/models/pipeline_item', formats: [:json], resource: pipeline_item
end
