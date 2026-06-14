json.id resource.id
json.account_id resource.account_id
json.pipeline_id resource.pipeline_id
json.initial_stage_id resource.initial_stage_id
json.inbox_id resource.inbox_id
json.channel_type resource.channel_type
json.enabled resource.enabled
json.position resource.position
json.created_at resource.created_at
json.updated_at resource.updated_at
json.pipeline do
  json.id resource.pipeline.id
  json.name resource.pipeline.name
end
json.initial_stage do
  json.id resource.initial_stage.id
  json.name resource.initial_stage.name
end
if resource.inbox.present?
  json.inbox do
    json.id resource.inbox.id
    json.name resource.inbox.name
    json.channel_type resource.inbox.channel_type
  end
else
  json.inbox nil
end
