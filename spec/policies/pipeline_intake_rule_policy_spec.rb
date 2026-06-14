require 'rails_helper'

RSpec.describe PipelineIntakeRulePolicy, type: :policy do
  subject(:policy) { described_class }

  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:rule) { create(:pipeline_intake_rule, account: account) }
  let(:administrator_context) do
    { user: administrator, account: account, account_user: administrator.account_users.find_by(account: account) }
  end
  let(:agent_context) do
    { user: agent, account: account, account_user: agent.account_users.find_by(account: account) }
  end

  permissions :index?, :create?, :update?, :destroy? do
    it { is_expected.to permit(administrator_context, rule) }
    it { is_expected.not_to permit(agent_context, rule) }
  end
end
