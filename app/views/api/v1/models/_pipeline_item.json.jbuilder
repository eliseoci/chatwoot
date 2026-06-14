json.id resource.id
json.account_id resource.account_id
json.pipeline_id resource.pipeline_id
json.stage_id resource.stage_id
json.title resource.title
json.display_title resource.display_title
json.priority resource.priority
json.value resource.value
json.due_date resource.due_date
json.field_values resource.field_values
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

next_activity = resource.next_activity
if next_activity.present?
  json.next_activity do
    json.partial! 'api/v1/models/pipeline_activity',
                  formats: [:json],
                  resource: next_activity
  end
else
  json.next_activity nil
end

workspace_context = local_assigns[:workspace_context] ||
                    Pipelines::Items::WorkspaceContextService.new([resource]).perform.fetch(resource.id)
json.workspace do
  json.last_activity_at workspace_context[:last_activity_at]
  json.unread_count workspace_context[:unread_count]
  json.conversation_ids workspace_context[:conversation_ids]
  json.channels workspace_context[:channels]
  json.labels workspace_context[:labels]
  json.inboxes workspace_context[:inboxes]
  json.attention_reasons workspace_context[:attention_reasons]
end
