# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Brands", type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace) }
  let!(:membership) { create(:workspace_membership, user: user, workspace: workspace, role: "owner") }
  let(:brand) { ActsAsTenant.with_tenant(workspace) { create(:brand, workspace: workspace) } }

  before do
    user.confirm if user.respond_to?(:confirm)
    user.reload # Reload to ensure workspace association is loaded
    sign_in user, scope: :user
    ActsAsTenant.current_tenant = workspace
  end

  describe "GET /workspace_slug/brands" do
    it "returns a successful response" do
      get workspace_brands_path(workspace)
      expect(response).to be_successful
    end

    it "displays brands" do
      brand # create brand
      get workspace_brands_path(workspace)
      expect(response.body).to include(brand.name)
    end

    it "scopes brands to workspace" do
      brand # Force creation of brand
      other_workspace = create(:workspace)
      other_brand = ActsAsTenant.with_tenant(other_workspace) { create(:brand, workspace: other_workspace) }

      get workspace_brands_path(workspace)
      expect(response.body).to include(brand.name)
      expect(response.body).not_to include(other_brand.name)
    end

    context "with search parameter" do
      let!(:nike) { ActsAsTenant.with_tenant(workspace) { create(:brand, workspace: workspace, name: "Nike") } }
      let!(:apple) { ActsAsTenant.with_tenant(workspace) { create(:brand, workspace: workspace, name: "Apple") } }

      it "filters brands by search term" do
        get workspace_brands_path(workspace), params: { search: "Nike" }
        expect(response.body).to include("Nike")
        expect(response.body).not_to include("Apple")
      end
    end
  end

  describe "GET /workspace_slug/brands/:id" do
    it "returns a successful response" do
      get workspace_brand_path(workspace, brand)
      expect(response).to be_successful
    end

    it "displays brand details" do
      get workspace_brand_path(workspace, brand)
      expect(response.body).to include(brand.name)
    end

    it "redirects if brand not found" do
      get workspace_brand_path(workspace, "invalid")
      expect(response).to redirect_to(workspace_brands_path(workspace))
      expect(flash[:alert]).to eq("Brand not found.")
    end
  end

  describe "GET /workspace_slug/brands/new" do
    it "returns a successful response" do
      get new_workspace_brand_path(workspace)
      expect(response).to be_successful
    end

    it "displays the new brand form" do
      get new_workspace_brand_path(workspace)
      expect(response.body).to include("Create New Brand")
    end
  end

  describe "POST /workspace_slug/brands" do
    context "with valid parameters" do
      let(:valid_attributes) do
        {
          name: "Test Brand",
          description: "A test brand",
          domain: "testbrand.com",
          active: true
        }
      end

      it "creates a new brand" do
        expect {
          post workspace_brands_path(workspace), params: { brand: valid_attributes }
        }.to change(Brand, :count).by(1)
      end

      it "redirects to the created brand" do
        post workspace_brands_path(workspace), params: { brand: valid_attributes }
        expect(response).to redirect_to(workspace_brand_path(workspace, Brand.last))
      end

      it "sets a success flash message" do
        post workspace_brands_path(workspace), params: { brand: valid_attributes }
        expect(flash[:notice]).to eq("Brand was successfully created.")
      end

      it "associates brand with workspace" do
        post workspace_brands_path(workspace), params: { brand: valid_attributes }
        expect(Brand.last.workspace).to eq(workspace)
      end
    end

    context "with invalid parameters" do
      let(:invalid_attributes) { { name: "" } }

      it "does not create a new brand" do
        expect {
          post workspace_brands_path(workspace), params: { brand: invalid_attributes }
        }.not_to change(Brand, :count)
      end

      it "renders the new template" do
        post workspace_brands_path(workspace), params: { brand: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /workspace_slug/brands/:id/edit" do
    it "returns a successful response" do
      get edit_workspace_brand_path(workspace, brand)
      expect(response).to be_successful
    end

    it "displays the edit form" do
      get edit_workspace_brand_path(workspace, brand)
      expect(response.body).to include("Edit Brand")
    end
  end

  describe "PATCH /workspace_slug/brands/:id" do
    context "with valid parameters" do
      let(:new_attributes) { { name: "Updated Brand Name" } }

      it "updates the brand" do
        patch workspace_brand_path(workspace, brand), params: { brand: new_attributes }
        brand.reload
        expect(brand.name).to eq("Updated Brand Name")
      end

      it "redirects to the brand" do
        patch workspace_brand_path(workspace, brand), params: { brand: new_attributes }
        expect(response).to redirect_to(workspace_brand_path(workspace, brand))
      end

      it "sets a success flash message" do
        patch workspace_brand_path(workspace, brand), params: { brand: new_attributes }
        expect(flash[:notice]).to eq("Brand was successfully updated.")
      end
    end

    context "with invalid parameters" do
      let(:invalid_attributes) { { name: "" } }

      it "does not update the brand" do
        original_name = brand.name
        patch workspace_brand_path(workspace, brand), params: { brand: invalid_attributes }
        brand.reload
        expect(brand.name).to eq(original_name)
      end

      it "renders the edit template" do
        patch workspace_brand_path(workspace, brand), params: { brand: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /workspace_slug/brands/:id" do
    it "destroys the brand" do
      brand # create brand
      expect {
        delete workspace_brand_path(workspace, brand)
      }.to change(Brand, :count).by(-1)
    end

    it "redirects to the brands list" do
      delete workspace_brand_path(workspace, brand)
      expect(response).to redirect_to(workspace_brands_path(workspace))
    end

    it "sets a success flash message" do
      delete workspace_brand_path(workspace, brand)
      expect(flash[:notice]).to eq("Brand was successfully deleted.")
    end
  end

  describe "workspace scoping" do
    let(:other_workspace) { create(:workspace) }
    let(:other_brand) { ActsAsTenant.with_tenant(other_workspace) { create(:brand, workspace: other_workspace) } }

    it "does not allow access to brands from other workspaces" do
      get workspace_brand_path(workspace, other_brand)
      expect(response).to redirect_to(workspace_brands_path(workspace))
      expect(flash[:alert]).to eq("Brand not found.")
    end

    it "redirects if workspace not found" do
      get "/invalid-workspace/brands"
      expect(response).to redirect_to(workspaces_path)
      expect(flash[:alert]).to eq("Workspace not found or you don't have access.")
    end
  end
end
