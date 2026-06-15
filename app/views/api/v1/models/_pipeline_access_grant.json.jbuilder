json.id resource.id
json.account_id resource.account_id
json.pipeline_id resource.pipeline_id
json.user_id resource.user_id
json.team_id resource.team_id
json.access_level resource.access_level
json.created_at resource.created_at
json.updated_at resource.updated_at

if resource.user.present?
  json.user do
    json.id resource.user.id
    json.name resource.user.available_name
  end
else
  json.user nil
end

if resource.team.present?
  json.team do
    json.id resource.team.id
    json.name resource.team.name
  end
else
  json.team nil
end
