FactoryBot.define do
  factory :pipeline_item do
    account
    pipeline { association :pipeline, account: account }
    stage { association :pipeline_stage, account: account, pipeline: pipeline, position: 0 }
    contact { association :contact, account: account }
    title { 'Qualified opportunity' }
    priority { :medium }
    value { 2500 }
    due_date { 2.weeks.from_now.to_date }
  end
end
