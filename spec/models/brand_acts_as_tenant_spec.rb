# frozen_string_literal: true

require "rails_helper"

RSpec.describe Brand, type: :model do
  describe "acts_as_tenant" do
    let(:workspace1) { create(:workspace, name: "Workspace 1") }
    let(:workspace2) { create(:workspace, name: "Workspace 2") }

    describe "automatic scoping" do
      it "only returns brands from current tenant" do
        brand1 = ActsAsTenant.with_tenant(workspace1) do
          create(:brand, name: "Brand 1")
        end

        brand2 = ActsAsTenant.with_tenant(workspace2) do
          create(:brand, name: "Brand 2")
        end

        ActsAsTenant.with_tenant(workspace1) do
          brands = Brand.all
          expect(brands).to include(brand1)
          expect(brands).not_to include(brand2)
        end

        ActsAsTenant.with_tenant(workspace2) do
          brands = Brand.all
          expect(brands).to include(brand2)
          expect(brands).not_to include(brand1)
        end
      end

      it "automatically assigns workspace_id on create" do
        ActsAsTenant.with_tenant(workspace1) do
          brand = create(:brand, name: "Auto Brand")
          expect(brand.workspace_id).to eq(workspace1.id)
        end
      end

      it "scopes find queries to current tenant" do
        brand1 = ActsAsTenant.with_tenant(workspace1) do
          create(:brand, name: "Brand 1")
        end

        brand2 = ActsAsTenant.with_tenant(workspace2) do
          create(:brand, name: "Brand 2")
        end

        # Try to find brand2 while in workspace1 context
        ActsAsTenant.with_tenant(workspace1) do
          expect { Brand.find(brand2.id) }.to raise_error(ActiveRecord::RecordNotFound)
        end

        # Can find brand1 in workspace1 context
        ActsAsTenant.with_tenant(workspace1) do
          expect(Brand.find(brand1.id)).to eq(brand1)
        end
      end

      it "scopes where queries to current tenant" do
        ActsAsTenant.with_tenant(workspace1) do
          create(:brand, name: "Active Brand", active: true)
          create(:brand, name: "Inactive Brand", active: false)
        end

        ActsAsTenant.with_tenant(workspace2) do
          create(:brand, name: "Another Active", active: true)
        end

        ActsAsTenant.with_tenant(workspace1) do
          active_brands = Brand.where(active: true)
          expect(active_brands.count).to eq(1)
          expect(active_brands.first.name).to eq("Active Brand")
        end
      end
    end

    describe "workspace uniqueness" do
      it "allows same name in different workspaces" do
        brand1 = ActsAsTenant.with_tenant(workspace1) do
          create(:brand, name: "Same Name")
        end

        brand2 = ActsAsTenant.with_tenant(workspace2) do
          create(:brand, name: "Same Name")
        end

        expect(brand1).to be_persisted
        expect(brand2).to be_persisted
        expect(brand1.name).to eq(brand2.name)
        expect(brand1.workspace_id).not_to eq(brand2.workspace_id)
      end

      it "enforces unique name within workspace" do
        ActsAsTenant.with_tenant(workspace1) do
          create(:brand, name: "Unique Name")
          duplicate = build(:brand, name: "Unique Name")

          expect(duplicate).not_to be_valid
          expect(duplicate.errors[:name]).to include("already exists in this workspace")
        end
      end
    end

    describe "scoped associations" do
      it "only returns associated records from current tenant" do
        brand1 = ActsAsTenant.with_tenant(workspace1) do
          create(:brand, name: "Brand 1")
        end

        brand2 = ActsAsTenant.with_tenant(workspace2) do
          create(:brand, name: "Brand 2")
        end

        ActsAsTenant.with_tenant(workspace1) do
          expect(workspace1.brands).to include(brand1)
          expect(workspace1.brands).not_to include(brand2)
        end
      end
    end

    describe "without tenant" do
      it "raises error when querying without tenant set" do
        ActsAsTenant.current_tenant = nil

        expect { Brand.all.to_a }.to raise_error(ActsAsTenant::Errors::NoTenantSet)
      end

      it "allows queries with without_tenant block" do
        brand1 = ActsAsTenant.with_tenant(workspace1) do
          create(:brand, name: "Brand 1")
        end

        brand2 = ActsAsTenant.with_tenant(workspace2) do
          create(:brand, name: "Brand 2")
        end

        ActsAsTenant.without_tenant do
          all_brands = Brand.all
          expect(all_brands).to include(brand1, brand2)
          expect(all_brands.count).to eq(2)
        end
      end
    end
  end
end

