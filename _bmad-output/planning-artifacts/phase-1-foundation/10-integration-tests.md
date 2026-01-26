# Task 10: Integration Tests & QA

**Estimated Time:** 6 hours  
**Priority:** Critical  
**Dependencies:** 01-rails-initialization, 02-database-setup, 03-devise-authentication, 04-core-models, 05-multi-tenancy

---

## Overview

Implement comprehensive integration and system testing to verify that all Phase 1 components work together correctly. This includes request specs for API-like controller testing, system specs with Capybara for browser-based testing, authentication flow verification, multi-tenancy isolation tests, and complete end-to-end user journeys.

**Key Goals:**
- Verify controller/request interactions
- Test complete user workflows with Capybara
- Validate authentication and authorization flows
- Ensure multi-tenancy data isolation
- Establish performance baselines
- Create manual QA checklist

---

## Test Pyramid Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Test Pyramid                            │
└─────────────────────────────────────────────────────────────┘

                    ▲
                   ╱ ╲
                  ╱   ╲
                 ╱ E2E ╲              ← System Specs (Capybara)
                ╱───────╲                 5-10 critical paths
               ╱         ╲                ~10% of tests
              ╱───────────╲
             ╱             ╲
            ╱  Integration  ╲         ← Request Specs
           ╱─────────────────╲           Controller tests
          ╱                   ╲          API-like testing
         ╱                     ╲         ~30% of tests
        ╱───────────────────────╲
       ╱                         ╲
      ╱         Unit Tests        ╲   ← Model/Service Specs
     ╱─────────────────────────────╲     Fast, isolated
    ╱                               ╲    ~60% of tests
   ╱_________________________________╲

```

**Testing Strategy:**
- **Unit Tests (60%)**: Models, services, helpers (covered in Task 09)
- **Integration Tests (30%)**: Request specs, controller interactions
- **System Tests (10%)**: End-to-end user journeys with Capybara

---

## Step 1: Configure Capybara for System Tests

### 1.1 Install Required Gems

Verify these gems are in your `Gemfile` (should be from Task 01):

```ruby
# Gemfile
group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "shoulda-matchers", "~> 5.3"
  gem "vcr", "~> 6.2"
  gem "webmock", "~> 3.19"
  gem "simplecov", require: false
end
```

```bash
bundle install
```

### 1.2 Configure Capybara in Rails Helper

Edit `spec/rails_helper.rb` to add Capybara configuration:

```ruby
# spec/rails_helper.rb
require 'capybara/rails'
require 'capybara/rspec'

# Capybara configuration
Capybara.register_driver :selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--disable-gpu')
  options.add_argument('--window-size=1400,1000')
  
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.javascript_driver = :selenium_chrome_headless
Capybara.default_max_wait_time = 5
Capybara.server = :puma, { Silent: true }

RSpec.configure do |config|
  # Existing configuration...
  
  # System test configuration
  config.before(:each, type: :system) do
    driven_by :selenium_chrome_headless
  end
end
```

### 1.3 Create System Spec Directory

```bash
mkdir -p spec/system
mkdir -p spec/requests
mkdir -p spec/support/shared_examples
```

---

## Step 2: Request Specs for Controllers

Request specs test your controllers like an API client would, without the browser overhead.

### 2.1 Authentication Request Specs

**File:** `spec/requests/authentication_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe "Authentication", type: :request do
  describe "POST /users/sign_in" do
    let(:user) { create(:user, password: 'password123') }
    
    context "with valid credentials" do
      it "signs in the user and redirects to root" do
        post user_session_path, params: {
          user: {
            email: user.email,
            password: 'password123'
          }
        }
        
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include(user.email)
      end
      
      it "sets the user session" do
        post user_session_path, params: {
          user: { email: user.email, password: 'password123' }
        }
        
        expect(session[:user_id]).to eq(user.id) if using_custom_auth
        # Or for Devise:
        expect(controller.current_user).to eq(user)
      end
    end
    
    context "with invalid credentials" do
      it "does not sign in and shows error" do
        post user_session_path, params: {
          user: { email: user.email, password: 'wrong' }
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Invalid')
      end
    end
  end
  
  describe "DELETE /users/sign_out" do
    let(:user) { create(:user) }
    
    before { sign_in user }
    
    it "signs out the user" do
      delete destroy_user_session_path
      
      expect(response).to redirect_to(root_path)
      expect(controller.current_user).to be_nil
    end
  end
  
  describe "POST /users" do
    context "with valid parameters" do
      let(:valid_params) do
        {
          user: {
            email: 'newuser@example.com',
            password: 'password123',
            password_confirmation: 'password123'
          }
        }
      end
      
      it "creates a new user" do
        expect {
          post user_registration_path, params: valid_params
        }.to change(User, :count).by(1)
      end
      
      it "creates a default workspace for the user" do
        expect {
          post user_registration_path, params: valid_params
        }.to change(Workspace, :count).by(1)
        
        user = User.last
        expect(user.workspaces.count).to eq(1)
        expect(user.workspace_memberships.first.role).to eq('owner')
      end
    end
    
    context "with invalid parameters" do
      it "does not create a user with mismatched passwords" do
        expect {
          post user_registration_path, params: {
            user: {
              email: 'test@example.com',
              password: 'password123',
              password_confirmation: 'different'
            }
          }
        }.not_to change(User, :count)
      end
    end
  end
end
```

### 2.2 Workspace Request Specs

**File:** `spec/requests/workspaces_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe "Workspaces", type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace) }
  let!(:membership) { create(:workspace_membership, user: user, workspace: workspace, role: 'admin') }

  before { sign_in user }

  describe "GET /workspaces" do
    it "returns a successful response" do
      get workspaces_path
      expect(response).to be_successful
    end

    it "displays user's workspaces" do
      get workspaces_path
      expect(response.body).to include(workspace.name)
    end

    it "does not display other users' workspaces" do
      other_workspace = create(:workspace, name: "Other Workspace")
      get workspaces_path
      expect(response.body).not_to include("Other Workspace")
    end
  end

  describe "POST /workspaces" do
    context "with valid parameters" do
      let(:valid_params) do
        { workspace: { name: "New Workspace" } }
      end

      it "creates a new workspace" do
        expect {
          post workspaces_path, params: valid_params
        }.to change(Workspace, :count).by(1)
      end

      it "creates workspace membership with owner role" do
        post workspaces_path, params: valid_params

        workspace = Workspace.last
        membership = workspace.workspace_memberships.find_by(user: user)
        expect(membership.role).to eq('owner')
      end

      it "redirects to the new workspace" do
        post workspaces_path, params: valid_params
        expect(response).to redirect_to(workspace_path(Workspace.last))
      end
    end

    context "with invalid parameters" do
      it "does not create a workspace without a name" do
        expect {
          post workspaces_path, params: { workspace: { name: "" } }
        }.not_to change(Workspace, :count)
      end
    end
  end

  describe "PATCH /workspaces/:slug" do
    context "as workspace admin" do
      it "updates the workspace" do
        patch workspace_path(workspace.slug), params: {
          workspace: { name: "Updated Name" }
        }

        expect(workspace.reload.name).to eq("Updated Name")
        expect(response).to redirect_to(workspace_path(workspace))
      end
    end

    context "as workspace viewer" do
      let!(:viewer_membership) do
        create(:workspace_membership, user: user, workspace: workspace, role: 'viewer')
      end

      it "denies access" do
        patch workspace_path(workspace.slug), params: {
          workspace: { name: "Hacked Name" }
        }

        expect(response).to have_http_status(:forbidden)
        expect(workspace.reload.name).not_to eq("Hacked Name")
      end
    end
  end

  describe "POST /workspaces/:slug/switch" do
    it "switches the current workspace" do
      post switch_workspace_path(workspace.slug)

      expect(session[:current_workspace_id]).to eq(workspace.id)
      expect(response).to redirect_to(workspace_path(workspace))
    end
  end
end
```

### 2.3 Brand Request Specs (Multi-Tenancy)

**File:** `spec/requests/brands_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe "Brands", type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace) }
  let!(:membership) { create(:workspace_membership, user: user, workspace: workspace, role: 'editor') }
  let!(:brand) { create(:brand, workspace: workspace) }

  # Another workspace to test isolation
  let(:other_workspace) { create(:workspace) }
  let!(:other_brand) { create(:brand, workspace: other_workspace, name: "Other Brand") }

  before do
    sign_in user
    # Set current workspace (simulating middleware)
    allow_any_instance_of(ApplicationController).to receive(:current_workspace).and_return(workspace)
  end

  describe "GET /:workspace_slug/brands" do
    it "returns brands for current workspace only" do
      get workspace_brands_path(workspace.slug)

      expect(response).to be_successful
      expect(response.body).to include(brand.name)
      expect(response.body).not_to include("Other Brand")
    end
  end

  describe "POST /:workspace_slug/brands" do
    context "with valid parameters" do
      let(:valid_params) do
        {
          brand: {
            name: "New Brand",
            domain: "newbrand.com",
            description: "A new brand"
          }
        }
      end

      it "creates a brand in the current workspace" do
        expect {
          post workspace_brands_path(workspace.slug), params: valid_params
        }.to change(workspace.brands, :count).by(1)
      end

      it "does not create brand in other workspace" do
        expect {
          post workspace_brands_path(workspace.slug), params: valid_params
        }.not_to change(other_workspace.brands, :count)
      end

      it "sets the workspace_id correctly" do
        post workspace_brands_path(workspace.slug), params: valid_params

        brand = Brand.last
        expect(brand.workspace_id).to eq(workspace.id)
      end
    end
  end

  describe "GET /:workspace_slug/brands/:id" do
    it "shows brand from current workspace" do
      get workspace_brand_path(workspace.slug, brand)
      expect(response).to be_successful
    end

    it "denies access to brand from other workspace" do
      expect {
        get workspace_brand_path(workspace.slug, other_brand)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "PATCH /:workspace_slug/brands/:id" do
    it "updates brand in current workspace" do
      patch workspace_brand_path(workspace.slug, brand), params: {
        brand: { name: "Updated Brand" }
      }

      expect(brand.reload.name).to eq("Updated Brand")
    end

    it "prevents updating brand from other workspace" do
      expect {
        patch workspace_brand_path(workspace.slug, other_brand), params: {
          brand: { name: "Hacked" }
        }
      }.to raise_error(ActiveRecord::RecordNotFound)

      expect(other_brand.reload.name).not_to eq("Hacked")
    end
  end

  describe "DELETE /:workspace_slug/brands/:id" do
    it "deletes brand from current workspace" do
      expect {
        delete workspace_brand_path(workspace.slug, brand)
      }.to change(workspace.brands, :count).by(-1)
    end

    it "prevents deleting brand from other workspace" do
      expect {
        delete workspace_brand_path(workspace.slug, other_brand)
      }.to raise_error(ActiveRecord::RecordNotFound)

      expect(Brand.exists?(other_brand.id)).to be true
    end
  end
end
```

---

## Step 3: System Specs with Capybara

System specs test complete user workflows through the browser.

### 3.1 User Registration and Onboarding Flow

**File:** `spec/system/user_registration_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe "User Registration", type: :system do
  before do
    driven_by(:selenium_chrome_headless)
  end

  scenario "User signs up and gets a default workspace" do
    visit root_path

    click_link "Sign Up"

    fill_in "Email", with: "newuser@example.com"
    fill_in "Password", with: "password123"
    fill_in "Password confirmation", with: "password123"

    expect {
      click_button "Sign Up"
    }.to change(User, :count).by(1)
     .and change(Workspace, :count).by(1)

    user = User.last
    expect(user.workspaces.count).to eq(1)
    expect(user.workspace_memberships.first.role).to eq('owner')

    # Should redirect to confirmation or dashboard
    expect(page).to have_content("Welcome")
  end

  scenario "User cannot sign up with invalid email" do
    visit new_user_registration_path

    fill_in "Email", with: "invalid-email"
    fill_in "Password", with: "password123"
    fill_in "Password confirmation", with: "password123"

    expect {
      click_button "Sign Up"
    }.not_to change(User, :count)

    expect(page).to have_content("Email is invalid")
  end

  scenario "User cannot sign up with mismatched passwords" do
    visit new_user_registration_path

    fill_in "Email", with: "test@example.com"
    fill_in "Password", with: "password123"
    fill_in "Password confirmation", with: "different"

    expect {
      click_button "Sign Up"
    }.not_to change(User, :count)

    expect(page).to have_content("Password confirmation doesn't match")
  end
end
```

### 3.2 Authentication Flow System Spec

**File:** `spec/system/authentication_flow_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe "Authentication Flow", type: :system do
  let(:user) { create(:user, email: 'user@example.com', password: 'password123') }

  before do
    driven_by(:selenium_chrome_headless)
  end

  scenario "User signs in and signs out" do
    visit root_path

    # Should redirect to sign in
    expect(page).to have_content("Sign In")

    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Sign In"

    # Should be signed in
    expect(page).to have_content(user.email)
    expect(page).to have_link("Sign Out")

    # Sign out
    click_link "Sign Out"

    # Should be signed out
    expect(page).to have_content("Sign In")
    expect(page).not_to have_content(user.email)
  end

  scenario "User cannot access protected pages when signed out" do
    visit workspaces_path

    expect(page).to have_content("Sign In")
    expect(current_path).to eq(new_user_session_path)
  end

  scenario "User is redirected to requested page after sign in" do
    workspace = create(:workspace)
    create(:workspace_membership, user: user, workspace: workspace)

    visit workspace_path(workspace.slug)

    # Should redirect to sign in
    expect(page).to have_content("Sign In")

    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Sign In"

    # Should redirect back to requested page
    expect(current_path).to eq(workspace_path(workspace.slug))
  end
end
```

### 3.3 Workspace Switching System Spec

**File:** `spec/system/workspace_switching_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe "Workspace Switching", type: :system do
  let(:user) { create(:user) }
  let(:workspace1) { create(:workspace, name: "Workspace One") }
  let(:workspace2) { create(:workspace, name: "Workspace Two") }

  before do
    driven_by(:selenium_chrome_headless)

    create(:workspace_membership, user: user, workspace: workspace1, role: 'admin')
    create(:workspace_membership, user: user, workspace: workspace2, role: 'editor')

    sign_in user
  end

  scenario "User switches between workspaces" do
    visit workspaces_path

    # Should see both workspaces
    expect(page).to have_content("Workspace One")
    expect(page).to have_content("Workspace Two")

    # Switch to workspace 1
    click_link "Workspace One"

    expect(page).to have_content("Workspace One")
    expect(current_path).to eq(workspace_path(workspace1.slug))

    # Navigate back to workspaces list
    visit workspaces_path

    # Switch to workspace 2
    click_link "Workspace Two"

    expect(page).to have_content("Workspace Two")
    expect(current_path).to eq(workspace_path(workspace2.slug))
  end

  scenario "User sees only their workspaces" do
    other_workspace = create(:workspace, name: "Other Workspace")

    visit workspaces_path

    expect(page).to have_content("Workspace One")
    expect(page).to have_content("Workspace Two")
    expect(page).not_to have_content("Other Workspace")
  end
end
```

### 3.4 Brand CRUD System Spec

**File:** `spec/system/brand_management_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe "Brand Management", type: :system do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace) }

  before do
    driven_by(:selenium_chrome_headless)

    create(:workspace_membership, user: user, workspace: workspace, role: 'admin')
    sign_in user
    visit workspace_path(workspace.slug)
  end

  scenario "User creates a new brand" do
    click_link "Brands"
    click_link "New Brand"

    fill_in "Name", with: "Test Brand"
    fill_in "Domain", with: "testbrand.com"
    fill_in "Description", with: "A test brand for testing"

    expect {
      click_button "Create Brand"
    }.to change(Brand, :count).by(1)

    expect(page).to have_content("Brand was successfully created")
    expect(page).to have_content("Test Brand")
    expect(page).to have_content("testbrand.com")
  end

  scenario "User edits an existing brand" do
    brand = create(:brand, workspace: workspace, name: "Original Name")

    visit workspace_brands_path(workspace.slug)

    click_link "Original Name"
    click_link "Edit"

    fill_in "Name", with: "Updated Name"
    click_button "Update Brand"

    expect(page).to have_content("Brand was successfully updated")
    expect(page).to have_content("Updated Name")
    expect(page).not_to have_content("Original Name")
  end

  scenario "User deletes a brand" do
    brand = create(:brand, workspace: workspace, name: "Brand to Delete")

    visit workspace_brands_path(workspace.slug)

    expect(page).to have_content("Brand to Delete")

    accept_confirm do
      click_link "Delete"
    end

    expect(page).to have_content("Brand was successfully deleted")
    expect(page).not_to have_content("Brand to Delete")
  end

  scenario "User cannot see brands from other workspaces" do
    other_workspace = create(:workspace)
    other_brand = create(:brand, workspace: other_workspace, name: "Other Brand")

    visit workspace_brands_path(workspace.slug)

    expect(page).not_to have_content("Other Brand")
  end
end
```

---

## Step 4: Multi-Tenancy Isolation Tests

### 4.1 Shared Examples for Multi-Tenancy

**File:** `spec/support/shared_examples/multi_tenancy.rb`

```ruby
# Shared examples for testing multi-tenancy isolation
RSpec.shared_examples "multi-tenant resource" do |resource_factory, workspace_association|
  let(:user) { create(:user) }
  let(:workspace1) { create(:workspace) }
  let(:workspace2) { create(:workspace) }
  let!(:membership1) { create(:workspace_membership, user: user, workspace: workspace1, role: 'admin') }
  let!(:membership2) { create(:workspace_membership, user: user, workspace: workspace2, role: 'admin') }

  let!(:resource1) { create(resource_factory, workspace_association => workspace1) }
  let!(:resource2) { create(resource_factory, workspace_association => workspace2) }

  before { sign_in user }

  it "scopes resources to current workspace" do
    # Set current workspace to workspace1
    allow_any_instance_of(ApplicationController)
      .to receive(:current_workspace).and_return(workspace1)

    get polymorphic_path([workspace1, resource_factory.to_s.pluralize])

    expect(response.body).to include(resource1.name)
    expect(response.body).not_to include(resource2.name)
  end

  it "prevents access to resources from other workspaces" do
    allow_any_instance_of(ApplicationController)
      .to receive(:current_workspace).and_return(workspace1)

    expect {
      get polymorphic_path([workspace1, resource2])
    }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "prevents updating resources from other workspaces" do
    allow_any_instance_of(ApplicationController)
      .to receive(:current_workspace).and_return(workspace1)

    expect {
      patch polymorphic_path([workspace1, resource2]), params: {
        resource_factory => { name: "Hacked" }
      }
    }.to raise_error(ActiveRecord::RecordNotFound)

    expect(resource2.reload.name).not_to eq("Hacked")
  end
end
```

### 4.2 Using Shared Examples

**File:** `spec/requests/multi_tenancy/brands_isolation_spec.rb`

```ruby
require 'rails_helper'
require 'support/shared_examples/multi_tenancy'

RSpec.describe "Brand Multi-Tenancy Isolation", type: :request do
  it_behaves_like "multi-tenant resource", :brand, :workspace
end
```

---

## Step 5: End-to-End User Journey Tests

### 5.1 Complete User Journey

**File:** `spec/system/complete_user_journey_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe "Complete User Journey", type: :system do
  before do
    driven_by(:selenium_chrome_headless)
  end

  scenario "New user signs up, creates workspace, and manages brands" do
    # Step 1: Sign up
    visit root_path
    click_link "Sign Up"

    fill_in "Email", with: "journey@example.com"
    fill_in "Password", with: "password123"
    fill_in "Password confirmation", with: "password123"

    click_button "Sign Up"

    # Step 2: Verify default workspace created
    user = User.find_by(email: "journey@example.com")
    expect(user.workspaces.count).to eq(1)
    default_workspace = user.workspaces.first

    # Step 3: Sign in (if not auto-signed in)
    unless page.has_content?(user.email)
      visit new_user_session_path
      fill_in "Email", with: "journey@example.com"
      fill_in "Password", with: "password123"
      click_button "Sign In"
    end

    # Step 4: Navigate to workspace
    visit workspace_path(default_workspace.slug)
    expect(page).to have_content(default_workspace.name)

    # Step 5: Create a brand
    click_link "Brands"
    click_link "New Brand"

    fill_in "Name", with: "My First Brand"
    fill_in "Domain", with: "myfirstbrand.com"
    fill_in "Description", with: "This is my first brand"

    click_button "Create Brand"

    expect(page).to have_content("Brand was successfully created")
    expect(page).to have_content("My First Brand")

    # Step 6: Edit the brand
    click_link "Edit"
    fill_in "Name", with: "My Updated Brand"
    click_button "Update Brand"

    expect(page).to have_content("Brand was successfully updated")
    expect(page).to have_content("My Updated Brand")

    # Step 7: Create another workspace
    visit workspaces_path
    click_link "New Workspace"

    fill_in "Name", with: "Second Workspace"
    click_button "Create Workspace"

    expect(page).to have_content("Workspace was successfully created")

    # Step 8: Verify brand isolation
    second_workspace = user.workspaces.find_by(name: "Second Workspace")
    visit workspace_brands_path(second_workspace.slug)

    expect(page).not_to have_content("My Updated Brand")

    # Step 9: Sign out
    click_link "Sign Out"
    expect(page).to have_content("Sign In")
  end
end
```

---

## Step 6: Performance Testing Basics

### 6.1 Performance Benchmarks

**File:** `spec/performance/database_queries_spec.rb`

```ruby
require 'rails_helper'
require 'benchmark'

RSpec.describe "Database Query Performance", type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace) }

  before do
    create(:workspace_membership, user: user, workspace: workspace, role: 'admin')
    sign_in user
  end

  describe "N+1 query prevention" do
    it "loads brands with workspace in constant queries" do
      # Create test data
      create_list(:brand, 10, workspace: workspace)

      # Warm up
      get workspace_brands_path(workspace.slug)

      # Measure queries
      queries = []
      ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
        queries << args.last[:sql] unless args.last[:sql].include?('SCHEMA')
      end

      get workspace_brands_path(workspace.slug)

      # Should not have N+1 queries
      # Expect: 1 query for brands, maybe 1 for workspace
      expect(queries.count).to be <= 3
    end
  end

  describe "Response time benchmarks" do
    it "loads workspace brands page in under 200ms" do
      create_list(:brand, 20, workspace: workspace)

      time = Benchmark.realtime do
        get workspace_brands_path(workspace.slug)
      end

      expect(time).to be < 0.2 # 200ms
      expect(response).to be_successful
    end

    it "creates a brand in under 100ms" do
      time = Benchmark.realtime do
        post workspace_brands_path(workspace.slug), params: {
          brand: {
            name: "Performance Test Brand",
            domain: "perftest.com"
          }
        }
      end

      expect(time).to be < 0.1 # 100ms
      expect(response).to have_http_status(:redirect)
    end
  end
end
```

### 6.2 Load Testing Helper

**File:** `spec/support/performance_helpers.rb`

```ruby
module PerformanceHelpers
  def measure_time(&block)
    start_time = Time.current
    result = block.call
    end_time = Time.current

    {
      result: result,
      duration: end_time - start_time
    }
  end

  def expect_fast_query(max_time: 0.1, &block)
    measurement = measure_time(&block)
    expect(measurement[:duration]).to be < max_time
    measurement[:result]
  end

  def count_queries(&block)
    queries = []
    ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
      queries << args.last[:sql] unless args.last[:sql].include?('SCHEMA')
    end

    block.call
    queries.count
  end
end

RSpec.configure do |config|
  config.include PerformanceHelpers, type: :request
  config.include PerformanceHelpers, type: :system
end
```

---

## Step 7: Test Helpers and Support Files

### 7.1 Authentication Helpers

**File:** `spec/support/authentication_helpers.rb`

```ruby
module AuthenticationHelpers
  # For Devise
  def sign_in(user)
    if respond_to?(:visit)
      # System/feature specs
      visit new_user_session_path
      fill_in "Email", with: user.email
      fill_in "Password", with: user.password || 'password123'
      click_button "Sign In"
    else
      # Request specs
      post user_session_path, params: {
        user: {
          email: user.email,
          password: user.password || 'password123'
        }
      }
    end
  end

  def sign_out
    if respond_to?(:visit)
      click_link "Sign Out"
    else
      delete destroy_user_session_path
    end
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
  config.include AuthenticationHelpers, type: :system
  config.include Devise::Test::IntegrationHelpers, type: :request
end
```

### 7.2 Workspace Context Helpers

**File:** `spec/support/workspace_helpers.rb`

```ruby
module WorkspaceHelpers
  def set_current_workspace(workspace)
    allow_any_instance_of(ApplicationController)
      .to receive(:current_workspace).and_return(workspace)

    # Also set in session if using session-based workspace switching
    if respond_to?(:session)
      session[:current_workspace_id] = workspace.id
    end
  end

  def within_workspace(workspace, &block)
    original_workspace = @current_workspace
    set_current_workspace(workspace)
    block.call
    set_current_workspace(original_workspace) if original_workspace
  end
end

RSpec.configure do |config|
  config.include WorkspaceHelpers, type: :request
  config.include WorkspaceHelpers, type: :system
end
```

---

## Step 8: Running the Tests

### 8.1 Run All Integration Tests

```bash
# Run all request specs
bundle exec rspec spec/requests

# Run all system specs
bundle exec rspec spec/system

# Run all integration tests (request + system)
bundle exec rspec spec/requests spec/system

# Run with documentation format
bundle exec rspec spec/requests spec/system --format documentation

# Run specific test file
bundle exec rspec spec/requests/authentication_spec.rb

# Run specific test by line number
bundle exec rspec spec/system/user_registration_spec.rb:10
```

### 8.2 Run Tests with Coverage

```bash
# Run all tests with SimpleCov coverage
COVERAGE=true bundle exec rspec

# View coverage report
open coverage/index.html
```

### 8.3 Run Performance Tests

```bash
# Run performance benchmarks
bundle exec rspec spec/performance --format documentation

# Run with profiling
bundle exec rspec spec/performance --profile
```

---

## Step 9: Manual QA Checklist

### 9.1 Authentication & Authorization

**Manual Testing Checklist:**

- [ ] **User Registration**
  - [ ] Can register with valid email and password
  - [ ] Cannot register with invalid email format
  - [ ] Cannot register with password < 6 characters
  - [ ] Cannot register with mismatched password confirmation
  - [ ] Receives confirmation email (if implemented)
  - [ ] Default workspace is created automatically
  - [ ] User is set as owner of default workspace

- [ ] **User Sign In**
  - [ ] Can sign in with valid credentials
  - [ ] Cannot sign in with invalid password
  - [ ] Cannot sign in with non-existent email
  - [ ] Redirected to originally requested page after sign in
  - [ ] Session persists across page refreshes
  - [ ] "Remember me" functionality works (if implemented)

- [ ] **User Sign Out**
  - [ ] Can sign out successfully
  - [ ] Session is cleared after sign out
  - [ ] Cannot access protected pages after sign out
  - [ ] Redirected to sign in page when accessing protected pages

- [ ] **Password Reset** (if implemented)
  - [ ] Can request password reset
  - [ ] Receives password reset email
  - [ ] Can reset password with valid token
  - [ ] Cannot reset password with expired token
  - [ ] Cannot reset password with invalid token

### 9.2 Multi-Tenancy & Workspaces

- [ ] **Workspace Management**
  - [ ] Can view list of workspaces user belongs to
  - [ ] Cannot see workspaces user doesn't belong to
  - [ ] Can create new workspace
  - [ ] Creator is automatically set as owner
  - [ ] Can edit workspace as admin/owner
  - [ ] Cannot edit workspace as viewer
  - [ ] Can delete workspace as owner
  - [ ] Cannot delete workspace as non-owner

- [ ] **Workspace Switching**
  - [ ] Can switch between workspaces
  - [ ] Current workspace persists in session
  - [ ] URL reflects current workspace (/:workspace_slug/...)
  - [ ] Cannot access workspace user is not a member of
  - [ ] Workspace context is maintained across navigation

- [ ] **Data Isolation**
  - [ ] Brands from workspace A not visible in workspace B
  - [ ] Cannot access brands from other workspaces via URL manipulation
  - [ ] Cannot edit brands from other workspaces
  - [ ] Cannot delete brands from other workspaces
  - [ ] All queries are properly scoped to current workspace

### 9.3 Brand Management

- [ ] **Brand CRUD Operations**
  - [ ] Can create brand with valid data
  - [ ] Cannot create brand without required fields
  - [ ] Can view brand details
  - [ ] Can edit brand as editor/admin
  - [ ] Cannot edit brand as viewer
  - [ ] Can delete brand as admin
  - [ ] Cannot delete brand as viewer/editor
  - [ ] Brand is associated with correct workspace

- [ ] **Brand Validation**
  - [ ] Name is required
  - [ ] Domain format is validated
  - [ ] Duplicate brand names are handled appropriately
  - [ ] Description has reasonable length limits

### 9.4 Role-Based Access Control

- [ ] **Owner Role**
  - [ ] Can manage workspace settings
  - [ ] Can add/remove members
  - [ ] Can change member roles
  - [ ] Can delete workspace
  - [ ] Can create/edit/delete all resources

- [ ] **Admin Role**
  - [ ] Can manage workspace settings
  - [ ] Can add/remove members (except owner)
  - [ ] Can create/edit/delete all resources
  - [ ] Cannot delete workspace

- [ ] **Editor Role**
  - [ ] Can create resources
  - [ ] Can edit own resources
  - [ ] Can view all resources
  - [ ] Cannot delete resources
  - [ ] Cannot manage workspace settings
  - [ ] Cannot manage members

- [ ] **Viewer Role**
  - [ ] Can view all resources
  - [ ] Cannot create resources
  - [ ] Cannot edit resources
  - [ ] Cannot delete resources
  - [ ] Cannot manage workspace settings
  - [ ] Cannot manage members

---

## Step 10: Browser Compatibility Testing

### 10.1 Supported Browsers

Test the application in the following browsers:

- [ ] **Chrome** (latest version)
  - [ ] Desktop
  - [ ] Mobile (Android)

- [ ] **Firefox** (latest version)
  - [ ] Desktop

- [ ] **Safari** (latest version)
  - [ ] Desktop (macOS)
  - [ ] Mobile (iOS)

- [ ] **Edge** (latest version)
  - [ ] Desktop

### 10.2 Browser-Specific Tests

For each browser, verify:

- [ ] Sign in/sign out works
- [ ] Forms submit correctly
- [ ] JavaScript interactions work (dropdowns, modals, etc.)
- [ ] CSS renders correctly
- [ ] Responsive design works on mobile
- [ ] No console errors

---

## Step 11: Accessibility Basics

### 11.1 Accessibility Checklist

- [ ] **Keyboard Navigation**
  - [ ] Can navigate entire site with keyboard only
  - [ ] Tab order is logical
  - [ ] Focus indicators are visible
  - [ ] Can submit forms with Enter key
  - [ ] Can close modals with Escape key

- [ ] **Screen Reader Support**
  - [ ] Form labels are properly associated
  - [ ] Error messages are announced
  - [ ] Success messages are announced
  - [ ] Images have alt text
  - [ ] Links have descriptive text

- [ ] **Visual Accessibility**
  - [ ] Color contrast meets WCAG AA standards
  - [ ] Text is readable at 200% zoom
  - [ ] No information conveyed by color alone
  - [ ] Focus states are clearly visible

- [ ] **Form Accessibility**
  - [ ] All inputs have labels
  - [ ] Required fields are marked
  - [ ] Error messages are clear and specific
  - [ ] Validation errors are associated with inputs

### 11.2 Automated Accessibility Testing

Add to your system specs:

```ruby
# spec/system/accessibility_spec.rb
require 'rails_helper'

RSpec.describe "Accessibility", type: :system do
  before do
    driven_by(:selenium_chrome_headless)
  end

  scenario "Sign in page is accessible" do
    visit new_user_session_path

    # Check for form labels
    expect(page).to have_css('label[for="user_email"]')
    expect(page).to have_css('label[for="user_password"]')

    # Check for submit button
    expect(page).to have_button('Sign In')
  end

  scenario "Forms have proper ARIA attributes" do
    visit new_user_registration_path

    # Check for required fields
    expect(page).to have_css('input[required]')

    # Submit form with errors
    click_button "Sign Up"

    # Check for error messages
    expect(page).to have_css('[role="alert"]', text: /error/i)
  end
end
```

---

## Success Criteria

### Phase 1 Integration Testing Complete When:

- [ ] **Request Specs Coverage**
  - [ ] Authentication flows tested (sign up, sign in, sign out)
  - [ ] Workspace CRUD operations tested
  - [ ] Brand CRUD operations tested
  - [ ] Multi-tenancy isolation verified
  - [ ] Authorization rules tested for all roles

- [ ] **System Specs Coverage**
  - [ ] User registration journey tested
  - [ ] Authentication flow tested
  - [ ] Workspace switching tested
  - [ ] Brand management tested
  - [ ] Complete end-to-end user journey tested

- [ ] **Multi-Tenancy Verification**
  - [ ] Data isolation between workspaces confirmed
  - [ ] Cross-workspace access prevented
  - [ ] Workspace scoping works for all resources
  - [ ] Role-based access control enforced

- [ ] **Performance Baselines**
  - [ ] No N+1 queries in main flows
  - [ ] Page load times under 200ms
  - [ ] Create operations under 100ms
  - [ ] Performance benchmarks documented

- [ ] **Test Infrastructure**
  - [ ] Capybara configured and working
  - [ ] Test helpers created and documented
  - [ ] Shared examples for multi-tenancy
  - [ ] Performance testing utilities

- [ ] **Manual QA**
  - [ ] All manual QA checklist items verified
  - [ ] Browser compatibility tested
  - [ ] Accessibility basics verified
  - [ ] No critical bugs found

- [ ] **Documentation**
  - [ ] Test running instructions documented
  - [ ] Coverage reports generated
  - [ ] Known issues documented
  - [ ] Next steps identified

---

## Troubleshooting

### Issue: Capybara tests fail with "element not found"

**Cause:** Elements not loaded yet or JavaScript not executed

**Solution:**
```ruby
# Increase wait time
Capybara.default_max_wait_time = 10

# Or use explicit waits
expect(page).to have_content("Expected text", wait: 10)

# Wait for AJAX
expect(page).to have_css('.loading-spinner', visible: false)
```

### Issue: "Database is not empty" errors

**Cause:** Database not cleaned between tests

**Solution:**
```ruby
# spec/rails_helper.rb
config.use_transactional_fixtures = true

# For system tests with JavaScript
config.before(:each, type: :system) do
  DatabaseCleaner.strategy = :truncation
end

config.after(:each, type: :system) do
  DatabaseCleaner.clean
end
```

### Issue: Chrome driver not found

**Cause:** ChromeDriver not installed or not in PATH

**Solution:**
```bash
# Install ChromeDriver
brew install chromedriver

# Or use webdrivers gem (auto-installs)
# Add to Gemfile
gem 'webdrivers', '~> 5.0'
```

### Issue: Tests pass individually but fail when run together

**Cause:** Test pollution or shared state

**Solution:**
```ruby
# Use let! instead of before blocks for test data
let!(:user) { create(:user) }

# Clear caches between tests
config.before(:each) do
  Rails.cache.clear
end

# Check for instance variables in controllers
# Use proper scoping in tests
```

### Issue: Slow test suite

**Cause:** Too many system tests or inefficient database setup

**Solution:**
```ruby
# Use request specs instead of system specs where possible
# Request specs are 10x faster

# Use build_stubbed for tests that don't need database
let(:user) { build_stubbed(:user) }

# Run tests in parallel
bundle exec rspec --parallel

# Profile slow tests
bundle exec rspec --profile 10
```

### Issue: Multi-tenancy tests failing

**Cause:** Current workspace not set correctly

**Solution:**
```ruby
# Make sure to set current workspace in tests
before do
  allow_any_instance_of(ApplicationController)
    .to receive(:current_workspace).and_return(workspace)
end

# Or use helper
set_current_workspace(workspace)

# Verify in controller
def current_workspace
  @current_workspace ||= begin
    workspace = current_user.workspaces.find_by(slug: params[:workspace_slug])
    raise ActiveRecord::RecordNotFound unless workspace
    workspace
  end
end
```

---

## Performance Optimization Tips

### 1. Reduce Database Queries

```ruby
# Bad: N+1 queries
@brands = @workspace.brands
@brands.each { |brand| brand.workspace.name }

# Good: Eager loading
@brands = @workspace.brands.includes(:workspace)
```

### 2. Use Database Indexes

```ruby
# Add indexes for foreign keys and frequently queried columns
add_index :brands, :workspace_id
add_index :brands, [:workspace_id, :active]
add_index :workspace_memberships, [:user_id, :workspace_id], unique: true
```

### 3. Cache Expensive Queries

```ruby
# Cache workspace count
def workspace_count
  Rails.cache.fetch("user_#{id}_workspace_count", expires_in: 1.hour) do
    workspaces.count
  end
end
```

### 4. Use Counter Caches

```ruby
# Add counter cache column
add_column :workspaces, :brands_count, :integer, default: 0

# Update model
class Brand < ApplicationRecord
  belongs_to :workspace, counter_cache: true
end

# Now workspace.brands_count is instant
```

---

## Next Steps After Integration Testing

### 1. Code Coverage Analysis

```bash
# Generate coverage report
COVERAGE=true bundle exec rspec

# Aim for:
# - 90%+ coverage for models
# - 80%+ coverage for controllers
# - 70%+ coverage overall
```

### 2. Continuous Integration Setup

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.2
      - name: Install dependencies
        run: bundle install
      - name: Setup database
        run: |
          bundle exec rails db:create
          bundle exec rails db:schema:load
      - name: Run tests
        run: bundle exec rspec
```

### 3. Security Testing

- [ ] Run Brakeman for security vulnerabilities
- [ ] Check for SQL injection vulnerabilities
- [ ] Verify CSRF protection
- [ ] Test authentication bypass attempts
- [ ] Verify authorization rules

### 4. Load Testing (Future Phase)

- [ ] Set up load testing with tools like Apache Bench or k6
- [ ] Test concurrent user scenarios
- [ ] Identify bottlenecks
- [ ] Optimize slow endpoints

### 5. Move to Phase 2

Once all integration tests pass and manual QA is complete:
- [ ] Document Phase 1 completion
- [ ] Create Phase 1 release notes
- [ ] Tag Phase 1 in version control
- [ ] Begin Phase 2 planning

---

## Summary

You've now implemented comprehensive integration and system testing for Phase 1:

✅ **Request Specs** - API-like controller testing
✅ **System Specs** - Browser-based end-to-end testing
✅ **Multi-Tenancy Tests** - Data isolation verification
✅ **Performance Tests** - Baseline benchmarks
✅ **Manual QA Checklist** - Comprehensive testing guide
✅ **Accessibility Testing** - Basic WCAG compliance
✅ **Browser Compatibility** - Cross-browser verification

**Total Test Coverage:**
- Unit Tests: ~60% of test suite
- Integration Tests: ~30% of test suite
- System Tests: ~10% of test suite

**Estimated Time Breakdown:**
- Capybara setup: 30 minutes
- Request specs: 2 hours
- System specs: 2 hours
- Multi-tenancy tests: 1 hour
- Manual QA: 30 minutes

**Phase 1 is complete when all tests pass and manual QA is verified!** 🎉

---

## Additional Resources

- [RSpec Documentation](https://rspec.info/)
- [Capybara Documentation](https://github.com/teamcapybara/capybara)
- [Rails Testing Guide](https://guides.rubyonrails.org/testing.html)
- [Better Specs](https://www.betterspecs.org/)
- [WCAG Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [SimpleCov Documentation](https://github.com/simplecov-ruby/simplecov)
