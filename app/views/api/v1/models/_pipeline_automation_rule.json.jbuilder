json.id resource.id
json.account_id resource.account_id
json.pipeline_id resource.pipeline_id
json.target_stage_id resource.target_stage_id
json.name resource.name
json.enabled resource.enabled
json.trigger_type resource.trigger_type
json.conditions resource.conditions
json.actions resource.actions do |action|
  json.id action.id
  json.position action.position
  json.action_type action.action_type
  json.config action.config
  json.secret_present action.secret.present?
end
recent_runs = resource.runs.sort_by(&:created_at).reverse.first(10)
json.recent_runs recent_runs do |run|
  json.id run.id
  json.pipeline_item_id run.pipeline_item_id
  json.status run.status
  json.attempt_count run.attempt_count
  json.error_message run.error_message
  json.created_at run.created_at
  json.actions run.action_runs.sort_by(&:id) do |action_run|
    json.action_id action_run.pipeline_automation_action_id
    json.status action_run.status
    json.attempt_count action_run.attempt_count
    json.result action_run.result
    json.error_message action_run.error_message
  end
end
json.created_at resource.created_at
json.updated_at resource.updated_at
json.pipeline do
  json.id resource.pipeline.id
  json.name resource.pipeline.name
end
json.target_stage do
  json.id resource.target_stage.id
  json.name resource.target_stage.name
end
