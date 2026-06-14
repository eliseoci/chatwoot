json.array! @field_definitions do |field_definition|
  json.partial! 'api/v1/models/pipeline_field_definition',
                formats: [:json],
                resource: field_definition
end
