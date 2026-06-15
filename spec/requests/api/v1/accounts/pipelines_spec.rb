require 'rails_helper'

RSpec.describe 'Pipelines API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  describe 'GET /api/v1/accounts/:account_id/pipelines/templates' do
    it 'requires authentication' do
      get "/api/v1/accounts/#{account.id}/pipelines/templates"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects non-administrators' do
      get "/api/v1/accounts/#{account.id}/pipelines/templates",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns localized workflow templates to administrators' do
      get "/api/v1/accounts/#{account.id}/pipelines/templates",
          headers: administrator.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('key')).to include('sales', 'support', 'custom')
      expect(response.parsed_body.find { |template| template['key'] == 'sales' }['stages'].last).to include(
        'terminal' => true,
        'outcome_key' => 'lost'
      )
    end
  end

  describe 'POST /api/v1/accounts/:account_id/pipelines' do
    it 'rejects non-administrators' do
      post "/api/v1/accounts/#{account.id}/pipelines",
           params: { pipeline: { name: 'Sales', template_key: 'sales' } },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'creates a pipeline and seeded stages for an administrator' do
      expect do
        post "/api/v1/accounts/#{account.id}/pipelines",
             params: { pipeline: { name: 'Sales', template_key: 'sales' } },
             headers: administrator.create_new_auth_token,
             as: :json
      end.to change(account.pipelines, :count).by(1)
         .and change(PipelineStage, :count).by(5)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['name']).to eq('Sales')
      expect(response.parsed_body['stages'].pluck('position')).to eq([0, 1, 2, 3, 4])
    end
  end

  describe 'GET /api/v1/accounts/:account_id/pipelines' do
    let!(:pipeline) { create(:pipeline, :with_stages, account: account, name: 'Onboarding') }

    it 'returns account-scoped pipelines and ordered stages to operators' do
      create(:pipeline, account: create(:account), name: 'Other account')
      field = create(
        :pipeline_field_definition,
        pipeline: pipeline,
        account: account,
        label: 'Contract value'
      )
      pipeline.stages.second.update!(required_field_keys: [field.key])

      get "/api/v1/accounts/#{account.id}/pipelines",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('id')).to eq([pipeline.id])
      expect(response.parsed_body.first['stages'].pluck('position')).to eq([0, 1])
      expect(response.parsed_body.first['field_definitions'].first).to include(
        'key' => field.key,
        'field_type' => 'text'
      )
      expect(response.parsed_body.first['stages'].second['required_field_keys']).to eq([field.key])
    end

    it 'does not expose restricted pipelines without a direct or team grant' do
      restricted_pipeline = create(
        :pipeline,
        account: account,
        name: 'Restricted',
        access_mode: :restricted
      )

      get "/api/v1/accounts/#{account.id}/pipelines",
          headers: agent.create_new_auth_token,
          as: :json
      expect(response.parsed_body.pluck('id')).to eq([pipeline.id])

      create(
        :pipeline_access_grant,
        account: account,
        pipeline: restricted_pipeline,
        user: agent,
        access_level: :viewer
      )

      get "/api/v1/accounts/#{account.id}/pipelines",
          headers: agent.create_new_auth_token,
          as: :json
      expect(response.parsed_body.pluck('id')).to contain_exactly(
        pipeline.id,
        restricted_pipeline.id
      )
      expect(
        response.parsed_body.find { |item| item['id'] == restricted_pipeline.id }
      ).to include(
        'access_mode' => 'restricted',
        'capabilities' => hash_including(
          'view' => true,
          'create_item' => false,
          'move_item' => false,
          'configure' => false
        )
      )
    end
  end

  describe 'GET /api/v1/accounts/:account_id/pipelines/:id' do
    it 'does not expose pipelines from another account' do
      other_pipeline = create(:pipeline, account: create(:account))

      get "/api/v1/accounts/#{account.id}/pipelines/#{other_pipeline.id}",
          headers: administrator.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
