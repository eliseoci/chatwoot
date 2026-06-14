FactoryBot.define do
  factory :pipeline_automation_rule do
    account
    pipeline { association :pipeline, :with_stages, account: account }
    target_stage { pipeline.stages.second }
    sequence(:name) { |n| "Stage follow-up #{n}" }
    enabled { true }
    trigger_type { :pipeline_item_stage_changed }
    conditions { [] }

    after(:build) do |rule|
      next if rule.actions.any?

      rule.actions.build(
        account: rule.account,
        position: 0,
        action_type: :create_activity,
        config: {
          title: 'Follow up with customer',
          activity_type: 'task',
          due_mode: 'relative',
          due_in_minutes: 60
        }
      )
    end
  end
end
