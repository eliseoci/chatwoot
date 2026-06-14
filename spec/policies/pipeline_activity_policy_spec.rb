require 'rails_helper'

RSpec.describe PipelineActivityPolicy, type: :policy do
  subject(:policy) { described_class }

  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:activity) { create(:pipeline_activity, account: account) }
  let(:administrator_context) do
    { user: administrator, account: account, account_user: administrator.account_users.find_by(account: account) }
  end
  let(:agent_context) do
    { user: agent, account: account, account_user: agent.account_users.find_by(account: account) }
  end

  permissions :index?, :create?, :update?, :complete?, :cancel? do
    it { is_expected.to permit(administrator_context, activity) }
    it { is_expected.to permit(agent_context, activity) }
  end
end
