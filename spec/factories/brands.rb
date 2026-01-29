# frozen_string_literal: true

FactoryBot.define do
  factory :brand do
    workspace
    sequence(:name) { |n| "Brand #{n}" }
    domain { Faker::Internet.domain_name }
    description { Faker::Company.catch_phrase }
    active { true }
    mentions_count { 0 }
    metadata { {} }

    trait :inactive do
      active { false }
    end

    trait :with_metadata do
      metadata do
        {
          "industry" => "Technology",
          "keywords" => [ "software", "saas", "cloud" ],
          "created_by" => "system"
        }
      end
    end

    trait :without_domain do
      domain { nil }
    end

    trait :with_mentions do
      mentions_count { rand(10..100) }
    end
  end
end

