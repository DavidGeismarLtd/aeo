# frozen_string_literal: true

FactoryBot.define do
  factory :workspace_membership do
    workspace
    user
    role { "viewer" }

    trait :owner do
      role { "owner" }
    end

    trait :admin do
      role { "admin" }
    end

    trait :editor do
      role { "editor" }
    end

    trait :viewer do
      role { "viewer" }
    end
  end
end

