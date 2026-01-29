# frozen_string_literal: true

require "rails_helper"

RSpec.describe Authorization, type: :module do
  # Create a test class that includes the Authorization concern
  let(:test_class) do
    Class.new do
      include Authorization

      attr_accessor :current_user

      def initialize(user, workspace)
        @current_user = user
        ActsAsTenant.current_tenant = workspace
      end
    end
  end

  let(:user) { create(:user) }
  let(:workspace) { create(:workspace) }
  let(:test_instance) { test_class.new(user, workspace) }

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe "#has_workspace_role?" do
    context "when user is owner" do
      before do
        create(:workspace_membership, :owner, workspace: workspace, user: user)
      end

      it "returns true for viewer role" do
        expect(test_instance.has_workspace_role?(:viewer)).to be true
      end

      it "returns true for editor role" do
        expect(test_instance.has_workspace_role?(:editor)).to be true
      end

      it "returns true for admin role" do
        expect(test_instance.has_workspace_role?(:admin)).to be true
      end

      it "returns true for owner role" do
        expect(test_instance.has_workspace_role?(:owner)).to be true
      end
    end

    context "when user is admin" do
      before do
        create(:workspace_membership, :admin, workspace: workspace, user: user)
      end

      it "returns true for viewer role" do
        expect(test_instance.has_workspace_role?(:viewer)).to be true
      end

      it "returns true for editor role" do
        expect(test_instance.has_workspace_role?(:editor)).to be true
      end

      it "returns true for admin role" do
        expect(test_instance.has_workspace_role?(:admin)).to be true
      end

      it "returns false for owner role" do
        expect(test_instance.has_workspace_role?(:owner)).to be false
      end
    end

    context "when user is editor" do
      before do
        create(:workspace_membership, :editor, workspace: workspace, user: user)
      end

      it "returns true for viewer role" do
        expect(test_instance.has_workspace_role?(:viewer)).to be true
      end

      it "returns true for editor role" do
        expect(test_instance.has_workspace_role?(:editor)).to be true
      end

      it "returns false for admin role" do
        expect(test_instance.has_workspace_role?(:admin)).to be false
      end

      it "returns false for owner role" do
        expect(test_instance.has_workspace_role?(:owner)).to be false
      end
    end

    context "when user is viewer" do
      before do
        create(:workspace_membership, :viewer, workspace: workspace, user: user)
      end

      it "returns true for viewer role" do
        expect(test_instance.has_workspace_role?(:viewer)).to be true
      end

      it "returns false for editor role" do
        expect(test_instance.has_workspace_role?(:editor)).to be false
      end

      it "returns false for admin role" do
        expect(test_instance.has_workspace_role?(:admin)).to be false
      end

      it "returns false for owner role" do
        expect(test_instance.has_workspace_role?(:owner)).to be false
      end
    end

    context "when user has no membership" do
      it "returns false for any role" do
        expect(test_instance.has_workspace_role?(:viewer)).to be false
        expect(test_instance.has_workspace_role?(:editor)).to be false
        expect(test_instance.has_workspace_role?(:admin)).to be false
        expect(test_instance.has_workspace_role?(:owner)).to be false
      end
    end
  end

  describe "convenience methods" do
    before do
      create(:workspace_membership, :admin, workspace: workspace, user: user)
    end

    it "#workspace_owner? returns false for admin" do
      expect(test_instance.workspace_owner?).to be false
    end

    it "#workspace_admin? returns true for admin" do
      expect(test_instance.workspace_admin?).to be true
    end

    it "#workspace_editor? returns true for admin" do
      expect(test_instance.workspace_editor?).to be true
    end

    it "#workspace_viewer? returns true for admin" do
      expect(test_instance.workspace_viewer?).to be true
    end
  end

  describe "#current_tenant" do
    it "returns the current ActsAsTenant tenant" do
      expect(test_instance.current_tenant).to eq(workspace)
    end
  end

  describe "#current_workspace" do
    it "returns the current workspace (alias for current_tenant)" do
      expect(test_instance.current_workspace).to eq(workspace)
    end
  end
end
