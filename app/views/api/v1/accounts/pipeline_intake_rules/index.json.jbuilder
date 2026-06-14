json.array! @rules do |rule|
  json.partial! 'api/v1/models/pipeline_intake_rule',
                formats: [:json],
                resource: rule
end
