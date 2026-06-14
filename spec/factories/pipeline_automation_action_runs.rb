FactoryBot.define do
  factory :pipeline_automation_action_run do
    pipeline_automation_run
    pipeline_automation_action do
      association(
        :pipeline_automation_action,
        account: pipeline_automation_run.account,
        pipeline_automation_rule: pipeline_automation_run.pipeline_automation_rule
      )
    end
    account { pipeline_automation_run.account }
    status { :pending }
    attempt_count { 0 }
    result { {} }
  end
end
