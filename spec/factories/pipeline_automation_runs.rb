FactoryBot.define do
  factory :pipeline_automation_run do
    pipeline_item
    account { pipeline_item.account }
    stage_transition do
      association(
        :pipeline_item_stage_transition,
        account: account,
        pipeline_item: pipeline_item
      )
    end
    pipeline_automation_rule do
      association(
        :pipeline_automation_rule,
        account: account,
        pipeline: pipeline_item.pipeline,
        target_stage: stage_transition.to_stage
      )
    end
    status { :pending }
    attempt_count { 0 }
    metadata { {} }
  end
end
