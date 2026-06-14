import ApiClient from './ApiClient';

class PipelineIntakeRulesAPI extends ApiClient {
  constructor() {
    super('pipeline_intake_rules', { accountScoped: true });
  }
}

export default new PipelineIntakeRulesAPI();
