import PipelineStagesAPI from '../pipelineStages';
import ApiClient from '../ApiClient';

describe('#PipelineStagesAPI', () => {
  it('updates stage requirements inside a pipeline', () => {
    expect(PipelineStagesAPI).toBeInstanceOf(ApiClient);
    const originalAxios = window.axios;
    const axiosMock = { patch: vi.fn(() => Promise.resolve()) };
    window.axios = axiosMock;

    PipelineStagesAPI.updateRequirements(3, 4, ['budget']);

    expect(axiosMock.patch).toHaveBeenCalledWith(
      `${PipelineStagesAPI.baseUrl()}/pipelines/3/stages/4`,
      {
        pipeline_stage: {
          required_field_keys: ['budget'],
        },
      }
    );
    window.axios = originalAxios;
  });
});
