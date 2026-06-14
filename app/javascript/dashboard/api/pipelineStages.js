/* global axios */
import ApiClient from './ApiClient';

class PipelineStagesAPI extends ApiClient {
  constructor() {
    super('pipeline_stages', { accountScoped: true });
  }

  updateRequirements(pipelineId, stageId, requiredFieldKeys) {
    return axios.patch(
      `${this.baseUrl()}/pipelines/${pipelineId}/stages/${stageId}`,
      {
        pipeline_stage: {
          required_field_keys: requiredFieldKeys,
        },
      }
    );
  }
}

export default new PipelineStagesAPI();
