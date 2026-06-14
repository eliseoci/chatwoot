import PipelineAutomationRulesAPI from '../pipelineAutomationRules';
import ApiClient from '../ApiClient';

describe('#PipelineAutomationRulesAPI', () => {
  it('creates an account-scoped CRUD client', () => {
    expect(PipelineAutomationRulesAPI).toBeInstanceOf(ApiClient);
    expect(PipelineAutomationRulesAPI).toHaveProperty('get');
    expect(PipelineAutomationRulesAPI).toHaveProperty('create');
    expect(PipelineAutomationRulesAPI).toHaveProperty('update');
    expect(PipelineAutomationRulesAPI).toHaveProperty('delete');
  });
});
