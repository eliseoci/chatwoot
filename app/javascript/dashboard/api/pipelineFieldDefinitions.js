/* global axios */
import ApiClient from './ApiClient';

class PipelineFieldDefinitionsAPI extends ApiClient {
  constructor() {
    super('pipeline_field_definitions', { accountScoped: true });
  }

  getUrl(pipelineId, suffix = '') {
    return `${this.baseUrl()}/pipelines/${pipelineId}/field_definitions${suffix}`;
  }

  create(pipelineId, fieldDefinition) {
    return axios.post(this.getUrl(pipelineId), {
      field_definition: fieldDefinition,
    });
  }

  update(pipelineId, id, fieldDefinition) {
    return axios.patch(this.getUrl(pipelineId, `/${id}`), {
      field_definition: fieldDefinition,
    });
  }

  delete(pipelineId, id) {
    return axios.delete(this.getUrl(pipelineId, `/${id}`));
  }

  reorder(pipelineId, orderedIds) {
    return axios.patch(this.getUrl(pipelineId, '/reorder'), {
      ordered_ids: orderedIds,
    });
  }
}

export default new PipelineFieldDefinitionsAPI();
