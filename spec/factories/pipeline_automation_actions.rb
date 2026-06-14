FactoryBot.define do
  factory :pipeline_automation_action do
    account
    pipeline_automation_rule do
      association :pipeline_automation_rule, account: account
    end
    sequence(:position)
    action_type { :create_activity }
    config do
      {
        title: 'Follow up with customer',
        activity_type: 'task',
        due_mode: 'relative',
        due_in_minutes: 60
      }
    end
  end
end
