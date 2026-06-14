export const buildPipelineActivityPayload = ({
  activityType,
  title,
  dueAt,
  assigneeId,
  notes,
  source = 'item_detail',
}) => {
  const pipelineActivity = {
    activity_type: activityType,
    title: title.trim(),
    due_at: new Date(dueAt).toISOString(),
    assignee_id: assigneeId || null,
    notes: notes.trim() || null,
    source,
  };

  return { pipeline_activity: pipelineActivity };
};

export const sortActivities = activities =>
  [...activities].sort((left, right) => {
    if (left.status === 'scheduled' && right.status !== 'scheduled') return -1;
    if (left.status !== 'scheduled' && right.status === 'scheduled') return 1;
    return new Date(left.due_at) - new Date(right.due_at);
  });
