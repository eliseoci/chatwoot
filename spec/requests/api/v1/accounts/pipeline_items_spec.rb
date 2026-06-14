require 'rails_helper'

RSpec.describe 'Pipeline Items API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:pipeline) { create(:pipeline, :with_stages, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Nadia') }
  let(:team) { create(:team, account: account) }

  describe 'POST /api/v1/accounts/:account_id/pipeline_items' do
    it 'requires authentication' do
      post "/api/v1/accounts/#{account.id}/pipeline_items"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'creates a first-class item with optional workflow context' do
      params = {
        pipeline_item: {
          pipeline_id: pipeline.id,
          stage_id: pipeline.stages.first.id,
          contact_id: contact.id,
          owner_id: agent.id,
          team_id: team.id,
          title: 'New website',
          priority: 'high',
          value: 5000,
          due_date: '2026-06-30'
        }
      }

      expect do
        post "/api/v1/accounts/#{account.id}/pipeline_items",
             params: params,
             headers: agent.create_new_auth_token,
             as: :json
      end.to change(account.pipeline_items, :count).by(1)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include(
        'pipeline_id' => pipeline.id,
        'stage_id' => pipeline.stages.first.id,
        'priority' => 'high',
        'display_title' => 'New website'
      )
      expect(response.parsed_body.dig('contact', 'id')).to eq(contact.id)
      expect(response.parsed_body.dig('owner', 'id')).to eq(agent.id)
      expect(response.parsed_body.dig('team', 'id')).to eq(team.id)
    end

    it 'rejects a contact from another account' do
      other_contact = create(:contact)

      post "/api/v1/accounts/#{account.id}/pipeline_items",
           params: {
             pipeline_item: {
               pipeline_id: pipeline.id,
               stage_id: pipeline.stages.first.id,
               contact_id: other_contact.id
             }
           },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:not_found)
      expect(PipelineItem.exists?).to be(false)
    end
  end

  describe 'GET /api/v1/accounts/:account_id/pipeline_items' do
    it 'returns only items in the selected account and pipeline' do
      item = create(:pipeline_item, account: account, pipeline: pipeline, stage: pipeline.stages.first, contact: contact)
      create(:pipeline_item)

      get "/api/v1/accounts/#{account.id}/pipeline_items",
          params: { pipeline_id: pipeline.id },
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('id')).to eq([item.id])
    end
  end

  describe 'GET /api/v1/accounts/:account_id/pipeline_items/:id' do
    it 'does not expose an item from another account' do
      other_item = create(:pipeline_item)

      get "/api/v1/accounts/#{account.id}/pipeline_items/#{other_item.id}",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
