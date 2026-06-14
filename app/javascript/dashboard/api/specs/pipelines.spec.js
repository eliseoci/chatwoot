import pipelinesAPI from '../pipelines';
import ApiClient from '../ApiClient';

describe('#PipelinesAPI', () => {
  it('creates an account-scoped API client', () => {
    expect(pipelinesAPI).toBeInstanceOf(ApiClient);
    expect(pipelinesAPI).toHaveProperty('get');
    expect(pipelinesAPI).toHaveProperty('show');
    expect(pipelinesAPI).toHaveProperty('create');
    expect(pipelinesAPI).toHaveProperty('getTemplates');
  });

  it('fetches templates from the pipelines collection', () => {
    const originalAxios = window.axios;
    const axiosMock = { get: vi.fn(() => Promise.resolve()) };
    window.axios = axiosMock;

    pipelinesAPI.getTemplates();

    expect(axiosMock.get).toHaveBeenCalledWith(`${pipelinesAPI.url}/templates`);
    window.axios = originalAxios;
  });
});
