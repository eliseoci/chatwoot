timeline_entries = (@transitions.to_a + @events.to_a + @automation_runs.to_a).sort_by(&:created_at).reverse

json.array! timeline_entries do |entry|
  json.id "#{entry.class.model_name.singular}-#{entry.id}"
  json.source entry.is_a?(PipelineAutomationRun) ? 'automation' : entry.source
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
  elsif entry.is_a?(PipelineAutomationRun)
    json.event_type "automation_run_#{entry.status}"
    json.automation do
      json.rule_id entry.pipeline_automation_rule_id
      json.rule_name entry.metadata['rule_name'] || entry.pipeline_automation_rule.name
      json.status entry.status
      json.skip_reason entry.skip_reason
      json.error_message entry.error_message
      json.attempt_count entry.attempt_count
      json.actions entry.action_runs.sort_by(&:id) do |action_run|
        json.action_type action_run.pipeline_automation_action.action_type
        json.status action_run.status
        json.attempt_count action_run.attempt_count
        json.result action_run.result
        json.error_message action_run.error_message
      end
    end
    if entry.pipeline_activity.present?
      json.activity do
        json.id entry.pipeline_activity.id
        json.title entry.pipeline_activity.title
        json.activity_type entry.pipeline_activity.activity_type
      end
    else
      json.activity nil
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
    if entry.ownership_changed?
      json.ownership do
        json.from_owner do
          json.id entry.metadata['from_owner_id']
          json.name entry.metadata['from_owner_name']
        end
        json.to_owner do
          json.id entry.metadata['to_owner_id']
          json.name entry.metadata['to_owner_name']
        end
      end
    else
      json.ownership nil
    end
    if entry.field_values_updated?
      json.changed_field_keys entry.metadata['changed_field_keys']
    else
      json.changed_field_keys nil
    end
  end

  if entry.respond_to?(:actor) && entry.actor.present?
    json.actor do
      json.id entry.actor.id
      json.name entry.actor.available_name
    end
  else
    json.actor nil
  end
end
