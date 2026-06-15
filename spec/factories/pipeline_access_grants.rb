FactoryBot.define do
  factory :pipeline_access_grant do
    account
    pipeline { association :pipeline, account: account }
    user { association :user, account: account }
    access_level { :viewer }
  end
end
