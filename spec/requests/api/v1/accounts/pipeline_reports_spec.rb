require 'rails_helper'

RSpec.describe 'Pipeline Reports API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:pipeline) { create(:pipeline, account: account) }
  let!(:new_stage) do
    create(:pipeline_stage, account: account, pipeline: pipeline, position: 0, name: 'New')
  end
  let!(:qualified_stage) do
    create(:pipeline_stage, account: account, pipeline: pipeline, position: 1, name: 'Qualified')
  end

  describe 'GET /api/v1/accounts/:account_id/pipelines/:pipeline_id/report' do
    def create_stage_history
      create_new_item
      qualified_item = create_qualified_item
      create_transition(qualified_item)
    end

    def create_new_item
      create(
        :pipeline_item,
        account: account,
        pipeline: pipeline,
        stage: new_stage,
        created_at: 10.days.ago,
        updated_at: 1.minute.ago
      )
    end

    def create_qualified_item
      create(
        :pipeline_item,
        account: account,
        pipeline: pipeline,
        stage: qualified_stage,
        created_at: 8.days.ago,
        updated_at: 1.minute.ago
      )
    end

    def create_transition(qualified_item)
      create(
        :pipeline_item_stage_transition,
        account: account,
        pipeline_item: qualified_item,
        from_stage: new_stage,
        to_stage: qualified_stage,
        actor: administrator,
        created_at: 2.days.ago
      )
    end

    def expected_stage_rows
      [
        expected_stage_row(new_stage, age: 10.days),
        expected_stage_row(qualified_stage, age: 2.days)
      ]
    end

    def expected_stage_row(stage, age:)
      {
        'id' => stage.id,
        'name' => stage.name,
        'position' => stage.position,
        'terminal' => stage.terminal,
        'outcome_key' => stage.outcome_key,
        'item_count' => 1,
        'average_age_seconds' => age.to_i,
        'oldest_age_seconds' => age.to_i
      }
    end

    it 'reports current stage volume and aging from transition history' do
      travel_to Time.zone.parse('2026-06-15 12:00:00 UTC') do
        create_stage_history
        get "/api/v1/accounts/#{account.id}/pipelines/#{pipeline.id}/report",
            headers: administrator.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to include(
          'generated_at' => '2026-06-15T12:00:00Z',
          'timezone' => 'UTC',
          'pipeline' => {
            'id' => pipeline.id,
            'name' => pipeline.name
          }
        )
        expect(response.parsed_body['stages']).to eq(expected_stage_rows)
      end
    end

    it 'reports explicit terminal outcomes and optional transition reasons' do
      terminal_stage = create(
        :pipeline_stage,
        :terminal,
        account: account,
        pipeline: pipeline,
        position: 2,
        name: 'Won',
        outcome_key: 'won'
      )
      create_terminal_item(terminal_stage, outcome_reason: 'Fast implementation')
      create_terminal_item(terminal_stage, outcome_reason: nil)

      get "/api/v1/accounts/#{account.id}/pipelines/#{pipeline.id}/report",
          headers: administrator.create_new_auth_token,
          as: :json

      expect(response.parsed_body['outcomes']).to eq(
        [
          {
            'stage_id' => terminal_stage.id,
            'stage_name' => 'Won',
            'outcome_key' => 'won',
            'item_count' => 2,
            'reasons' => [
              { 'reason' => nil, 'item_count' => 1 },
              { 'reason' => 'Fast implementation', 'item_count' => 1 }
            ]
          }
        ]
      )
    end

    it 'reports activity status and owner workload in the account timezone' do
      account.update!(reporting_timezone: 'America/New_York')
      owner = create(:user, account: account, name: 'Nadia Owner')

      travel_to Time.zone.parse('2026-06-15 02:00:00 UTC') do
        item = create(
          :pipeline_item,
          account: account,
          pipeline: pipeline,
          stage: new_stage,
          owner: owner
        )
        create_report_activities(item, owner)

        get "/api/v1/accounts/#{account.id}/pipelines/#{pipeline.id}/report",
            headers: administrator.create_new_auth_token,
            as: :json

        expect(response.parsed_body).to include(
          'timezone' => 'America/New_York',
          'reporting_date' => '2026-06-14'
        )
        expect(response.parsed_body['activities']).to eq(
          {
            'summary' => {
              'due' => 1,
              'overdue' => 1,
              'completed' => 1,
              'canceled' => 1
            },
            'owners' => [
              {
                'assignee_id' => owner.id,
                'assignee_name' => 'Nadia Owner',
                'due' => 1,
                'overdue' => 1,
                'completed' => 1,
                'canceled' => 1
              }
            ]
          }
        )
      end
    end

    it 'deduplicates linked conversation attribution by pipeline item' do
      contact = create(:contact, account: account)
      item = create(
        :pipeline_item,
        account: account,
        pipeline: pipeline,
        stage: new_stage,
        contact: contact
      )
      website_inbox = create(:inbox, account: account, name: 'Website')
      email_inbox = create(:inbox, :with_email, account: account, name: 'Email')
      first_website = create(:conversation, account: account, contact: contact, inbox: website_inbox)
      second_website = create(:conversation, account: account, contact: contact, inbox: website_inbox)
      email = create(:conversation, account: account, contact: contact, inbox: email_inbox)
      create_link(item, first_website, source: 'conversation_sidebar')
      create_link(item, second_website, source: 'conversation_sidebar')
      create_link(item, email, source: 'automation')

      get "/api/v1/accounts/#{account.id}/pipelines/#{pipeline.id}/report",
          headers: administrator.create_new_auth_token,
          as: :json

      expect(response.parsed_body['attribution']).to eq(
        {
          'sources' => [
            { 'key' => 'automation', 'item_count' => 1 },
            { 'key' => 'conversation_sidebar', 'item_count' => 1 }
          ],
          'inboxes' => [
            { 'id' => email_inbox.id, 'name' => 'Email', 'item_count' => 1 },
            { 'id' => website_inbox.id, 'name' => 'Website', 'item_count' => 1 }
          ],
          'channels' => [
            { 'key' => 'Channel::Email', 'item_count' => 1 },
            { 'key' => 'Channel::WebWidget', 'item_count' => 1 }
          ]
        }
      )
    end

    def create_terminal_item(terminal_stage, outcome_reason:)
      item = create(
        :pipeline_item,
        account: account,
        pipeline: pipeline,
        stage: terminal_stage
      )
      create(
        :pipeline_item_stage_transition,
        account: account,
        pipeline_item: item,
        from_stage: new_stage,
        to_stage: terminal_stage,
        actor: administrator,
        outcome_reason: outcome_reason
      )
    end

    def create_report_activities(item, owner)
      common = { account: account, pipeline_item: item, assignee: owner }
      create(:pipeline_activity, **common, due_at: 1.hour.ago)
      create(:pipeline_activity, **common, due_at: 1.hour.from_now)
      create(
        :pipeline_activity,
        **common,
        status: :completed,
        completed_at: 1.hour.ago,
        due_at: 1.day.ago
      )
      create(
        :pipeline_activity,
        **common,
        status: :canceled,
        canceled_at: 1.hour.ago,
        due_at: 1.day.from_now
      )
    end

    def create_link(item, conversation, source:)
      create(
        :pipeline_item_conversation,
        account: account,
        pipeline_item: item,
        conversation: conversation,
        linked_by: administrator,
        source: source
      )
    end
  end
end
