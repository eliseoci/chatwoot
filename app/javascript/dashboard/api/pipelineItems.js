/* global axios */
import ApiClient from './ApiClient';

class PipelineItemsAPI extends ApiClient {
  constructor() {
    super('pipeline_items', { accountScoped: true });
  }

  get({ pipelineId }) {
    return axios.get(this.url, { params: { pipeline_id: pipelineId } });
  }

  transition(id, { stageId, source }) {
    return axios.patch(`${this.url}/${id}/transition`, {
      transition: {
        stage_id: stageId,
        source,
      },
    });
  }

  timeline(id) {
    return axios.get(`${this.url}/${id}/timeline`);
  }
}

export default new PipelineItemsAPI();
