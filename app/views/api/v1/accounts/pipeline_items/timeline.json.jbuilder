timeline_entries = (@transitions.to_a + @events.to_a).sort_by(&:created_at).reverse

json.array! timeline_entries do |entry|
  json.id "#{entry.class.model_name.singular}-#{entry.id}"
  json.source entry.source
  json.created_at entry.created_at

  if entry.is_a?(PipelineItemStageTransition)
    json.event_type 'stage_transition'
    json.from_stage do
      json.id entry.from_stage.id
      json.name entry.from_stage.name
    end
    json.to_stage do
      json.id entry.to_stage.id
      json.name entry.to_stage.name
    end
  else
    json.event_type entry.event_type
    if entry.conversation.present? && @visible_conversation_ids.include?(entry.conversation_id)
      json.conversation do
        json.id entry.conversation.display_id
      end
    else
      json.conversation nil
    end
    if entry.pipeline_activity.present?
      json.activity do
        json.id entry.pipeline_activity.id
        json.title entry.metadata['title'] || entry.pipeline_activity.title
        json.activity_type(
          entry.metadata['activity_type'] || entry.pipeline_activity.activity_type
        )
      end
    else
      json.activity nil
    end
  end

  if entry.actor.present?
    json.actor do
      json.id entry.actor.id
      json.name entry.actor.available_name
    end
  else
    json.actor nil
  end
end
