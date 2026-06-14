import { buildPipelinePayload } from './pipelineForm';

describe('#buildPipelinePayload', () => {
  it('builds a predefined template payload without custom stages', () => {
    expect(
      buildPipelinePayload({
        name: ' Sales ',
        description: ' New business ',
        templateKey: 'sales',
        customStages: 'Ignored',
      })
    ).toEqual({
      pipeline: {
        name: 'Sales',
        description: 'New business',
        template_key: 'sales',
      },
    });
  });

  it('normalizes non-empty custom stages', () => {
    expect(
      buildPipelinePayload({
        name: 'Custom',
        description: '',
        templateKey: 'custom',
        customStages: " New \n\n Qualified \n Won ",
      })
    ).toEqual({
      pipeline: {
        name: 'Custom',
        description: '',
        template_key: 'custom',
        stages: [{ name: 'New' }, { name: 'Qualified' }, { name: 'Won' }],
      },
    });
  });
});
