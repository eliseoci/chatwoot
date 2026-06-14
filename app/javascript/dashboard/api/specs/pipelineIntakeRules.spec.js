import PipelineIntakeRulesAPI from '../pipelineIntakeRules';
import ApiClient from '../ApiClient';

describe('#PipelineIntakeRulesAPI', () => {
  it('creates an account-scoped CRUD client', () => {
    expect(PipelineIntakeRulesAPI).toBeInstanceOf(ApiClient);
    expect(PipelineIntakeRulesAPI).toHaveProperty('get');
    expect(PipelineIntakeRulesAPI).toHaveProperty('create');
    expect(PipelineIntakeRulesAPI).toHaveProperty('update');
    expect(PipelineIntakeRulesAPI).toHaveProperty('delete');
  });
});
