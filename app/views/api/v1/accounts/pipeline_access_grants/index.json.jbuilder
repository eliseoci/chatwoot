json.array! @access_grants do |access_grant|
  json.partial! 'api/v1/models/pipeline_access_grant',
                formats: [:json],
                resource: access_grant
end
