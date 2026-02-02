# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace) }
  let!(:membership) { create(:workspace_membership, user: user, workspace: workspace, role: "owner") }

  before do
    user.confirm if user.respond_to?(:confirm)
    sign_in user, scope: :user
    ActsAsTenant.current_tenant = workspace
  end

  describe "GET /workspace_slug" do
    context "with valid workspace" do
      before do
        get "/#{workspace.slug}"
      end

      it "returns http success" do
        expect(response).to have_http_status(:success)
      end

      it "renders the dashboard template" do
        expect(response).to render_template(:index)
      end

      it "displays workspace name" do
        expect(response.body).to include(workspace.name)
      end
    end

    context "with brands" do
      let!(:brand1) { create(:brand, workspace: workspace, active: true, name: "Test Brand 1") }
      let!(:brand2) { create(:brand, workspace: workspace, active: true, name: "Test Brand 2") }
      let!(:inactive_brand) { create(:brand, workspace: workspace, active: false, name: "Inactive Brand") }

      before do
        get "/#{workspace.slug}"
      end

      it "displays active brands" do
        expect(response.body).to include("Test Brand 1")
        expect(response.body).to include("Test Brand 2")
      end

      it "does not display inactive brands" do
        expect(response.body).not_to include("Inactive Brand")
      end

      it "displays total brands count" do
        expect(response.body).to include("Total Brands")
        expect(response.body).to include("2")
      end
    end

    context "without brands" do
      before do
        get "/#{workspace.slug}"
      end

      it "displays empty state" do
        expect(response.body).to include("No brands yet")
      end

      it "displays add brand button" do
        expect(response.body).to include("Add Your First Brand")
      end
    end

    context "without authentication" do
      before do
        sign_out user
      end

      it "shows public home page" do
        get root_path
        expect(response).to have_http_status(:success)
      end
    end

    context "with many brands" do
      let!(:brands) { create_list(:brand, 15, workspace: workspace, active: true) }

      before do
        get "/#{workspace.slug}"
      end

      it "displays brands" do
        expect(response).to have_http_status(:success)
      end

      it "shows total brands count" do
        expect(response.body).to include("15")
      end
    end
  end

  describe "statistics display" do
    before do
      create_list(:brand, 3, workspace: workspace, active: true)
      get "/#{workspace.slug}"
    end

    it "displays total brands statistic" do
      expect(response.body).to include("Total Brands")
      expect(response.body).to include("3")
    end

    it "displays total mentions statistic" do
      expect(response.body).to include("Total Mentions")
    end

    it "displays avg visibility score statistic" do
      expect(response.body).to include("Avg Visibility Score")
    end

    it "displays recent activity statistic" do
      expect(response.body).to include("Recent Activity")
    end
  end

  describe "charts placeholder" do
    before do
      get "/#{workspace.slug}"
    end

    it "displays charts coming soon message" do
      expect(response.body).to include("Charts Coming Soon")
    end

    it "displays future features preview" do
      expect(response.body).to include("Visibility Trends")
      expect(response.body).to include("Sentiment Analysis")
      expect(response.body).to include("Platform Comparison")
    end
  end
end
