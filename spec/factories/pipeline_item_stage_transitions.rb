FactoryBot.define do
  factory :pipeline_item_stage_transition do
    pipeline_item
    account { pipeline_item.account }
    from_stage do
      pipeline_item.pipeline.stages.first ||
        association(:pipeline_stage, account: account, pipeline: pipeline_item.pipeline)
    end
    to_stage do
      association(
        :pipeline_stage,
        account: account,
        pipeline: pipeline_item.pipeline,
        position: from_stage.position + 1
      )
    end
    actor { association :user, account: account }
    source { 'api' }
  end
end
