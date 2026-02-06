# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    confirmed_at { Time.current }

    trait :unconfirmed do
      confirmed_at { nil }
    end

    trait :with_workspace do
      after(:create) do |user|
        workspace = create(:workspace)
        create(:workspace_membership, user: user, workspace: workspace, role: "owner")
      end
    end
  end
end
