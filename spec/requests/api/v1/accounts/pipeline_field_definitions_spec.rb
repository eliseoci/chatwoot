require 'rails_helper'

RSpec.describe 'Pipeline field definitions API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:pipeline) { create(:pipeline, :with_stages, account: account) }
  let(:headers) { administrator.create_new_auth_token }

  it 'creates type-aware field definitions' do
    post definitions_path,
         params: {
           field_definition: {
             label: 'Contract value',
             field_type: 'currency',
             settings: { currency: 'USD' }
           }
         },
         headers: headers,
         as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include(
      'key' => 'contract_value',
      'field_type' => 'currency',
      'settings' => { 'currency' => 'USD' }
    )

    post definitions_path,
         params: {
           field_definition: {
             label: 'Segment',
             field_type: 'list',
             settings: { choices: %w[New Existing] }
           }
         },
         headers: headers,
         as: :json
    expect(response.parsed_body.dig('settings', 'choices')).to eq(%w[New Existing])
  end

  it 'orders, requires, and archives definitions' do
    first = create(
      :pipeline_field_definition,
      :currency,
      pipeline: pipeline,
      account: account,
      label: 'Contract value',
      position: 0
    )
    second = create(
      :pipeline_field_definition,
      :list,
      pipeline: pipeline,
      account: account,
      label: 'Segment',
      position: 1
    )

    patch "#{definitions_path}/reorder",
          params: { ordered_ids: [second.id, first.id] },
          headers: headers,
          as: :json
    expect(response.parsed_body.pluck('id')).to eq([second.id, first.id])

    patch "/api/v1/accounts/#{account.id}/pipelines/#{pipeline.id}/stages/#{pipeline.stages.second.id}",
          params: { pipeline_stage: { required_field_keys: [first.key] } },
          headers: headers,
          as: :json
    expect(response.parsed_body['required_field_keys']).to eq([first.key])

    delete "#{definitions_path}/#{first.id}", headers: headers, as: :json
    expect(response).to have_http_status(:no_content)
    expect(first.reload).to be_archived
    expect(pipeline.stages.second.reload.required_field_keys).to be_empty

    get definitions_path, headers: headers, as: :json
    expect(response.parsed_body.pluck('id')).to eq([second.id])
  end

  it 'rejects operators and resources from another account' do
    post definitions_path,
         params: { field_definition: { label: 'Private', field_type: 'text' } },
         headers: agent.create_new_auth_token,
         as: :json
    expect(response).to have_http_status(:unauthorized)

    other_pipeline = create(:pipeline)
    get "/api/v1/accounts/#{account.id}/pipelines/#{other_pipeline.id}/field_definitions",
        headers: headers,
        as: :json
    expect(response).to have_http_status(:not_found)
  end

  it 'rejects stage requirements from another pipeline' do
    other_field = create(:pipeline_field_definition)

    patch "/api/v1/accounts/#{account.id}/pipelines/#{pipeline.id}/stages/#{pipeline.stages.second.id}",
          params: { pipeline_stage: { required_field_keys: [other_field.key] } },
          headers: headers,
          as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(pipeline.stages.second.reload.required_field_keys).to be_empty
  end

  def definitions_path
    "/api/v1/accounts/#{account.id}/pipelines/#{pipeline.id}/field_definitions"
  end
end
