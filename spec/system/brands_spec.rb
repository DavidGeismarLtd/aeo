# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Brands", type: :system do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace) }
  let!(:membership) { create(:workspace_membership, user: user, workspace: workspace, role: "owner") }
  let!(:brand) { ActsAsTenant.with_tenant(workspace) { create(:brand, workspace: workspace, name: "Nike") } }

  before do
    driven_by(:rack_test)
    user.confirm if user.respond_to?(:confirm)
    login_as(user, scope: :user)
  end

  describe "visiting the index" do
    it "displays the brands list" do
      visit workspace_brands_path(workspace)

      expect(page).to have_content("Brands")
      expect(page).to have_content(brand.name)
    end

    it "shows empty state when no brands exist" do
      brand.destroy
      visit workspace_brands_path(workspace)

      expect(page).to have_content("No brands")
      expect(page).to have_content("Get started by creating a new brand")
    end
  end

  describe "creating a brand" do
    it "creates a new brand with valid data" do
      visit workspace_brands_path(workspace)
      click_on "New Brand"

      fill_in "Name", with: "Test Brand"
      fill_in "Description", with: "This is a test brand"
      fill_in "Website Domain", with: "testbrand.com"
      check "Active"

      click_on "Create Brand"

      expect(page).to have_content("Brand was successfully created")
      expect(page).to have_content("Test Brand")
    end

    it "shows validation errors with invalid data" do
      visit new_workspace_brand_path(workspace)

      click_on "Create Brand"

      expect(page).to have_content("errors prohibited this brand from being saved")
      expect(page).to have_content("Name can't be blank")
    end
  end

  describe "updating a brand" do
    it "updates the brand with valid data" do
      visit workspace_brand_path(workspace, brand)
      click_on "Edit"

      fill_in "Name", with: "Updated Brand Name"
      click_on "Update Brand"

      expect(page).to have_content("Brand was successfully updated")
      expect(page).to have_content("Updated Brand Name")
    end

    it "shows validation errors with invalid data" do
      visit edit_workspace_brand_path(workspace, brand)

      fill_in "Name", with: ""
      click_on "Update Brand"

      expect(page).to have_content("errors prohibited this brand from being saved")
    end
  end

  describe "deleting a brand" do
    it "deletes the brand" do
      visit workspace_brand_path(workspace, brand)

      # Note: This test doesn't verify the confirmation dialog since rack_test doesn't support JS
      # The confirmation dialog is tested via Stimulus controller unit tests
      click_on "Delete"

      expect(page).to have_content("Brand was successfully deleted")
      expect(page).to have_current_path(workspace_brands_path(workspace))
    end
  end

  describe "searching brands" do
    let!(:apple) { ActsAsTenant.with_tenant(workspace) { create(:brand, workspace: workspace, name: "Apple") } }

    it "filters brands by search term" do
      visit workspace_brands_path(workspace)

      fill_in "search", with: "Nike"
      click_on "Search"

      expect(page).to have_content("Nike")
      expect(page).not_to have_content("Apple")
    end

    it "shows clear button when searching" do
      visit workspace_brands_path(workspace)

      fill_in "search", with: "Nike"
      click_on "Search"

      expect(page).to have_link("Clear")

      click_on "Clear"
      expect(page).to have_content("Nike")
      expect(page).to have_content("Apple")
    end
  end

  describe "viewing brand details" do
    it "displays brand information" do
      visit workspace_brand_path(workspace, brand)

      expect(page).to have_content(brand.name)
      expect(page).to have_content(brand.description) if brand.description.present?
    end

    it "shows active status badge" do
      visit workspace_brand_path(workspace, brand)

      if brand.active?
        expect(page).to have_content("Active")
      else
        expect(page).to have_content("Inactive")
      end
    end
  end

  describe "workspace scoping" do
    let(:other_workspace) { create(:workspace) }
    let!(:other_membership) { create(:workspace_membership, user: user, workspace: other_workspace, role: "owner") }
    let!(:other_brand) { ActsAsTenant.with_tenant(other_workspace) { create(:brand, workspace: other_workspace, name: "Tesla") } }

    it "only shows brands from current workspace" do
      visit workspace_brands_path(workspace)

      expect(page).to have_content(brand.name)
      expect(page).not_to have_content(other_brand.name)
    end
  end
end
