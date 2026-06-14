/* global axios */
import ApiClient from './ApiClient';

class PipelineActivitiesAPI extends ApiClient {
  constructor() {
    super('pipeline_items', { accountScoped: true });
  }

  activityUrl(pipelineItemId, activityId = null) {
    const url = `${this.url}/${pipelineItemId}/activities`;
    return activityId ? `${url}/${activityId}` : url;
  }

  get(pipelineItemId) {
    return axios.get(this.activityUrl(pipelineItemId));
  }

  create(pipelineItemId, payload) {
    return axios.post(this.activityUrl(pipelineItemId), payload);
  }

  update(pipelineItemId, activityId, payload) {
    return axios.patch(this.activityUrl(pipelineItemId, activityId), payload);
  }

  complete(pipelineItemId, activityId, source) {
    return axios.patch(
      `${this.activityUrl(pipelineItemId, activityId)}/complete`,
      { pipeline_activity: { source } }
    );
  }

  cancel(pipelineItemId, activityId, source) {
    return axios.patch(
      `${this.activityUrl(pipelineItemId, activityId)}/cancel`,
      { pipeline_activity: { source } }
    );
  }
}

export default new PipelineActivitiesAPI();
