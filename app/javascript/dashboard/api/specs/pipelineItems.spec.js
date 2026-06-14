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

  it('moves an item through the transition endpoint', () => {
    const originalAxios = window.axios;
    const axiosMock = { patch: vi.fn(() => Promise.resolve()) };
    window.axios = axiosMock;

    pipelineItemsAPI.transition(4, {
      stageId: 9,
      source: 'board_command',
    });

    expect(axiosMock.patch).toHaveBeenCalledWith(
      `${pipelineItemsAPI.url}/4/transition`,
      {
        transition: {
          stage_id: 9,
          source: 'board_command',
        },
      }
    );
    window.axios = originalAxios;
  });

  it('loads the item timeline', () => {
    const originalAxios = window.axios;
    const axiosMock = { get: vi.fn(() => Promise.resolve()) };
    window.axios = axiosMock;

    pipelineItemsAPI.timeline(4);

    expect(axiosMock.get).toHaveBeenCalledWith(
      `${pipelineItemsAPI.url}/4/timeline`
    );
    window.axios = originalAxios;
  });
});
