json.id resource.id
json.account_id resource.account_id
json.name resource.name
json.description resource.description
json.template_key resource.template_key
json.created_at resource.created_at
json.updated_at resource.updated_at
json.stages resource.stages do |stage|
  json.id stage.id
  json.name stage.name
  json.position stage.position
  json.color stage.color
  json.terminal stage.terminal
  json.outcome_key stage.outcome_key
end
