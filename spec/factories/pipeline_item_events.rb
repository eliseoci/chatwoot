FactoryBot.define do
  factory :pipeline_item_event do
    pipeline_item
    account { pipeline_item.account }
    conversation do
      association :conversation,
                  account: pipeline_item.account,
                  contact: pipeline_item.contact
    end
    actor { association :user, account: pipeline_item.account }
    event_type { :conversation_linked }
    source { 'api' }
  end
end
