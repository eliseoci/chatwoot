import pipelinesAPI from '../pipelines';
import ApiClient from '../ApiClient';

describe('#PipelinesAPI', () => {
  it('creates an account-scoped API client', () => {
    expect(pipelinesAPI).toBeInstanceOf(ApiClient);
    expect(pipelinesAPI).toHaveProperty('get');
    expect(pipelinesAPI).toHaveProperty('show');
    expect(pipelinesAPI).toHaveProperty('create');
    expect(pipelinesAPI).toHaveProperty('getTemplates');
    expect(pipelinesAPI).toHaveProperty('getReport');
  });

  it('fetches templates from the pipelines collection', () => {
    const originalAxios = window.axios;
    const axiosMock = { get: vi.fn(() => Promise.resolve()) };
    window.axios = axiosMock;

    pipelinesAPI.getTemplates();

    expect(axiosMock.get).toHaveBeenCalledWith(`${pipelinesAPI.url}/templates`);
    window.axios = originalAxios;
  });

  it('fetches the operational report for a pipeline', () => {
    const originalAxios = window.axios;
    const axiosMock = { get: vi.fn(() => Promise.resolve()) };
    window.axios = axiosMock;

    pipelinesAPI.getReport(42);

    expect(axiosMock.get).toHaveBeenCalledWith(`${pipelinesAPI.url}/42/report`);
    window.axios = originalAxios;
  });
});
