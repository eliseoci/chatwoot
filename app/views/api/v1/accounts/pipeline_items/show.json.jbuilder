json.partial! 'api/v1/models/pipeline_item', formats: [:json], resource: @pipeline_item
json.linked_conversations do
  json.array! @conversation_links do |conversation_link|
    json.partial! 'api/v1/models/pipeline_item_conversation',
                  formats: [:json],
                  resource: conversation_link
  end
end
