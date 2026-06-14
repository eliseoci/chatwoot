require 'rails_helper'

RSpec.describe 'Pipeline Activities API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:item) { create(:pipeline_item, account: account) }
  let(:headers) { agent.create_new_auth_token }

  describe 'POST /api/v1/accounts/:account_id/pipeline_items/:pipeline_item_id/activities' do
    it 'creates scheduled work with an independent assignee and preserves the supplied instant' do
      assignee = create(:user, account: account)

      post activities_path,
           params: {
             pipeline_activity: {
               activity_type: 'meeting',
               title: 'Demo',
               due_at: '2099-06-15T09:30:00-03:00',
               assignee_id: assignee.id,
               notes: 'Review workflow.',
               source: 'item_detail'
             }
           },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include(
        'activity_type' => 'meeting',
        'status' => 'scheduled',
        'title' => 'Demo',
        'overdue' => false
      )
      expect(Time.zone.parse(response.parsed_body['due_at'])).to eq(
        Time.zone.parse('2099-06-15T12:30:00Z')
      )
      expect(response.parsed_body.dig('assignee', 'id')).to eq(assignee.id)
      expect(item.reload.owner).to be_nil
    end

    it 'rejects an assignee from another account' do
      post activities_path,
           params: {
             pipeline_activity: {
               title: 'Call',
               due_at: 1.day.from_now.iso8601,
               assignee_id: create(:user).id
             }
           },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:not_found)
      expect(item.activities).to be_empty
    end
  end

  describe 'lifecycle' do
    let!(:later_activity) do
      create(:pipeline_activity, pipeline_item: item, account: account, due_at: 2.days.from_now)
    end
    let!(:next_activity) do
      create(:pipeline_activity, pipeline_item: item, account: account, due_at: 1.day.from_now)
    end

    it 'lists activities by due time and exposes the next one on the item' do
      get activities_path, headers: headers, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('id')).to eq([next_activity.id, later_activity.id])

      get "/api/v1/accounts/#{account.id}/pipeline_items",
          params: { pipeline_id: item.pipeline_id },
          headers: headers,
          as: :json

      expect(response.parsed_body.first.dig('next_activity', 'id')).to eq(next_activity.id)
    end

    it 'updates, completes, and cancels scheduled activities' do
      patch "#{activities_path}/#{next_activity.id}",
            params: {
              pipeline_activity: {
                title: 'Updated call',
                due_at: 3.hours.from_now.iso8601,
                source: 'item_detail'
              }
            },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include(
        'title' => 'Updated call',
        'assignee' => a_hash_including('id' => next_activity.assignee_id)
      )

      patch "#{activities_path}/#{next_activity.id}/complete",
            params: { pipeline_activity: { source: 'item_detail' } },
            headers: headers,
            as: :json
      expect(response.parsed_body['status']).to eq('completed')

      patch "#{activities_path}/#{later_activity.id}/cancel",
            params: { pipeline_activity: { source: 'item_detail' } },
            headers: headers,
            as: :json
      expect(response.parsed_body['status']).to eq('canceled')

      expect(item.events.order(:created_at).last(3).map(&:event_type)).to eq(
        %w[activity_updated activity_completed activity_canceled]
      )

      get "/api/v1/accounts/#{account.id}/pipeline_items/#{item.id}/timeline",
          headers: headers,
          as: :json

      activity_events = response.parsed_body.select do |event|
        event['event_type'].start_with?('activity_')
      end
      expect(activity_events.pluck('event_type')).to contain_exactly(
        'activity_updated',
        'activity_completed',
        'activity_canceled'
      )
      expect(activity_events.pluck('activity').compact.pluck('title')).to include(
        'Updated call'
      )
    end

    it 'does not expose an activity from another account' do
      other_activity = create(:pipeline_activity)

      patch "#{activities_path}/#{other_activity.id}/complete",
            params: { pipeline_activity: {} },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  def activities_path
    "/api/v1/accounts/#{account.id}/pipeline_items/#{item.id}/activities"
  end
end
