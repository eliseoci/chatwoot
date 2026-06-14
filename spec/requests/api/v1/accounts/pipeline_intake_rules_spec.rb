require 'rails_helper'

RSpec.describe 'Pipeline Intake Rules API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:pipeline) { create(:pipeline, :with_stages, account: account) }
  let(:inbox) { create(:inbox, account: account) }

  it 'allows administrators to create and list an account-scoped rule' do
    post "/api/v1/accounts/#{account.id}/pipeline_intake_rules",
         params: {
           pipeline_intake_rule: {
             pipeline_id: pipeline.id,
             initial_stage_id: pipeline.stages.first.id,
             inbox_id: inbox.id,
             channel_type: inbox.channel_type,
             enabled: true,
             position: 0
           }
         },
         headers: administrator.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include(
      'pipeline_id' => pipeline.id,
      'initial_stage_id' => pipeline.stages.first.id,
      'inbox_id' => inbox.id,
      'enabled' => true
    )

    get "/api/v1/accounts/#{account.id}/pipeline_intake_rules",
        headers: administrator.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.pluck('id')).to eq([PipelineIntakeRule.last.id])
  end

  it 'rejects non-administrators' do
    get "/api/v1/accounts/#{account.id}/pipeline_intake_rules",
        headers: agent.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects cross-account associations and mismatched stages' do
    post "/api/v1/accounts/#{account.id}/pipeline_intake_rules",
         params: {
           pipeline_intake_rule: {
             pipeline_id: pipeline.id,
             initial_stage_id: create(:pipeline_stage, account: account).id,
             inbox_id: create(:inbox).id
           }
         },
         headers: administrator.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:not_found)
    expect(account.pipeline_intake_rules).to be_empty
  end

  it 'updates and deletes a rule' do
    rule = create(:pipeline_intake_rule, account: account, pipeline: pipeline)

    patch "/api/v1/accounts/#{account.id}/pipeline_intake_rules/#{rule.id}",
          params: {
            pipeline_intake_rule: {
              pipeline_id: pipeline.id,
              initial_stage_id: pipeline.stages.first.id,
              enabled: false,
              position: 2
            }
          },
          headers: administrator.create_new_auth_token,
          as: :json

    expect(response).to have_http_status(:success)
    expect(rule.reload).to have_attributes(enabled: false, position: 2)

    delete "/api/v1/accounts/#{account.id}/pipeline_intake_rules/#{rule.id}",
           headers: administrator.create_new_auth_token,
           as: :json

    expect(response).to have_http_status(:no_content)
    expect(PipelineIntakeRule.exists?(rule.id)).to be(false)
  end
end
