/* global axios */
import ApiClient from './ApiClient';

class PipelinesAPI extends ApiClient {
  constructor() {
    super('pipelines', { accountScoped: true });
  }

  getTemplates() {
    return axios.get(`${this.url}/templates`);
  }
}

export default new PipelinesAPI();
