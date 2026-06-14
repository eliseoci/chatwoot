import PipelineFieldDefinitionsAPI from '../pipelineFieldDefinitions';
import ApiClient from '../ApiClient';

describe('#PipelineFieldDefinitionsAPI', () => {
  it('uses pipeline-scoped definition and reorder endpoints', () => {
    expect(PipelineFieldDefinitionsAPI).toBeInstanceOf(ApiClient);
    const originalAxios = window.axios;
    const axiosMock = {
      post: vi.fn(() => Promise.resolve()),
      patch: vi.fn(() => Promise.resolve()),
    };
    window.axios = axiosMock;

    PipelineFieldDefinitionsAPI.create(3, {
      label: 'Budget',
      field_type: 'currency',
      settings: { currency: 'USD' },
    });
    PipelineFieldDefinitionsAPI.reorder(3, [8, 7]);

    expect(axiosMock.post).toHaveBeenCalledWith(
      `${PipelineFieldDefinitionsAPI.baseUrl()}/pipelines/3/field_definitions`,
      {
        field_definition: {
          label: 'Budget',
          field_type: 'currency',
          settings: { currency: 'USD' },
        },
      }
    );
    expect(axiosMock.patch).toHaveBeenCalledWith(
      `${PipelineFieldDefinitionsAPI.baseUrl()}/pipelines/3/field_definitions/reorder`,
      { ordered_ids: [8, 7] }
    );
    window.axios = originalAxios;
  });
});
