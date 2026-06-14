import ApiClient from './ApiClient';

class PipelineAutomationRulesAPI extends ApiClient {
  constructor() {
    super('pipeline_automation_rules', { accountScoped: true });
  }
}

export default new PipelineAutomationRulesAPI();
