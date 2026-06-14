export const buildIntakeRulePayload = ({
  pipelineId,
  initialStageId,
  inboxId,
  channelType,
  enabled = true,
  position = 0,
}) => ({
  pipeline_intake_rule: {
    pipeline_id: pipelineId,
    initial_stage_id: initialStageId,
    inbox_id: inboxId || null,
    channel_type: channelType || null,
    enabled,
    position,
  },
});
