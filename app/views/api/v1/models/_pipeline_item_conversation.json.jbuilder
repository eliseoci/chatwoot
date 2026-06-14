conversation = resource.conversation

json.id conversation.display_id
json.uuid conversation.uuid
json.status conversation.status
json.last_activity_at conversation.last_activity_at
json.linked_at resource.created_at
json.inbox do
  json.id conversation.inbox.id
  json.name conversation.inbox.name
  json.channel_type conversation.inbox.channel_type
end
if conversation.assignee.present?
  json.assignee do
    json.id conversation.assignee.id
    json.name conversation.assignee.available_name
  end
else
  json.assignee nil
end
json.linked_by do
  json.id resource.linked_by.id
  json.name resource.linked_by.available_name
end
