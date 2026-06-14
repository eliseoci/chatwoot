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
    it 'returns linked conversation summaries without message history' do
      item = create(:pipeline_item, account: account, pipeline: pipeline, stage: pipeline.stages.first, contact: contact)
      conversation = create(:conversation, :with_assignee, account: account, contact: contact)
      create(:inbox_member, user: agent, inbox: conversation.inbox)
      create(
        :pipeline_item_conversation,
        account: account,
        pipeline_item: item,
        conversation: conversation,
        linked_by: agent
      )

      get "/api/v1/accounts/#{account.id}/pipeline_items/#{item.id}",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      summary = response.parsed_body['linked_conversations'].first
      expect(summary).to include(
        'id' => conversation.display_id,
        'status' => conversation.status
      )
      expect(summary.dig('inbox', 'name')).to eq(conversation.inbox.name)
      expect(summary.dig('assignee', 'id')).to eq(conversation.assignee.id)
      expect(summary).not_to have_key('messages')
    end

    it 'does not expose an item from another account' do
      other_item = create(:pipeline_item)

      get "/api/v1/accounts/#{account.id}/pipeline_items/#{other_item.id}",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'conversation links' do
    let(:item) do
      create(:pipeline_item, account: account, pipeline: pipeline, stage: pipeline.stages.first, contact: contact)
    end
    let(:conversation) { create(:conversation, account: account, contact: contact) }

    before { create(:inbox_member, user: agent, inbox: conversation.inbox) }

    it 'links a compatible conversation and records the actor' do
      expect do
        post "/api/v1/accounts/#{account.id}/pipeline_items/#{item.id}/link_conversation",
             params: {
               conversation_link: {
                 conversation_id: conversation.display_id,
                 source: 'item_detail'
               }
             },
             headers: agent.create_new_auth_token,
             as: :json
      end.to change(item.conversation_links, :count).by(1)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['id']).to eq(conversation.display_id)
      expect(item.events.last).to have_attributes(
        event_type: 'conversation_linked',
        actor: agent,
        source: 'item_detail'
      )
    end

    it 'treats duplicate links idempotently' do
      create(
        :pipeline_item_conversation,
        account: account,
        pipeline_item: item,
        conversation: conversation,
        linked_by: agent
      )

      post "/api/v1/accounts/#{account.id}/pipeline_items/#{item.id}/link_conversation",
           params: { conversation_link: { conversation_id: conversation.display_id } },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(item.conversation_links.count).to eq(1)
    end

    it 'rejects a conversation for another contact' do
      incompatible_conversation = create(:conversation, account: account)
      create(:inbox_member, user: agent, inbox: incompatible_conversation.inbox)

      post "/api/v1/accounts/#{account.id}/pipeline_items/#{item.id}/link_conversation",
           params: { conversation_link: { conversation_id: incompatible_conversation.display_id } },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(item.conversation_links).to be_empty
    end

    it 'rejects a conversation the agent cannot access' do
      restricted_conversation = create(:conversation, account: account, contact: contact)

      post "/api/v1/accounts/#{account.id}/pipeline_items/#{item.id}/link_conversation",
           params: { conversation_link: { conversation_id: restricted_conversation.display_id } },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(item.conversation_links).to be_empty
    end

    it 'does not expose a conversation from another account' do
      other_account = create(:account)
      other_conversation = create_list(:conversation, 2, account: other_account).last

      post "/api/v1/accounts/#{account.id}/pipeline_items/#{item.id}/link_conversation",
           params: { conversation_link: { conversation_id: other_conversation.display_id } },
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:not_found)
      expect(item.conversation_links).to be_empty
    end

    it 'does not list linked conversations outside the agent inbox access' do
      restricted_conversation = create(:conversation, account: account, contact: contact)
      create(
        :pipeline_item_conversation,
        account: account,
        pipeline_item: item,
        conversation: restricted_conversation,
        linked_by: agent
      )

      get "/api/v1/accounts/#{account.id}/pipeline_items/#{item.id}/linked_conversations",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to be_empty
    end

    it 'lists and unlinks conversations without deleting them' do
      create(
        :pipeline_item_conversation,
        account: account,
        pipeline_item: item,
        conversation: conversation,
        linked_by: agent
      )

      get "/api/v1/accounts/#{account.id}/pipeline_items/#{item.id}/linked_conversations",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('id')).to eq([conversation.display_id])

      delete "/api/v1/accounts/#{account.id}/pipeline_items/#{item.id}/unlink_conversation",
             params: {
               conversation_link: {
                 conversation_id: conversation.display_id,
                 source: 'item_detail'
               }
             },
             headers: agent.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:no_content)
      expect(item.reload.conversation_links).to be_empty
      expect(conversation.reload).to be_present
      expect(item.events.last).to have_attributes(
        event_type: 'conversation_unlinked',
        actor: agent,
        source: 'item_detail'
      )
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/pipeline_items/:id/transition' do
    let(:item) do
      create(:pipeline_item, account: account, pipeline: pipeline, stage: pipeline.stages.first, contact: contact)
    end

    it 'requires authentication' do
      patch "/api/v1/accounts/#{account.id}/pipeline_items/#{item.id}/transition"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'moves the item and records the actor and source' do
      patch "/api/v1/accounts/#{account.id}/pipeline_items/#{item.id}/transition",
            params: {
              transition: {
                stage_id: pipeline.stages.second.id,
                source: 'board_command'
              }
            },
            headers: agent.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['stage_id']).to eq(pipeline.stages.second.id)
      expect(item.stage_transitions.last).to have_attributes(actor: agent, source: 'board_command')
    end

    it 'rejects a stage from another pipeline' do
      patch "/api/v1/accounts/#{account.id}/pipeline_items/#{item.id}/transition",
            params: {
              transition: {
                stage_id: create(:pipeline_stage).id,
                source: 'api'
              }
            },
            headers: agent.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:not_found)
      expect(item.reload.stage).to eq(pipeline.stages.first)
    end
  end

  describe 'GET /api/v1/accounts/:account_id/pipeline_items/:id/timeline' do
    it 'returns newest stage transitions first' do
      item = create(:pipeline_item, account: account, pipeline: pipeline, stage: pipeline.stages.first, contact: contact)
      service = Pipelines::Items::TransitionStageService
      service.new(
        pipeline_item: item,
        target_stage_id: pipeline.stages.second.id,
        actor: agent,
        source: 'api'
      ).perform

      get "/api/v1/accounts/#{account.id}/pipeline_items/#{item.id}/timeline",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.first).to include('source' => 'api')
      expect(response.parsed_body.first.dig('actor', 'id')).to eq(agent.id)
      expect(response.parsed_body.first.dig('from_stage', 'id')).to eq(pipeline.stages.first.id)
      expect(response.parsed_body.first.dig('to_stage', 'id')).to eq(pipeline.stages.second.id)
    end

    it 'returns conversation link and unlink audit events' do
      item = create(:pipeline_item, account: account, pipeline: pipeline, stage: pipeline.stages.first, contact: contact)
      conversation = create(:conversation, account: account, contact: contact)
      create(:inbox_member, user: agent, inbox: conversation.inbox)
      link_service = Pipelines::Items::LinkConversationService
      unlink_service = Pipelines::Items::UnlinkConversationService

      link_service.new(
        pipeline_item: item,
        conversation: conversation,
        actor: agent,
        source: 'item_detail'
      ).perform
      unlink_service.new(
        pipeline_item: item,
        conversation: conversation,
        actor: agent,
        source: 'item_detail'
      ).perform

      get "/api/v1/accounts/#{account.id}/pipeline_items/#{item.id}/timeline",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('event_type')).to eq(
        %w[conversation_unlinked conversation_linked]
      )
      expect(response.parsed_body.first.dig('conversation', 'id')).to eq(conversation.display_id)
    end
  end
end
