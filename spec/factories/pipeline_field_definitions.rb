FactoryBot.define do
  factory :pipeline_field_definition do
    account
    pipeline { association :pipeline, account: account }
    sequence(:label) { |n| "Custom field #{n}" }
    field_type { :text }
    sequence(:position)
    settings { {} }

    trait :list do
      field_type { :list }
      settings { { choices: %w[New Existing] } }
    end

    trait :currency do
      field_type { :currency }
      settings { { currency: 'USD' } }
    end
  end
end
