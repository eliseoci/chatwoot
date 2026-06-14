import { buildIntakeRulePayload } from './intakeRuleForm';

describe('#buildIntakeRulePayload', () => {
  it('normalizes optional eligibility filters', () => {
    expect(
      buildIntakeRulePayload({
        pipelineId: 2,
        initialStageId: 7,
        inboxId: '',
        channelType: 'Channel::Whatsapp',
        position: 3,
      })
    ).toEqual({
      pipeline_intake_rule: {
        pipeline_id: 2,
        initial_stage_id: 7,
        inbox_id: null,
        channel_type: 'Channel::Whatsapp',
        enabled: true,
        position: 3,
      },
    });
  });
});
