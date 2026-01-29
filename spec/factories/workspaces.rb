# frozen_string_literal: true

FactoryBot.define do
  factory :workspace do
    sequence(:name) { |n| "Workspace #{n}" }
    # slug will be auto-generated from name

    trait :with_custom_slug do
      sequence(:slug) { |n| "custom-workspace-#{n}" }
    end

    trait :with_settings do
      settings do
        {
          "timezone" => "UTC",
          "notifications_enabled" => true,
          "theme" => "light"
        }
      end
    end

    trait :with_owner do
      after(:create) do |workspace|
        user = create(:user)
        create(:workspace_membership, workspace: workspace, user: user, role: "owner")
      end
    end

    trait :with_members do
      after(:create) do |workspace|
        owner = create(:user)
        admin = create(:user)
        editor = create(:user)
        viewer = create(:user)

        create(:workspace_membership, workspace: workspace, user: owner, role: "owner")
        create(:workspace_membership, workspace: workspace, user: admin, role: "admin")
        create(:workspace_membership, workspace: workspace, user: editor, role: "editor")
        create(:workspace_membership, workspace: workspace, user: viewer, role: "viewer")
      end
    end

    trait :with_brands do
      after(:create) do |workspace|
        create_list(:brand, 3, workspace: workspace)
      end
    end
  end
end

