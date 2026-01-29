# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkspaceMembership, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:workspace) }
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    subject { build(:workspace_membership) }

    it { is_expected.to validate_presence_of(:workspace) }
    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_presence_of(:role) }
    it { is_expected.to validate_inclusion_of(:role).in_array(WorkspaceMembership::ROLES) }

    describe "uniqueness validation" do
      it "validates uniqueness of user_id scoped to workspace_id" do
        workspace = create(:workspace)
        user = create(:user)
        create(:workspace_membership, workspace: workspace, user: user)

        duplicate = build(:workspace_membership, workspace: workspace, user: user)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:user_id]).to include("is already a member of this workspace")
      end

      it "allows same user in different workspaces" do
        user = create(:user)
        workspace1 = create(:workspace)
        workspace2 = create(:workspace)

        create(:workspace_membership, workspace: workspace1, user: user)
        membership2 = build(:workspace_membership, workspace: workspace2, user: user)

        expect(membership2).to be_valid
      end
    end

    describe "only one owner per workspace validation" do
      let(:workspace) { create(:workspace) }

      it "allows creating the first owner" do
        owner = build(:workspace_membership, workspace: workspace, role: "owner")
        expect(owner).to be_valid
      end

      it "prevents creating a second owner" do
        create(:workspace_membership, workspace: workspace, role: "owner")
        second_owner = build(:workspace_membership, workspace: workspace, role: "owner")

        expect(second_owner).not_to be_valid
        expect(second_owner.errors[:role]).to include("workspace can only have one owner")
      end

      it "allows multiple non-owner roles" do
        create(:workspace_membership, workspace: workspace, role: "admin")
        second_admin = build(:workspace_membership, workspace: workspace, role: "admin")

        expect(second_admin).to be_valid
      end
    end
  end

  describe "scopes" do
    let(:workspace) { create(:workspace) }
    let!(:owner_membership) { create(:workspace_membership, workspace: workspace, role: "owner") }
    let!(:admin_membership) { create(:workspace_membership, workspace: workspace, role: "admin") }
    let!(:editor_membership) { create(:workspace_membership, workspace: workspace, role: "editor") }
    let!(:viewer_membership) { create(:workspace_membership, workspace: workspace, role: "viewer") }

    describe ".owners" do
      it "returns only owner memberships" do
        expect(WorkspaceMembership.owners).to include(owner_membership)
        expect(WorkspaceMembership.owners).not_to include(admin_membership, editor_membership, viewer_membership)
      end
    end

    describe ".admins" do
      it "returns only admin memberships" do
        expect(WorkspaceMembership.admins).to include(admin_membership)
        expect(WorkspaceMembership.admins).not_to include(owner_membership, editor_membership, viewer_membership)
      end
    end

    describe ".editors" do
      it "returns only editor memberships" do
        expect(WorkspaceMembership.editors).to include(editor_membership)
        expect(WorkspaceMembership.editors).not_to include(owner_membership, admin_membership, viewer_membership)
      end
    end

    describe ".viewers" do
      it "returns only viewer memberships" do
        expect(WorkspaceMembership.viewers).to include(viewer_membership)
        expect(WorkspaceMembership.viewers).not_to include(owner_membership, admin_membership, editor_membership)
      end
    end

    describe ".by_role" do
      it "filters by specific role" do
        expect(WorkspaceMembership.by_role("owner")).to include(owner_membership)
        expect(WorkspaceMembership.by_role("admin")).to include(admin_membership)
      end

      it "returns empty for invalid role" do
        expect(WorkspaceMembership.by_role("invalid")).to be_empty
      end
    end

    describe ".recent" do
      it "orders by created_at DESC" do
        workspace = create(:workspace)
        old_membership = create(:workspace_membership, workspace: workspace, created_at: 2.days.ago)
        new_membership = create(:workspace_membership, workspace: workspace, created_at: 1.day.ago)

        recent_memberships = workspace.workspace_memberships.recent
        expect(recent_memberships.first).to eq(new_membership)
        expect(recent_memberships.last).to eq(old_membership)
      end
    end
  end

  describe "instance methods" do
    describe "role check methods" do
      it "#owner? returns true for owner role" do
        membership = build(:workspace_membership, role: "owner")
        expect(membership.owner?).to be true
      end

      it "#admin? returns true for owner and admin roles" do
        owner = build(:workspace_membership, role: "owner")
        admin = build(:workspace_membership, role: "admin")
        editor = build(:workspace_membership, role: "editor")

        expect(owner.admin?).to be true
        expect(admin.admin?).to be true
        expect(editor.admin?).to be false
      end

      it "#can_edit? returns true for owner, admin, and editor roles" do
        owner = build(:workspace_membership, role: "owner")
        admin = build(:workspace_membership, role: "admin")
        editor = build(:workspace_membership, role: "editor")
        viewer = build(:workspace_membership, role: "viewer")

        expect(owner.can_edit?).to be true
        expect(admin.can_edit?).to be true
        expect(editor.can_edit?).to be true
        expect(viewer.can_edit?).to be false
      end

      it "#can_view? returns true for all roles" do
        WorkspaceMembership::ROLES.each do |role|
          membership = build(:workspace_membership, role: role)
          expect(membership.can_view?).to be true
        end
      end
    end

    describe "#promote!" do
      it "promotes viewer to editor" do
        membership = create(:workspace_membership, role: "viewer")
        membership.promote!
        expect(membership.reload.role).to eq("editor")
      end

      it "promotes editor to admin" do
        membership = create(:workspace_membership, role: "editor")
        membership.promote!
        expect(membership.reload.role).to eq("admin")
      end

      it "promotes admin to owner" do
        workspace = create(:workspace)
        membership = create(:workspace_membership, workspace: workspace, role: "admin")
        membership.promote!
        expect(membership.reload.role).to eq("owner")
      end

      it "returns false for owner (cannot promote further)" do
        membership = create(:workspace_membership, role: "owner")
        result = membership.promote!
        expect(result).to be false
      end
    end

    describe "#demote!" do
      it "demotes owner to admin" do
        membership = create(:workspace_membership, role: "owner")
        membership.demote!
        expect(membership.reload.role).to eq("admin")
      end

      it "demotes admin to editor" do
        membership = create(:workspace_membership, role: "admin")
        membership.demote!
        expect(membership.reload.role).to eq("editor")
      end

      it "demotes editor to viewer" do
        membership = create(:workspace_membership, role: "editor")
        membership.demote!
        expect(membership.reload.role).to eq("viewer")
      end

      it "returns false for viewer (cannot demote further)" do
        membership = create(:workspace_membership, role: "viewer")
        result = membership.demote!
        expect(result).to be false
      end
    end
  end

  describe "callbacks" do
    describe "#cleanup_workspace_if_empty" do
      it "destroys workspace when last member leaves" do
        workspace = create(:workspace)
        membership = create(:workspace_membership, workspace: workspace)

        expect { membership.destroy }.to change { Workspace.count }.by(-1)
      end

      it "does not destroy workspace if other members exist" do
        workspace = create(:workspace)
        membership1 = create(:workspace_membership, workspace: workspace)
        membership2 = create(:workspace_membership, workspace: workspace)

        expect { membership1.destroy }.not_to change { Workspace.count }
        expect(workspace.reload).to be_persisted
      end
    end
  end
end
