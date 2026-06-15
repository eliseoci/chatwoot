export const groupItemsByStage = (stages, items) =>
  stages.map(stage => ({
    ...stage,
    items: items.filter(item => item.stage_id === stage.id),
  }));

export const pipelineCapabilities = pipeline => {
  const capabilities = pipeline?.capabilities || {};

  return {
    canView: Boolean(capabilities.view),
    canCreate: Boolean(capabilities.create_item),
    canUpdate: Boolean(capabilities.update_item),
    canMove: Boolean(capabilities.move_item),
    canArchive: Boolean(capabilities.archive_item),
    canConfigure: Boolean(capabilities.configure),
    canExport: Boolean(capabilities.export),
    canAutomate: Boolean(capabilities.automate),
  };
};

export const buildPipelineItemPayload = ({
  pipelineId,
  stageId,
  contactId,
  ownerId,
  teamId,
  title,
  priority,
  value,
  dueDate,
  conversationId,
}) => {
  const pipelineItem = {
    pipeline_id: pipelineId,
    stage_id: stageId,
    contact_id: contactId,
  };

  if (title.trim()) pipelineItem.title = title.trim();
  if (ownerId) pipelineItem.owner_id = ownerId;
  if (teamId) pipelineItem.team_id = teamId;
  if (priority) pipelineItem.priority = priority;
  if (value !== '') pipelineItem.value = Number(value);
  if (dueDate) pipelineItem.due_date = dueDate;
  if (conversationId) pipelineItem.conversation_id = conversationId;

  return { pipeline_item: pipelineItem };
};
