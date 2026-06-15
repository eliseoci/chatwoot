require 'rails_helper'

RSpec.describe PipelinePolicy, type: :policy do
  subject(:policy) { described_class }

  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:pipeline) { create(:pipeline, account: account) }
  let(:administrator_context) do
    { user: administrator, account: account, account_user: administrator.account_users.find_by(account: account) }
  end
  let(:agent_context) do
    { user: agent, account: account, account_user: agent.account_users.find_by(account: account) }
  end

  permissions :show?, :create_item?, :update_item?, :move_item?, :archive_item? do
    it { is_expected.to permit(agent_context, pipeline) }
  end

  permissions :create?, :update?, :archive?, :configure?, :export?, :automate? do
    it { is_expected.not_to permit(agent_context, pipeline) }
  end

  it 'allows administrators to perform every pipeline capability' do
    administrator_policy = described_class.new(administrator_context, pipeline)
    actions = %i[
      show create update archive configure export automate
      create_item update_item move_item archive_item
    ]

    actions.each do |action|
      expect(administrator_policy.public_send("#{action}?")).to be(true)
    end
  end

  it 'limits restricted pipelines to direct or team grants' do
    pipeline.update!(access_mode: :restricted)
    team = create(:team, account: account)
    team.add_members([agent.id])

    agent_policy = described_class.new(agent_context, pipeline)
    expect(agent_policy.show?).to be(false)

    create(
      :pipeline_access_grant,
      account: account,
      pipeline: pipeline,
      user: nil,
      team: team,
      access_level: :viewer
    )

    granted_agent_policy = described_class.new(agent_context, pipeline)
    expect(granted_agent_policy.show?).to be(true)
    expect(granted_agent_policy.move_item?).to be(false)
  end

  it 'allows operators to perform item work without configuration access' do
    pipeline.update!(access_mode: :restricted)
    create(
      :pipeline_access_grant,
      account: account,
      pipeline: pipeline,
      user: agent,
      access_level: :operator
    )
    agent_policy = described_class.new(agent_context, pipeline)

    expect(agent_policy.create_item?).to be(true)
    expect(agent_policy.update_item?).to be(true)
    expect(agent_policy.move_item?).to be(true)
    expect(agent_policy.configure?).to be(false)
  end
end
