FactoryBot.define do
  factory :pipeline_activity do
    account
    pipeline_item { association :pipeline_item, account: account }
    assignee { association :user, account: account }
    created_by { association :user, account: account }
    activity_type { :task }
    status { :scheduled }
    title { 'Follow up with customer' }
    due_at { 1.day.from_now }
    notes { 'Confirm the next step.' }
  end
end
