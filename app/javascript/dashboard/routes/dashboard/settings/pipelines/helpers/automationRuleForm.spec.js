import { buildAutomationRulePayload } from './automationRuleForm';

describe('#buildAutomationRulePayload', () => {
  it('builds a relative stage-entry activity rule with an optional condition', () => {
    expect(
      buildAutomationRulePayload({
        name: ' Qualified follow-up ',
        pipelineId: 2,
        targetStageId: 7,
        priority: 'high',
        actionType: 'create_activity',
        activityTitle: ' Call the lead ',
        activityType: 'call',
        assigneeId: 4,
        dueMode: 'relative',
        dueInMinutes: '120',
        dueAt: '',
        notes: '',
      })
    ).toEqual({
      pipeline_automation_rule: {
        name: 'Qualified follow-up',
        pipeline_id: 2,
        target_stage_id: 7,
        enabled: true,
        trigger_type: 'pipeline_item_stage_changed',
        conditions: [
          { attribute: 'priority', operator: 'equals', value: 'high' },
        ],
        actions: [
          {
            position: 0,
            action_type: 'create_activity',
            config: {
              title: 'Call the lead',
              activity_type: 'call',
              assignee_id: 4,
              due_mode: 'relative',
              due_in_minutes: 120,
              due_at: null,
              notes: null,
            },
          },
        ],
      },
    });
  });

  it('builds a signed webhook action without exposing customer messaging', () => {
    expect(
      buildAutomationRulePayload({
        name: ' Notify CRM ',
        pipelineId: 2,
        targetStageId: 7,
        actionType: 'send_webhook',
        webhookUrl: ' https://example.com/pipeline-events ',
        webhookSecret: ' signing-secret ',
      })
    ).toEqual({
      pipeline_automation_rule: {
        name: 'Notify CRM',
        pipeline_id: 2,
        target_stage_id: 7,
        enabled: true,
        trigger_type: 'pipeline_item_stage_changed',
        conditions: [],
        actions: [
          {
            position: 0,
            action_type: 'send_webhook',
            config: { url: 'https://example.com/pipeline-events' },
            secret: 'signing-secret',
          },
        ],
      },
    });
  });
});
