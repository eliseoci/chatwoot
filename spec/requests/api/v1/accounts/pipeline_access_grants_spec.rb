require 'rails_helper'

RSpec.describe 'Pipeline Access Grants API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:pipeline) { create(:pipeline, account: account) }
  let(:grants_path) do
    "/api/v1/accounts/#{account.id}/pipelines/#{pipeline.id}/access_grants"
  end

  it 'allows administrators to restrict a pipeline and grant team access' do
    team = create(:team, account: account)

    patch "/api/v1/accounts/#{account.id}/pipelines/#{pipeline.id}",
          params: { pipeline: { access_mode: 'restricted' } },
          headers: administrator.create_new_auth_token,
          as: :json
    post grants_path,
         params: {
           pipeline_access_grant: {
             team_id: team.id,
             access_level: 'operator'
           }
         },
         headers: administrator.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:success)
    expect(pipeline.reload).to be_access_mode_restricted
    expect(response.parsed_body).to include(
      'team_id' => team.id,
      'user_id' => nil,
      'access_level' => 'operator'
    )
  end

  it 'rejects agents and cross-account grantees' do
    post grants_path,
         params: {
           pipeline_access_grant: {
             user_id: agent.id,
             access_level: 'viewer'
           }
         },
         headers: agent.create_new_auth_token,
         as: :json
    expect(response).to have_http_status(:unauthorized)

    post grants_path,
         params: {
           pipeline_access_grant: {
             user_id: create(:user).id,
             access_level: 'viewer'
           }
         },
         headers: administrator.create_new_auth_token,
         as: :json
    expect(response).to have_http_status(:not_found)
  end
end
