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

    it 'creates and links an item from the current conversation atomically' do
      conversation = create(:conversation, account: account, contact: contact)
      create(:inbox_member, user: agent, inbox: conversation.inbox)

      expect do
        post "/api/v1/accounts/#{account.id}/pipeline_items",
             params: {
               pipeline_item: {
                 pipeline_id: pipeline.id,
                 stage_id: pipeline.stages.first.id,
                 contact_id: contact.id,
                 conversation_id: conversation.display_id
               }
             },
             headers: agent.create_new_auth_token,
             as: :json
      end.to change(account.pipeline_items, :count).by(1)
                                                   .and change(PipelineItemConversation, :count).by(1)

      expect(response).to have_http_status(:success)
      expect(account.pipeline_items.last.linked_conversations).to contain_exactly(conversation)
    end

    it 'rolls back an item when the conversation belongs to another contact' do
      conversation = create(:conversation, account: account)
      create(:inbox_member, user: agent, inbox: conversation.inbox)

      expect do
        post "/api/v1/accounts/#{account.id}/pipeline_items",
             params: {
               pipeline_item: {
                 pipeline_id: pipeline.id,
                 stage_id: pipeline.stages.first.id,
                 contact_id: contact.id,
                 conversation_id: conversation.display_id
               }
             },
             headers: agent.create_new_auth_token,
             as: :json
      end.not_to change(account.pipeline_items, :count)

      expect(response).to have_http_status(:unprocessable_entity)
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

    it 'filters contact-compatible and conversation-linked items for the sidebar' do
      linked_item = create(
        :pipeline_item,
        account: account,
        pipeline: pipeline,
        stage: pipeline.stages.first,
        contact: contact
      )
      compatible_item = create(:pipeline_item, account: account, contact: contact)
      conversation = create(:conversation, account: account, contact: contact)
      create(:inbox_member, user: agent, inbox: conversation.inbox)
      create(
        :pipeline_item_conversation,
        account: account,
        pipeline_item: linked_item,
        conversation: conversation,
        linked_by: agent
      )

      get "/api/v1/accounts/#{account.id}/pipeline_items",
          params: { contact_id: contact.id },
          headers: agent.create_new_auth_token,
          as: :json
      expect(response.parsed_body.pluck('id')).to contain_exactly(linked_item.id, compatible_item.id)

      get "/api/v1/accounts/#{account.id}/pipeline_items",
          params: { conversation_id: conversation.display_id },
          headers: agent.create_new_auth_token,
          as: :json
      expect(response.parsed_body.pluck('id')).to eq([linked_item.id])
    end

    it 'filters the operating workspace and returns attention context' do
      owner = create(:user, account: account)
      team = create(:team, account: account)
      item = create(
        :pipeline_item,
        account: account,
        pipeline: pipeline,
        stage: pipeline.stages.first,
        contact: contact,
        owner: owner,
        team: team,
        title: 'Renewal'
      )
      conversation = create(:conversation, account: account, contact: contact)
      create(:inbox_member, user: agent, inbox: conversation.inbox)
      conversation.update!(label_list: ['vip'])
      create(
        :pipeline_item_conversation,
        account: account,
        pipeline_item: item,
        conversation: conversation,
        linked_by: agent
      )
      create(
        :pipeline_activity,
        account: account,
        pipeline_item: item,
        due_at: 1.hour.ago
      )

      get "/api/v1/accounts/#{account.id}/pipeline_items",
          params: {
            pipeline_id: pipeline.id,
            q: 'renew',
            stage_id: item.stage_id,
            owner_id: owner.id,
            team_id: team.id,
            inbox_id: conversation.inbox_id,
            channel: conversation.inbox.channel_type,
            label: 'vip',
            due_state: 'overdue'
          },
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('id')).to eq([item.id])
      expect(response.parsed_body.first.dig('workspace', 'attention_reasons')).to include('overdue_activity')
      expect(response.parsed_body.first.dig('workspace', 'inboxes', 0, 'id')).to eq(conversation.inbox_id)
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

    it 'moves the item from the conversation sidebar' do
      patch "/api/v1/accounts/#{account.id}/pipeline_items/#{item.id}/transition",
            params: {
              transition: {
                stage_id: pipeline.stages.second.id,
                source: 'conversation_sidebar'
              }
            },
            headers: agent.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(item.stage_transitions.last.source).to eq('conversation_sidebar')
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

    it 'returns structured missing-field errors and preserves the current stage' do
      field = create(
        :pipeline_field_definition,
        account: account,
        pipeline: pipeline,
        label: 'Contract value'
      )
      pipeline.stages.second.update!(required_field_keys: [field.key])

      patch "/api/v1/accounts/#{account.id}/pipeline_items/#{item.id}/transition",
            params: {
              transition: {
                stage_id: pipeline.stages.second.id,
                source: 'board_command'
              }
            },
            headers: agent.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to include(
        'error' => 'missing_required_fields',
        'missing_field_keys' => [field.key],
        'missing_fields' => [{ 'key' => field.key, 'label' => field.label }]
      )
      expect(item.reload.stage).to eq(pipeline.stages.first)
      expect(item.stage_transitions).to be_empty
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/pipeline_items/:id/field_values' do
    let(:item) do
      create(:pipeline_item, account: account, pipeline: pipeline, stage: pipeline.stages.first, contact: contact)
    end

    it 'updates typed item-owned fields and exposes them in item responses and history' do
      field = create(
        :pipeline_field_definition,
        account: account,
        pipeline: pipeline,
        label: 'Customer brief'
      )

      patch "/api/v1/accounts/#{account.id}/pipeline_items/#{item.id}/field_values",
            params: {
              pipeline_item: {
                field_values: { field.key => 'Enterprise renewal' },
                source: 'item_detail'
              }
            },
            headers: agent.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['field_values']).to eq(field.key => 'Enterprise renewal')
      expect(item.events.last).to have_attributes(
        event_type: 'field_values_updated',
        actor: agent,
        source: 'item_detail'
      )

      get "/api/v1/accounts/#{account.id}/pipeline_items/#{item.id}/timeline",
          headers: agent.create_new_auth_token,
          as: :json
      expect(response.parsed_body.first).to include(
        'event_type' => 'field_values_updated',
        'changed_field_keys' => [field.key]
      )
    end

    it 'rejects fields from another pipeline without changing stored values' do
      other_field = create(:pipeline_field_definition)

      patch "/api/v1/accounts/#{account.id}/pipeline_items/#{item.id}/field_values",
            params: {
              pipeline_item: {
                field_values: { other_field.key => 'Private' }
              }
            },
            headers: agent.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(item.reload.field_values).to be_empty
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/pipeline_items/:id/ownership' do
    let(:item) do
      create(:pipeline_item, account: account, pipeline: pipeline, stage: pipeline.stages.first, contact: contact)
    end

    it 'assigns and clears an account owner through the ownership service' do
      patch "/api/v1/accounts/#{account.id}/pipeline_items/#{item.id}/ownership",
            params: {
              ownership: {
                owner_id: agent.id,
                source: 'conversation_sidebar'
              }
            },
            headers: agent.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.dig('owner', 'id')).to eq(agent.id)
      expect(item.events.last.event_type).to eq('ownership_changed')

      get "/api/v1/accounts/#{account.id}/pipeline_items/#{item.id}/timeline",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response.parsed_body.first).to include('event_type' => 'ownership_changed')
      expect(response.parsed_body.first.dig('ownership', 'to_owner', 'name')).to eq(agent.available_name)

      patch "/api/v1/accounts/#{account.id}/pipeline_items/#{item.id}/ownership",
            params: { ownership: { owner_id: nil, source: 'conversation_sidebar' } },
            headers: agent.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['owner']).to be_nil
    end

    it 'rejects an owner from another account' do
      patch "/api/v1/accounts/#{account.id}/pipeline_items/#{item.id}/ownership",
            params: { ownership: { owner_id: create(:user).id } },
            headers: agent.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:not_found)
      expect(item.reload.owner).to be_nil
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
