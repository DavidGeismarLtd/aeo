# frozen_string_literal: true

require "rails_helper"

RSpec.describe Workspace, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:workspace_memberships).dependent(:destroy) }
    it { is_expected.to have_many(:users).through(:workspace_memberships) }
    it { is_expected.to have_many(:brands).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_least(2).is_at_most(100) }

    describe "slug validations" do
      it "auto-generates slug when not provided" do
        workspace = Workspace.new(name: "Test Workspace")
        workspace.valid?
        expect(workspace.slug).to eq("test-workspace")
      end

      it "validates presence of slug when explicitly set to empty string" do
        workspace = Workspace.new(name: "Test")
        workspace.slug = ""
        workspace.valid?
        # The generate_slug callback will create a slug from name
        expect(workspace.slug).to eq("test")
      end

      it "validates uniqueness of slug (case insensitive)" do
        create(:workspace, slug: "test-slug")
        workspace = build(:workspace, slug: "TEST-SLUG")
        expect(workspace).not_to be_valid
        expect(workspace.errors[:slug]).to include("has already been taken")
      end
    end

    it "validates slug format" do
      workspace = build(:workspace, slug: "Invalid Slug!")
      expect(workspace).not_to be_valid
      expect(workspace.errors[:slug]).to include("only allows lowercase letters, numbers, and hyphens (no leading/trailing hyphens)")
    end

    it "allows valid slug formats" do
      valid_slugs = [ "valid-slug", "slug123", "my-company-2024" ]
      valid_slugs.each do |slug|
        workspace = build(:workspace, slug: slug)
        expect(workspace).to be_valid
      end
    end

    it "rejects invalid slug formats" do
      invalid_slugs = [ "Invalid Slug", "slug_with_underscore", "-leading-hyphen", "trailing-hyphen-" ]
      invalid_slugs.each do |slug|
        workspace = build(:workspace, slug: slug)
        expect(workspace).not_to be_valid
      end
    end
  end

  describe "callbacks" do
    describe "#generate_slug" do
      it "generates slug from name on create" do
        workspace = create(:workspace, name: "My Awesome Company")
        expect(workspace.slug).to eq("my-awesome-company")
      end

      it "does not override manually set slug" do
        workspace = create(:workspace, name: "My Company", slug: "custom-slug")
        expect(workspace.slug).to eq("custom-slug")
      end

      it "ensures slug uniqueness by appending counter" do
        create(:workspace, name: "Duplicate", slug: "duplicate")
        workspace2 = create(:workspace, name: "Duplicate")
        expect(workspace2.slug).to eq("duplicate-1")
      end

      it "increments counter for multiple duplicates" do
        create(:workspace, slug: "test")
        create(:workspace, slug: "test-1")
        workspace3 = create(:workspace, name: "Test")
        expect(workspace3.slug).to eq("test-2")
      end
    end

    describe "#normalize_slug" do
      it "converts slug to lowercase" do
        workspace = create(:workspace, slug: "MySlug")
        expect(workspace.slug).to eq("myslug")
      end
    end
  end

  describe "scopes" do
    describe ".active" do
      it "returns workspaces with active brands" do
        workspace_with_active = create(:workspace)
        workspace_without_brands = create(:workspace)
        workspace_with_inactive = create(:workspace)

        ActsAsTenant.with_tenant(workspace_with_active) do
          create(:brand, workspace: workspace_with_active, active: true)
        end

        ActsAsTenant.with_tenant(workspace_with_inactive) do
          create(:brand, workspace: workspace_with_inactive, active: false)
        end

        ActsAsTenant.without_tenant do
          expect(Workspace.active).to include(workspace_with_active)
          expect(Workspace.active).not_to include(workspace_without_brands)
          expect(Workspace.active).not_to include(workspace_with_inactive)
        end
      end
    end

    describe ".recent" do
      it "orders workspaces by created_at DESC" do
        old_workspace = create(:workspace, created_at: 2.days.ago)
        new_workspace = create(:workspace, created_at: 1.day.ago)

        expect(Workspace.recent.first).to eq(new_workspace)
        expect(Workspace.recent.last).to eq(old_workspace)
      end
    end

    describe ".by_name" do
      it "orders workspaces alphabetically by name" do
        workspace_b = create(:workspace, name: "Beta Company")
        workspace_a = create(:workspace, name: "Alpha Company")

        expect(Workspace.by_name.first).to eq(workspace_a)
        expect(Workspace.by_name.last).to eq(workspace_b)
      end
    end
  end

  describe "instance methods" do
    let(:workspace) { create(:workspace) }
    let(:owner_user) { create(:user) }
    let(:admin_user) { create(:user) }
    let(:editor_user) { create(:user) }
    let(:viewer_user) { create(:user) }
    let(:non_member) { create(:user) }

    before do
      create(:workspace_membership, workspace: workspace, user: owner_user, role: "owner")
      create(:workspace_membership, workspace: workspace, user: admin_user, role: "admin")
      create(:workspace_membership, workspace: workspace, user: editor_user, role: "editor")
      create(:workspace_membership, workspace: workspace, user: viewer_user, role: "viewer")
    end

    describe "#owner" do
      it "returns the owner user" do
        expect(workspace.owner).to eq(owner_user)
      end

      it "returns nil if no owner exists" do
        workspace.workspace_memberships.owners.destroy_all
        expect(workspace.owner).to be_nil
      end
    end

    describe "#admins" do
      it "returns all admin and owner users" do
        admins = workspace.admins
        expect(admins).to include(owner_user, admin_user)
        expect(admins).not_to include(editor_user, viewer_user)
      end
    end

    describe "#member?" do
      it "returns true for workspace members" do
        expect(workspace.member?(owner_user)).to be true
        expect(workspace.member?(viewer_user)).to be true
      end

      it "returns false for non-members" do
        expect(workspace.member?(non_member)).to be false
      end

      it "returns false for nil user" do
        expect(workspace.member?(nil)).to be false
      end
    end

    describe "#role_for" do
      it "returns the user's role in the workspace" do
        expect(workspace.role_for(owner_user)).to eq("owner")
        expect(workspace.role_for(admin_user)).to eq("admin")
        expect(workspace.role_for(editor_user)).to eq("editor")
        expect(workspace.role_for(viewer_user)).to eq("viewer")
      end

      it "returns nil for non-members" do
        expect(workspace.role_for(non_member)).to be_nil
      end

      it "returns nil for nil user" do
        expect(workspace.role_for(nil)).to be_nil
      end
    end

    describe "#user_can_edit?" do
      it "returns true for owner, admin, and editor" do
        expect(workspace.user_can_edit?(owner_user)).to be true
        expect(workspace.user_can_edit?(admin_user)).to be true
        expect(workspace.user_can_edit?(editor_user)).to be true
      end

      it "returns false for viewer" do
        expect(workspace.user_can_edit?(viewer_user)).to be false
      end

      it "returns false for non-members" do
        expect(workspace.user_can_edit?(non_member)).to be false
      end
    end

    describe "#user_can_admin?" do
      it "returns true for owner and admin" do
        expect(workspace.user_can_admin?(owner_user)).to be true
        expect(workspace.user_can_admin?(admin_user)).to be true
      end

      it "returns false for editor and viewer" do
        expect(workspace.user_can_admin?(editor_user)).to be false
        expect(workspace.user_can_admin?(viewer_user)).to be false
      end

      it "returns false for non-members" do
        expect(workspace.user_can_admin?(non_member)).to be false
      end
    end
  end
end
