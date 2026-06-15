/* global axios */
import ApiClient from './ApiClient';

class PipelinesAPI extends ApiClient {
  constructor() {
    super('pipelines', { accountScoped: true });
  }

  getTemplates() {
    return axios.get(`${this.url}/templates`);
  }

  getReport(id) {
    return axios.get(`${this.url}/${id}/report`);
  }
}

export default new PipelinesAPI();
