FactoryBot.define do
  factory :pipeline_intake_rule do
    account
    pipeline { association :pipeline, :with_stages, account: account }
    initial_stage { pipeline.stages.first }
    channel_type { nil }
    enabled { true }
    position { 0 }
  end
end
