FactoryBot.define do
  factory :pipeline do
    account
    sequence(:name) { |n| "Pipeline #{n}" }
    description { 'A configurable workflow' }
    template_key { 'custom' }

    trait :with_stages do
      after(:create) do |pipeline|
        create(:pipeline_stage, pipeline: pipeline, account: pipeline.account, position: 0, name: 'New')
        create(:pipeline_stage, :terminal, pipeline: pipeline, account: pipeline.account, position: 1, name: 'Completed')
      end
    end
  end

  factory :pipeline_stage do
    account
    pipeline { association :pipeline, account: account }
    sequence(:name) { |n| "Stage #{n}" }
    sequence(:position)
    color { '#6B7280' }
    terminal { false }
    outcome_key { nil }

    trait :terminal do
      terminal { true }
      outcome_key { 'completed' }
    end
  end
end
