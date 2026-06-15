require 'rails_helper'

RSpec.describe PipelineAccessGrant do
  let(:account) { create(:account) }
  let(:pipeline) { create(:pipeline, account: account) }

  it 'grants a pipeline to either an account user or an account team' do
    user_grant = build(
      :pipeline_access_grant,
      account: account,
      pipeline: pipeline,
      user: create(:user, account: account),
      team: nil
    )
    team_grant = build(
      :pipeline_access_grant,
      account: account,
      pipeline: pipeline,
      user: nil,
      team: create(:team, account: account)
    )

    expect(user_grant).to be_valid
    expect(team_grant).to be_valid
  end

  it 'rejects ambiguous and cross-account grants' do
    other_account = create(:account)
    grant = build(
      :pipeline_access_grant,
      account: account,
      pipeline: pipeline,
      user: create(:user, account: other_account),
      team: create(:team, account: account)
    )

    expect(grant).not_to be_valid
    expect(grant.errors.attribute_names).to include(:base, :user)
  end
end
