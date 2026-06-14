import pipelineItemsAPI from '../pipelineItems';
import ApiClient from '../ApiClient';

describe('#PipelineItemsAPI', () => {
  it('creates an account-scoped API client', () => {
    expect(pipelineItemsAPI).toBeInstanceOf(ApiClient);
    expect(pipelineItemsAPI).toHaveProperty('get');
    expect(pipelineItemsAPI).toHaveProperty('show');
    expect(pipelineItemsAPI).toHaveProperty('create');
  });

  it('filters items by pipeline', () => {
    const originalAxios = window.axios;
    const axiosMock = { get: vi.fn(() => Promise.resolve()) };
    window.axios = axiosMock;

    pipelineItemsAPI.get({ pipelineId: 7 });

    expect(axiosMock.get).toHaveBeenCalledWith(pipelineItemsAPI.url, {
      params: { pipeline_id: 7 },
    });
    window.axios = originalAxios;
  });
});
