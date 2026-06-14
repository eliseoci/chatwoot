FactoryBot.define do
  factory :pipeline_item_conversation do
    pipeline_item
    account { pipeline_item.account }
    conversation do
      association :conversation,
                  account: pipeline_item.account,
                  contact: pipeline_item.contact
    end
    linked_by { association :user, account: pipeline_item.account }
    source { 'api' }
  end
end
