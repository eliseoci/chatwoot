require 'rails_helper'

RSpec.describe PipelineItemPolicy, type: :policy do
  subject(:pipeline_item_policy) { described_class }

  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:pipeline_item) { create(:pipeline_item, account: account) }
  let(:administrator_context) do
    { user: administrator, account: account, account_user: administrator.account_users.find_by(account: account) }
  end
  let(:agent_context) do
    { user: agent, account: account, account_user: agent.account_users.find_by(account: account) }
  end

  permissions :index?,
              :show?,
              :create?,
              :timeline?,
              :transition?,
              :ownership?,
              :linked_conversations?,
              :link_conversation?,
              :unlink_conversation? do
    it { is_expected.to permit(administrator_context, pipeline_item) }
    it { is_expected.to permit(agent_context, pipeline_item) }
  end
end
