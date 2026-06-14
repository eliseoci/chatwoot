json.id resource.id
json.account_id resource.account_id
json.pipeline_id resource.pipeline_id
json.stage_id resource.stage_id
json.title resource.title
json.display_title resource.display_title
json.priority resource.priority
json.value resource.value
json.due_date resource.due_date
json.created_at resource.created_at
json.updated_at resource.updated_at
json.contact do
  json.id resource.contact.id
  json.name resource.contact.name
  json.email resource.contact.email
  json.phone_number resource.contact.phone_number
  json.thumbnail resource.contact.avatar_url
end
if resource.owner.present?
  json.owner do
    json.id resource.owner.id
    json.name resource.owner.available_name
    json.thumbnail resource.owner.avatar_url
  end
else
  json.owner nil
end

if resource.team.present?
  json.team do
    json.id resource.team.id
    json.name resource.team.name
  end
else
  json.team nil
end
