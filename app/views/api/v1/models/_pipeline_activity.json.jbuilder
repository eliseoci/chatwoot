json.id resource.id
json.account_id resource.account_id
json.pipeline_item_id resource.pipeline_item_id
json.activity_type resource.activity_type
json.status resource.status
json.title resource.title
json.due_at resource.due_at.iso8601
json.notes resource.notes
json.completed_at resource.completed_at&.iso8601
json.canceled_at resource.canceled_at&.iso8601
json.overdue resource.overdue?
json.created_at resource.created_at.iso8601
json.updated_at resource.updated_at.iso8601

if resource.assignee.present?
  json.assignee do
    json.id resource.assignee.id
    json.name resource.assignee.available_name
    json.thumbnail resource.assignee.avatar_url
  end
else
  json.assignee nil
end
