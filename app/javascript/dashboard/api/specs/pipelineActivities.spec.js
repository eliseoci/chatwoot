import pipelineActivitiesAPI from '../pipelineActivities';
import ApiClient from '../ApiClient';

describe('#PipelineActivitiesAPI', () => {
  it('creates an account-scoped API client', () => {
    expect(pipelineActivitiesAPI).toBeInstanceOf(ApiClient);
  });

  it('loads activities nested under an item', () => {
    const originalAxios = window.axios;
    const axiosMock = { get: vi.fn(() => Promise.resolve()) };
    window.axios = axiosMock;

    pipelineActivitiesAPI.get(4);

    expect(axiosMock.get).toHaveBeenCalledWith(
      `${pipelineActivitiesAPI.url}/4/activities`
    );
    window.axios = originalAxios;
  });

  it('completes a specific activity', () => {
    const originalAxios = window.axios;
    const axiosMock = { patch: vi.fn(() => Promise.resolve()) };
    window.axios = axiosMock;

    pipelineActivitiesAPI.complete(4, 9, 'item_detail');

    expect(axiosMock.patch).toHaveBeenCalledWith(
      `${pipelineActivitiesAPI.url}/4/activities/9/complete`,
      { pipeline_activity: { source: 'item_detail' } }
    );
    window.axios = originalAxios;
  });
});
