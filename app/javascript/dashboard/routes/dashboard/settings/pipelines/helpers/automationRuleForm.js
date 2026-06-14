const actionConfig = form => {
  switch (form.actionType) {
    case 'assign_owner':
      return { owner_id: form.ownerId || null };
    case 'assign_team':
      return { team_id: form.teamId || null };
    case 'update_field':
      return { field_key: form.fieldKey, value: form.fieldValue };
    case 'add_labels':
    case 'remove_labels':
      return { labels: [form.label] };
    case 'send_internal_notification':
      return {
        recipient_id: form.recipientId,
        message: form.notificationMessage.trim(),
      };
    case 'send_webhook':
      return { url: form.webhookUrl.trim() };
    case 'update_attention':
      return {
        state: form.attentionState,
        note: form.attentionNote.trim() || null,
      };
    default:
      return {
        title: form.activityTitle.trim(),
        activity_type: form.activityType,
        assignee_id: form.assigneeId || null,
        due_mode: form.dueMode,
        due_in_minutes:
          form.dueMode === 'relative' ? Number(form.dueInMinutes) : null,
        due_at:
          form.dueMode === 'fixed' ? new Date(form.dueAt).toISOString() : null,
        notes: form.notes.trim() || null,
      };
  }
};

const buildAction = form => {
  const action = {
    position: 0,
    action_type: form.actionType,
    config: actionConfig(form),
  };
  if (form.actionType === 'send_webhook') {
    action.secret = form.webhookSecret.trim();
  }
  return action;
};

export const buildAutomationRulePayload = ({
  name,
  pipelineId,
  targetStageId,
  enabled = true,
  priority,
  actionType,
  activityTitle,
  activityType,
  assigneeId,
  dueMode,
  dueInMinutes,
  dueAt,
  notes,
  ownerId,
  teamId,
  fieldKey,
  fieldValue,
  label,
  recipientId,
  notificationMessage,
  webhookUrl,
  webhookSecret,
  attentionState,
  attentionNote,
}) => ({
  pipeline_automation_rule: {
    name: name.trim(),
    pipeline_id: pipelineId,
    target_stage_id: targetStageId,
    enabled,
    trigger_type: 'pipeline_item_stage_changed',
    conditions: priority
      ? [{ attribute: 'priority', operator: 'equals', value: priority }]
      : [],
    actions: [
      buildAction({
        actionType,
        activityTitle,
        activityType,
        assigneeId,
        dueMode,
        dueInMinutes,
        dueAt,
        notes,
        ownerId,
        teamId,
        fieldKey,
        fieldValue,
        label,
        recipientId,
        notificationMessage,
        webhookUrl,
        webhookSecret,
        attentionState,
        attentionNote,
      }),
    ],
  },
});
