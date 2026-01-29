# frozen_string_literal: true

require "rails_helper"

RSpec.describe Brand, type: :model do
  let(:workspace) { create(:workspace) }

  describe "associations" do
    it "belongs to workspace" do
      ActsAsTenant.with_tenant(workspace) do
        brand = build(:brand, workspace: workspace)
        expect(brand.workspace).to eq(workspace)

        # Test that workspace is required (test outside tenant context)
        ActsAsTenant.without_tenant do
          brand_without_workspace = build(:brand, workspace: nil)
          expect(brand_without_workspace).not_to be_valid
          expect(brand_without_workspace.errors[:workspace]).to be_present
        end
      end
    end
  end

  describe "validations" do
    it "validates presence of name" do
      ActsAsTenant.with_tenant(workspace) do
        brand = build(:brand)
        expect(brand).to validate_presence_of(:name)
      end
    end

    it "validates length of name" do
      ActsAsTenant.with_tenant(workspace) do
        brand = build(:brand)
        expect(brand).to validate_length_of(:name).is_at_least(1).is_at_most(100)
      end
    end

    it "validates length of description" do
      ActsAsTenant.with_tenant(workspace) do
        brand = build(:brand)
        expect(brand).to validate_length_of(:description).is_at_most(1000)
      end
    end

    describe "name uniqueness scoped to workspace" do
      it "validates uniqueness of name within workspace" do
        workspace = create(:workspace)
        ActsAsTenant.with_tenant(workspace) do
          create(:brand, workspace: workspace, name: "Acme Corp")

          duplicate = build(:brand, workspace: workspace, name: "Acme Corp")
          expect(duplicate).not_to be_valid
          expect(duplicate.errors[:name]).to include("already exists in this workspace")
        end
      end

      it "allows same name in different workspaces" do
        workspace1 = create(:workspace)
        workspace2 = create(:workspace)

        ActsAsTenant.with_tenant(workspace1) do
          create(:brand, workspace: workspace1, name: "Acme Corp")
        end

        ActsAsTenant.with_tenant(workspace2) do
          brand2 = build(:brand, workspace: workspace2, name: "Acme Corp")
          expect(brand2).to be_valid
        end
      end
    end

    describe "domain validation" do
      it "accepts valid domain names" do
        valid_domains = [
          "example.com",
          "subdomain.example.com",
          "my-company.co.uk",
          "test123.org"
        ]

        ActsAsTenant.with_tenant(workspace) do
          valid_domains.each do |domain|
            brand = build(:brand, domain: domain)
            expect(brand).to be_valid, "Expected #{domain} to be valid"
          end
        end
      end

      it "rejects invalid domain names" do
        invalid_domains = [
          "not a domain",
          "example",
          "-invalid.com",
          "invalid-.com"
        ]

        ActsAsTenant.with_tenant(workspace) do
          invalid_domains.each do |domain|
            brand = build(:brand, domain: domain)
            expect(brand).not_to be_valid, "Expected #{domain} to be invalid"
          end
        end
      end

      it "normalizes domains with protocols" do
        ActsAsTenant.with_tenant(workspace) do
          brand = create(:brand, domain: "http://example.com")
          expect(brand).to be_valid
          expect(brand.domain).to eq("example.com")
        end
      end

      it "allows blank domain" do
        ActsAsTenant.with_tenant(workspace) do
          brand = build(:brand, domain: nil)
          expect(brand).to be_valid
        end
      end
    end
  end

  describe "callbacks" do
    describe "#normalize_domain" do
      it "removes http:// protocol" do
        ActsAsTenant.with_tenant(workspace) do
          brand = create(:brand, domain: "http://example.com")
          expect(brand.domain).to eq("example.com")
        end
      end

      it "removes https:// protocol" do
        ActsAsTenant.with_tenant(workspace) do
          brand = create(:brand, domain: "https://example.com")
          expect(brand.domain).to eq("example.com")
        end
      end

      it "removes www. prefix" do
        ActsAsTenant.with_tenant(workspace) do
          brand = create(:brand, domain: "www.example.com")
          expect(brand.domain).to eq("example.com")
        end
      end

      it "removes trailing slash" do
        ActsAsTenant.with_tenant(workspace) do
          brand = create(:brand, domain: "example.com/")
          expect(brand.domain).to eq("example.com")
        end
      end

      it "converts to lowercase" do
        ActsAsTenant.with_tenant(workspace) do
          brand = create(:brand, domain: "EXAMPLE.COM")
          expect(brand.domain).to eq("example.com")
        end
      end

      it "handles complex normalization" do
        ActsAsTenant.with_tenant(workspace) do
          brand = create(:brand, domain: "HTTPS://WWW.EXAMPLE.COM/")
          expect(brand.domain).to eq("example.com")
        end
      end

      it "does not modify blank domain" do
        ActsAsTenant.with_tenant(workspace) do
          brand = create(:brand, domain: nil)
          expect(brand.domain).to be_nil
        end
      end
    end

    describe "#set_default_metadata" do
      it "sets default metadata on creation" do
        ActsAsTenant.with_tenant(workspace) do
          brand = create(:brand)
          expect(brand.metadata["created_by"]).to eq("system")
          expect(brand.metadata["keywords"]).to eq([])
        end
      end

      it "does not override existing metadata" do
        ActsAsTenant.with_tenant(workspace) do
          brand = create(:brand, metadata: { "created_by" => "user", "custom" => "value" })
          expect(brand.metadata["created_by"]).to eq("user")
          expect(brand.metadata["custom"]).to eq("value")
        end
      end
    end
  end

  describe "scopes" do
    describe ".active" do
      it "returns only active brands" do
        ActsAsTenant.with_tenant(workspace) do
          active_brand = create(:brand, workspace: workspace, active: true)
          inactive_brand = create(:brand, workspace: workspace, active: false)

          expect(Brand.active).to include(active_brand)
          expect(Brand.active).not_to include(inactive_brand)
        end
      end
    end

    describe ".inactive" do
      it "returns only inactive brands" do
        ActsAsTenant.with_tenant(workspace) do
          active_brand = create(:brand, workspace: workspace, active: true)
          inactive_brand = create(:brand, workspace: workspace, active: false)

          expect(Brand.inactive).to include(inactive_brand)
          expect(Brand.inactive).not_to include(active_brand)
        end
      end
    end

    describe ".recent" do
      it "orders brands by created_at DESC" do
        test_workspace = create(:workspace)
        ActsAsTenant.with_tenant(test_workspace) do
          old_brand = create(:brand, workspace: test_workspace, created_at: 2.days.ago)
          new_brand = create(:brand, workspace: test_workspace, created_at: 1.day.ago)

          recent_brands = test_workspace.brands.recent
          expect(recent_brands.first).to eq(new_brand)
          expect(recent_brands.last).to eq(old_brand)
        end
      end
    end

    describe ".by_name" do
      it "orders brands alphabetically by name" do
        test_workspace = create(:workspace)
        ActsAsTenant.with_tenant(test_workspace) do
          brand_b = create(:brand, workspace: test_workspace, name: "Beta Brand")
          brand_a = create(:brand, workspace: test_workspace, name: "Alpha Brand")

          sorted_brands = test_workspace.brands.by_name
          expect(sorted_brands.first).to eq(brand_a)
          expect(sorted_brands.last).to eq(brand_b)
        end
      end
    end

    describe ".by_workspace" do
      it "filters brands by workspace" do
        workspace1 = create(:workspace)
        workspace2 = create(:workspace)

        brand1 = ActsAsTenant.with_tenant(workspace1) do
          create(:brand, workspace: workspace1)
        end

        brand2 = ActsAsTenant.with_tenant(workspace2) do
          create(:brand, workspace: workspace2)
        end

        ActsAsTenant.without_tenant do
          expect(Brand.by_workspace(workspace1)).to include(brand1)
          expect(Brand.by_workspace(workspace1)).not_to include(brand2)
        end
      end
    end

    describe ".with_domain" do
      it "returns only brands with domain set" do
        ActsAsTenant.with_tenant(workspace) do
          brand_with_domain = create(:brand, domain: "example.com")
          brand_without_domain = create(:brand, domain: nil)

          expect(Brand.with_domain).to include(brand_with_domain)
          expect(Brand.with_domain).not_to include(brand_without_domain)
        end
      end
    end
  end

  describe "instance methods" do
    describe "#activate!" do
      it "sets active to true" do
        ActsAsTenant.with_tenant(workspace) do
          brand = create(:brand)
          brand.update!(active: false)
          brand.activate!
          expect(brand.reload.active).to be true
        end
      end
    end

    describe "#deactivate!" do
      it "sets active to false" do
        ActsAsTenant.with_tenant(workspace) do
          brand = create(:brand)
          brand.update!(active: true)
          brand.deactivate!
          expect(brand.reload.active).to be false
        end
      end
    end

    describe "#toggle_active!" do
      it "toggles active from true to false" do
        ActsAsTenant.with_tenant(workspace) do
          brand = create(:brand)
          brand.update!(active: true)
          brand.toggle_active!
          expect(brand.reload.active).to be false
        end
      end

      it "toggles active from false to true" do
        ActsAsTenant.with_tenant(workspace) do
          brand = create(:brand)
          brand.update!(active: false)
          brand.toggle_active!
          expect(brand.reload.active).to be true
        end
      end
    end

    describe "metadata methods" do
      describe "#get_metadata and #set_metadata" do
        it "gets and sets metadata values" do
          ActsAsTenant.with_tenant(workspace) do
            brand = create(:brand)
            brand.set_metadata("custom_key", "custom_value")
            expect(brand.get_metadata("custom_key")).to eq("custom_value")
          end
        end

        it "handles symbol keys" do
          ActsAsTenant.with_tenant(workspace) do
            brand = create(:brand)
            brand.set_metadata(:symbol_key, "value")
            expect(brand.get_metadata(:symbol_key)).to eq("value")
          end
        end
      end

      describe "#industry" do
        it "gets and sets industry metadata" do
          ActsAsTenant.with_tenant(workspace) do
            brand = create(:brand)
            brand.industry = "Technology"
            expect(brand.reload.industry).to eq("Technology")
          end
        end
      end

      describe "#keywords" do
        it "gets and sets keywords metadata" do
          ActsAsTenant.with_tenant(workspace) do
            brand = create(:brand)
            brand.keywords = [ "software", "saas" ]
            expect(brand.reload.keywords).to eq([ "software", "saas" ])
          end
        end

        it "returns empty array if keywords not set" do
          ActsAsTenant.with_tenant(workspace) do
            brand = create(:brand)
            brand.update!(metadata: {})
            expect(brand.keywords).to eq([])
          end
        end

        it "converts single value to array" do
          ActsAsTenant.with_tenant(workspace) do
            brand = create(:brand)
            brand.keywords = "single-keyword"
            expect(brand.reload.keywords).to eq([ "single-keyword" ])
          end
        end
      end
    end
  end
end
