/* global axios */
import ApiClient from './ApiClient';

class PipelineItemsAPI extends ApiClient {
  constructor() {
    super('pipeline_items', { accountScoped: true });
  }

  get({ pipelineId }) {
    return axios.get(this.url, { params: { pipeline_id: pipelineId } });
  }
}

export default new PipelineItemsAPI();
