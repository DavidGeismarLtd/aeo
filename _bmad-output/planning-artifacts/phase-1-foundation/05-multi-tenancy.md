# Task 05: Multi-Tenancy Implementation with acts_as_tenant

**Estimated Time:** 6 hours
**Priority:** High
**Dependencies:** 01-setup, 02-models, 03-authentication

---

## Overview

Implement a robust multi-tenancy system using the **acts_as_tenant** gem, where all resources are automatically scoped to workspaces. Users can belong to multiple workspaces with different roles (owner, admin, editor, viewer), and all data access is automatically filtered by the current workspace context.

### Why acts_as_tenant?

The `acts_as_tenant` gem provides automatic tenant scoping for Rails applications:

- **Automatic Query Scoping**: All queries are automatically scoped to the current tenant
- **Safety**: Prevents accidental cross-tenant data leaks
- **Simplicity**: Minimal configuration required
- **Performance**: Uses efficient database-level scoping
- **Flexibility**: Works with any tenant model (we use Workspace)

### What acts_as_tenant Does vs. What We Still Need

| Feature | acts_as_tenant | Custom Code |
|---------|----------------|-------------|
| Automatic query scoping | ✅ Built-in | ❌ |
| Setting current tenant | ✅ Built-in | ❌ |
| Validating tenant presence | ✅ Built-in | ❌ |
| Role-based authorization | ❌ | ✅ Required |
| Workspace membership | ❌ | ✅ Required |
| Workspace switching UI | ❌ | ✅ Required |

---

## Architecture Pattern

### Multi-Tenancy Flow with acts_as_tenant

```
┌─────────────────────────────────────────────────────────────┐
│                     User Authentication                      │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│              URL: /:workspace_slug/...                       │
│              Extract workspace_slug from params              │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│         Find Workspace & Verify User Membership              │
│         ActsAsTenant.current_tenant = workspace              │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│              Authorization Check (Role-Based)                │
│              - owner: full access + billing                  │
│              - admin: full access                            │
│              - editor: create, read, update                  │
│              - viewer: read only                             │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│    acts_as_tenant AUTOMATICALLY Scopes All Queries           │
│    Brand.all → Only brands in current workspace              │
│    Project.create → Automatically assigned to workspace      │
└─────────────────────────────────────────────────────────────┘
```

### How acts_as_tenant Works

**Before acts_as_tenant (Manual Scoping):**
```ruby
# ❌ Easy to forget scoping - DANGEROUS!
@brands = Brand.all  # Returns ALL brands from ALL workspaces!

# ✅ Must remember to scope every query
@brands = @current_workspace.brands.all
@brand = @current_workspace.brands.find(params[:id])
@brand = @current_workspace.brands.create(brand_params)
```

**After acts_as_tenant (Automatic Scoping):**
```ruby
# ✅ Automatically scoped - SAFE!
ActsAsTenant.current_tenant = @current_workspace

@brands = Brand.all  # Only brands in current workspace
@brand = Brand.find(params[:id])  # Only finds in current workspace
@brand = Brand.create(brand_params)  # Automatically assigned to workspace
```

---

## Step 1: Install and Configure acts_as_tenant

### 1.1 Verify Gem Installation

The `acts_as_tenant` gem should already be in your Gemfile from Task 01:

```ruby
# Gemfile
gem "acts_as_tenant"
```

If not already installed:
```bash
bundle add acts_as_tenant
bundle install
```

### 1.2 Configure acts_as_tenant Initializer

Create an initializer to configure acts_as_tenant behavior:

### File: `config/initializers/acts_as_tenant.rb`

```ruby
# Configure acts_as_tenant gem
ActsAsTenant.configure do |config|
  # Require tenant to be set for all requests
  # This prevents accidentally querying without a tenant
  config.require_tenant = true

  # Raise error if tenant is not set (recommended for development)
  # In production, you might want to handle this more gracefully
  config.pkey = :id
end
```

**Configuration Options Explained:**

- `require_tenant = true`: Forces all queries to have a tenant set. This is a safety feature that prevents accidental cross-tenant data leaks.
- `pkey = :id`: Specifies the primary key column name (default is :id)

---

## Step 2: Update Models to Use acts_as_tenant

### 2.1 How acts_as_tenant Works in Models

When you add `acts_as_tenant :workspace` to a model:

1. **Automatic Scoping**: All queries are scoped to `ActsAsTenant.current_tenant`
2. **Automatic Assignment**: New records automatically get `workspace_id` set
3. **Validation**: Ensures `workspace_id` is always present
4. **Foreign Key**: Expects a `workspace_id` column in the table

### 2.2 Update Brand Model

### File: `app/models/brand.rb`

```ruby
class Brand < ApplicationRecord
  # acts_as_tenant automatically:
  # 1. Scopes all queries to current tenant (workspace)
  # 2. Validates presence of workspace_id
  # 3. Sets workspace_id on new records
  acts_as_tenant :workspace

  # Associations
  has_many :projects, dependent: :destroy
  has_many :brand_assets, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :workspace_id }

  # Callbacks
  before_validation :generate_slug, if: -> { slug.blank? }

  private

  def generate_slug
    self.slug = name.parameterize if name.present?
  end
end
```

### 2.3 Update Other Models

Apply `acts_as_tenant` to all workspace-scoped models:

### File: `app/models/project.rb`

```ruby
class Project < ApplicationRecord
  acts_as_tenant :workspace

  belongs_to :brand
  belongs_to :created_by, class_name: "User"
  has_many :tasks, dependent: :destroy
  has_many :documents, dependent: :destroy

  validates :name, presence: true
  validates :status, inclusion: { in: %w[planning active on_hold completed archived] }
end
```

### File: `app/models/task.rb`

```ruby
class Task < ApplicationRecord
  acts_as_tenant :workspace

  belongs_to :project
  belongs_to :assigned_to, class_name: "User", optional: true

  validates :title, presence: true
  validates :status, inclusion: { in: %w[todo in_progress review done] }
end
```

### 2.4 Models That Should NOT Use acts_as_tenant

Some models are global and should NOT be scoped to workspaces:

```ruby
# ❌ Do NOT add acts_as_tenant to these models:
class User < ApplicationRecord
  # Users are global - they can belong to multiple workspaces
end

class Workspace < ApplicationRecord
  # Workspace is the tenant itself
end

class WorkspaceMembership < ApplicationRecord
  # Memberships link users to workspaces - not scoped to a single workspace
end
```

---

## Step 3: Create Authorization Concern

**Important**: `acts_as_tenant` handles **tenant scoping** (which workspace), but NOT **authorization** (what users can do). We still need custom role-based authorization.

### File: `app/controllers/concerns/authorization.rb`

```ruby
module Authorization
  extend ActiveSupport::Concern

  included do
    rescue_from NotAuthorizedError, with: :handle_not_authorized
  end

  class NotAuthorizedError < StandardError; end

  # Check if current user has required role in current workspace
  def authorize_workspace_access!(required_role = :viewer)
    unless has_workspace_role?(required_role)
      raise NotAuthorizedError, "You don't have permission to perform this action"
    end
  end

  # Check if user has at least the specified role
  def has_workspace_role?(required_role)
    return false unless current_tenant && current_user

    membership = current_user.workspace_memberships
                             .find_by(workspace: current_tenant)

    return false unless membership

    # Role hierarchy: viewer < editor < admin < owner
    role_hierarchy = { viewer: 0, editor: 1, admin: 2, owner: 3 }
    user_level = role_hierarchy[membership.role.to_sym] || 0
    required_level = role_hierarchy[required_role.to_sym] || 0

    user_level >= required_level
  end

  # Convenience methods for role checking
  def workspace_owner?
    has_workspace_role?(:owner)
  end

  def workspace_admin?
    has_workspace_role?(:admin)
  end

  def workspace_editor?
    has_workspace_role?(:editor)
  end

  def workspace_viewer?
    has_workspace_role?(:viewer)
  end

  # Helper to get current tenant (workspace)
  def current_tenant
    ActsAsTenant.current_tenant
  end

  private

  def handle_not_authorized
    respond_to do |format|
      format.html { redirect_to root_path, alert: "You are not authorized to perform this action" }
      format.json { render json: { error: "Not authorized" }, status: :forbidden }
    end
  end
end
```

---

## Step 4: Update ApplicationController with acts_as_tenant

This is where the magic happens! We set the current tenant, and acts_as_tenant handles the rest.

### File: `app/controllers/application_controller.rb`

```ruby
class ApplicationController < ActionController::Base
  include Authentication
  include Authorization

  # Set current tenant before any action
  before_action :set_current_tenant

  # Make current_workspace available in views
  helper_method :current_workspace

  private

  def set_current_tenant
    return unless user_signed_in?

    workspace_slug = params[:workspace_slug]

    if workspace_slug
      # Find workspace and verify user has access
      workspace = current_user.workspaces.find_by!(slug: workspace_slug)

      # THIS IS THE KEY LINE - Set the current tenant for acts_as_tenant
      ActsAsTenant.current_tenant = workspace

      # Also store in session for non-scoped pages
      session[:current_workspace_id] = workspace.id

    elsif session[:current_workspace_id]
      # Restore from session if no slug in URL
      workspace = current_user.workspaces.find_by(id: session[:current_workspace_id])
      ActsAsTenant.current_tenant = workspace if workspace
    end

  rescue ActiveRecord::RecordNotFound
    handle_workspace_not_found
  end

  # Helper method to access current workspace
  def current_workspace
    ActsAsTenant.current_tenant
  end

  # Require workspace to be set
  def require_workspace
    unless current_workspace
      redirect_to workspaces_path, alert: "Please select a workspace"
    end
  end

  # Handle workspace not found or no access
  def handle_workspace_not_found
    ActsAsTenant.current_tenant = nil
    session.delete(:current_workspace_id)
    redirect_to workspaces_path, alert: "Workspace not found or you don't have access"
  end
end
```

### How This Works

1. **Extract workspace_slug** from URL params (e.g., `/acme-corp/brands`)
2. **Find workspace** and verify user has access via `current_user.workspaces`
3. **Set current tenant**: `ActsAsTenant.current_tenant = workspace`
4. **All subsequent queries** are automatically scoped to this workspace
5. **Store in session** so workspace persists across non-scoped pages

### Before/After Comparison

**Without acts_as_tenant:**
```ruby
# Every controller action needs manual scoping
def index
  @brands = @current_workspace.brands.all  # Must remember this!
end

def show
  @brand = @current_workspace.brands.find(params[:id])  # And this!
end

def create
  @brand = @current_workspace.brands.build(brand_params)  # And this!
end
```

**With acts_as_tenant:**
```ruby
# Just set the tenant once in ApplicationController
ActsAsTenant.current_tenant = workspace

# Then all queries are automatically scoped
def index
  @brands = Brand.all  # Automatically scoped to workspace!
end

def show
  @brand = Brand.find(params[:id])  # Automatically scoped!
end

def create
  @brand = Brand.create(brand_params)  # Automatically assigned to workspace!
end
```

---

## Step 5: Create WorkspacesController

Workspaces themselves are NOT tenant-scoped (they ARE the tenants), so we skip tenant setting for workspace management.

### File: `app/controllers/workspaces_controller.rb`

```ruby
class WorkspacesController < ApplicationController
  # Skip tenant setting for workspace management pages
  # (Workspaces are the tenants, so they're not scoped to themselves)
  skip_before_action :set_current_tenant, only: [:index, :new, :create]

  before_action :authenticate_user!
  before_action :set_workspace, only: [:show, :edit, :update, :destroy, :switch]
  before_action :authorize_workspace_access!, only: [:show, :edit, :update]
  before_action -> { authorize_workspace_access!(:owner) }, only: [:destroy]

  # GET /workspaces
  def index
    @workspaces = current_user.workspaces.order(created_at: :desc)
  end

  # GET /workspaces/new
  def new
    @workspace = Workspace.new
  end

  # POST /workspaces
  def create
    @workspace = Workspace.new(workspace_params)

    if @workspace.save
      # Creator becomes owner
      @workspace.workspace_memberships.create!(
        user: current_user,
        role: :owner
      )

      redirect_to workspace_path(@workspace.slug),
                  notice: "Workspace '#{@workspace.name}' created successfully"
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /:workspace_slug
  def show
    # Dashboard view for the workspace
    # acts_as_tenant is already set from set_workspace
  end

  # GET /:workspace_slug/edit
  def edit
  end

  # PATCH/PUT /:workspace_slug
  def update
    if @workspace.update(workspace_params)
      redirect_to workspace_path(@workspace.slug),
                  notice: "Workspace updated successfully"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /:workspace_slug
  def destroy
    workspace_name = @workspace.name
    @workspace.destroy

    # Clear tenant and session
    ActsAsTenant.current_tenant = nil
    session.delete(:current_workspace_id)

    redirect_to workspaces_path,
                notice: "Workspace '#{workspace_name}' deleted successfully"
  end

  # POST /:workspace_slug/switch
  def switch
    # Set as current tenant
    ActsAsTenant.current_tenant = @workspace
    session[:current_workspace_id] = @workspace.id

    redirect_to workspace_path(@workspace.slug),
                notice: "Switched to '#{@workspace.name}'"
  end

  private

  def set_workspace
    # Find workspace user has access to
    @workspace = current_user.workspaces.find_by!(slug: params[:workspace_slug] || params[:id])

    # Set as current tenant for this request
    ActsAsTenant.current_tenant = @workspace

  rescue ActiveRecord::RecordNotFound
    redirect_to workspaces_path, alert: "Workspace not found or you don't have access"
  end

  def workspace_params
    params.require(:workspace).permit(:name, :slug)
  end
end
```

---

## Step 6: Implement Workspace-Scoped Controllers with acts_as_tenant

With acts_as_tenant, controllers become much simpler - no need to manually scope every query!

### Example: BrandsController

### File: `app/controllers/brands_controller.rb`

```ruby
class BrandsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_workspace
  before_action :set_brand, only: [:show, :edit, :update, :destroy]

  # Authorization checks
  before_action :authorize_workspace_access!, only: [:index, :show]
  before_action -> { authorize_workspace_access!(:editor) }, only: [:new, :create, :edit, :update]
  before_action -> { authorize_workspace_access!(:admin) }, only: [:destroy]

  # GET /:workspace_slug/brands
  def index
    # acts_as_tenant automatically scopes this to current workspace!
    @brands = Brand.all.order(created_at: :desc)

    # This is equivalent to (but safer than):
    # @brands = current_workspace.brands.all
  end

  # GET /:workspace_slug/brands/:id
  def show
    # @brand already set by set_brand callback
  end

  # GET /:workspace_slug/brands/new
  def new
    # acts_as_tenant will automatically set workspace_id when saved
    @brand = Brand.new
  end

  # POST /:workspace_slug/brands
  def create
    # acts_as_tenant automatically assigns workspace_id!
    @brand = Brand.new(brand_params)

    if @brand.save
      redirect_to workspace_brand_path(current_workspace.slug, @brand),
                  notice: "Brand created successfully"
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /:workspace_slug/brands/:id/edit
  def edit
  end

  # PATCH/PUT /:workspace_slug/brands/:id
  def update
    if @brand.update(brand_params)
      redirect_to workspace_brand_path(current_workspace.slug, @brand),
                  notice: "Brand updated successfully"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /:workspace_slug/brands/:id
  def destroy
    @brand.destroy
    redirect_to workspace_brands_path(current_workspace.slug),
                notice: "Brand deleted successfully"
  end

  private

  def set_brand
    # acts_as_tenant automatically scopes this query!
    # Will only find brands in current workspace
    @brand = Brand.find(params[:id])

  rescue ActiveRecord::RecordNotFound
    redirect_to workspace_brands_path(current_workspace.slug),
                alert: "Brand not found"
  end

  def brand_params
    params.require(:brand).permit(:name, :slug, :description, :logo_url, :primary_color)
  end
end
```

### Example: ProjectsController

### File: `app/controllers/projects_controller.rb`

```ruby
class ProjectsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_workspace
  before_action :set_project, only: [:show, :edit, :update, :destroy]
  before_action :authorize_workspace_access!, only: [:index, :show]
  before_action -> { authorize_workspace_access!(:editor) }, only: [:new, :create, :edit, :update]
  before_action -> { authorize_workspace_access!(:admin) }, only: [:destroy]

  # GET /:workspace_slug/projects
  def index
    # Automatically scoped to current workspace
    @projects = Project.all.order(created_at: :desc)
  end

  # GET /:workspace_slug/projects/:id
  def show
  end

  # GET /:workspace_slug/projects/new
  def new
    @project = Project.new
  end

  # POST /:workspace_slug/projects
  def create
    @project = Project.new(project_params)
    @project.created_by = current_user

    if @project.save
      redirect_to workspace_project_path(current_workspace.slug, @project),
                  notice: "Project created successfully"
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /:workspace_slug/projects/:id/edit
  def edit
  end

  # PATCH/PUT /:workspace_slug/projects/:id
  def update
    if @project.update(project_params)
      redirect_to workspace_project_path(current_workspace.slug, @project),
                  notice: "Project updated successfully"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /:workspace_slug/projects/:id
  def destroy
    @project.destroy
    redirect_to workspace_projects_path(current_workspace.slug),
                notice: "Project deleted successfully"
  end

  private

  def set_project
    # Automatically scoped to current workspace
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to workspace_projects_path(current_workspace.slug),
                alert: "Project not found"
  end

  def project_params
    params.require(:project).permit(:name, :description, :status, :brand_id)
  end
end
```

### Key Differences with acts_as_tenant

**Manual Scoping (Before):**
```ruby
# ❌ Must remember to scope every query
def index
  @brands = @current_workspace.brands.all
end

def set_brand
  @brand = @current_workspace.brands.find(params[:id])
end

def create
  @brand = @current_workspace.brands.build(brand_params)
end
```

**Automatic Scoping (After):**
```ruby
# ✅ acts_as_tenant handles scoping automatically
def index
  @brands = Brand.all  # Automatically scoped!
end

def set_brand
  @brand = Brand.find(params[:id])  # Automatically scoped!
end

def create
  @brand = Brand.new(brand_params)  # workspace_id set automatically!
end
```

---

## Step 7: Configure Routes with Workspace Scoping

Routes remain the same - acts_as_tenant works with any routing structure.

### File: `config/routes.rb`

```ruby
Rails.application.routes.draw do
  # Authentication routes
  devise_for :users

  # Root path
  root "home#index"

  # Workspace management (outside workspace scope)
  resources :workspaces, only: [:index, :new, :create]

  # Workspace-scoped routes
  # Pattern: /:workspace_slug/resource
  scope "/:workspace_slug", as: :workspace do
    # Workspace settings
    resource :workspace, only: [:show, :edit, :update, :destroy], controller: :workspaces do
      post :switch, on: :member
    end

    # Workspace members
    resources :workspace_memberships, path: "members", as: :members do
      member do
        patch :update_role
      end
    end

    # All workspace resources (automatically scoped by acts_as_tenant)
    resources :brands do
      resources :brand_assets
    end

    resources :projects do
      resources :tasks
      resources :documents
    end

    resources :clients
    resources :invoices
    resources :time_entries
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
```

### Example URLs

With this routing structure:

```
# Workspace management
GET  /workspaces                    → WorkspacesController#index
GET  /workspaces/new                → WorkspacesController#new
POST /workspaces                    → WorkspacesController#create

# Workspace dashboard
GET  /acme-corp                     → WorkspacesController#show
GET  /acme-corp/edit                → WorkspacesController#edit
POST /acme-corp/switch              → WorkspacesController#switch

# Brands (automatically scoped to workspace)
GET  /acme-corp/brands              → BrandsController#index
GET  /acme-corp/brands/new          → BrandsController#new
POST /acme-corp/brands              → BrandsController#create
GET  /acme-corp/brands/123          → BrandsController#show

# Projects (automatically scoped to workspace)
GET  /acme-corp/projects            → ProjectsController#index
GET  /acme-corp/projects/456        → ProjectsController#show

# Workspace members
GET  /acme-corp/members             → WorkspaceMembershipsController#index
```

---

## Step 8: Create Workspace Switcher UI Component

The UI remains the same - acts_as_tenant is transparent to views.

### File: `app/views/shared/_workspace_switcher.html.erb`

```erb
<div class="workspace-switcher">
  <% if current_workspace %>
    <div class="dropdown">
      <button class="btn btn-outline dropdown-toggle" type="button" data-bs-toggle="dropdown">
        <i class="bi bi-building"></i>
        <%= current_workspace.name %>
      </button>
      <ul class="dropdown-menu">
        <li class="dropdown-header">Your Workspaces</li>
        <% current_user.workspaces.each do |workspace| %>
          <li>
            <%= link_to switch_workspace_path(workspace.slug),
                        method: :post,
                        class: "dropdown-item #{'active' if workspace == current_workspace}",
                        data: { turbo_method: :post } do %>
              <i class="bi bi-building"></i>
              <%= workspace.name %>
              <% if workspace == current_workspace %>
                <i class="bi bi-check-circle-fill text-success float-end"></i>
              <% end %>
            <% end %>
          </li>
        <% end %>
        <li><hr class="dropdown-divider"></li>
        <li>
          <%= link_to new_workspace_path, class: "dropdown-item" do %>
            <i class="bi bi-plus-circle"></i> Create New Workspace
          <% end %>
        </li>
        <li>
          <%= link_to workspaces_path, class: "dropdown-item" do %>
            <i class="bi bi-gear"></i> Manage Workspaces
          <% end %>
        </li>
      </ul>
    </div>
  <% else %>
    <%= link_to "Select Workspace", workspaces_path, class: "btn btn-primary" %>
  <% end %>
</div>
```

### File: `app/views/layouts/application.html.erb` (Navigation Update)

```erb
<!DOCTYPE html>
<html>
  <head>
    <title>AEO</title>
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body>
    <nav class="navbar navbar-expand-lg navbar-dark bg-dark">
      <div class="container-fluid">
        <%= link_to "AEO", root_path, class: "navbar-brand" %>

        <% if user_signed_in? %>
          <div class="d-flex align-items-center gap-3">
            <%= render "shared/workspace_switcher" %>

            <div class="dropdown">
              <button class="btn btn-outline-light dropdown-toggle" type="button" data-bs-toggle="dropdown">
                <%= current_user.email %>
              </button>
              <ul class="dropdown-menu dropdown-menu-end">
                <li><%= link_to "Profile", edit_user_registration_path, class: "dropdown-item" %></li>
                <li><hr class="dropdown-divider"></li>
                <li>
                  <%= button_to "Sign Out", destroy_user_session_path,
                                method: :delete, class: "dropdown-item" %>
                </li>
              </ul>
            </div>
          </div>
        <% end %>
      </div>
    </nav>

    <main class="container mt-4">
      <% if notice %>
        <div class="alert alert-success alert-dismissible fade show" role="alert">
          <%= notice %>
          <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
      <% end %>

      <% if alert %>
        <div class="alert alert-danger alert-dismissible fade show" role="alert">
          <%= alert %>
          <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
      <% end %>

      <%= yield %>
    </main>
  </body>
</html>
```

---

## Step 9: Testing Multi-Tenancy with acts_as_tenant

Testing with acts_as_tenant requires setting the current tenant in tests.

### File: `test/test_helper.rb`

First, add a helper to set the current tenant in tests:

```ruby
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Helper to set current tenant for acts_as_tenant
  def set_current_tenant(workspace)
    ActsAsTenant.current_tenant = workspace
  end

  # Helper to clear current tenant
  def clear_current_tenant
    ActsAsTenant.current_tenant = nil
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # Automatically clear tenant between tests
  teardown do
    ActsAsTenant.current_tenant = nil
  end
end
```

### File: `test/controllers/brands_controller_test.rb`

```ruby
require "test_helper"

class BrandsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    @workspace = workspaces(:acme)
    @other_workspace = workspaces(:techcorp)
    @brand = brands(:acme_brand)

    sign_in @user
  end

  test "should get index scoped to workspace" do
    get workspace_brands_url(@workspace.slug)
    assert_response :success
  end

  test "should not access brands from other workspace" do
    # Create brand in other workspace
    ActsAsTenant.with_tenant(@other_workspace) do
      other_brand = Brand.create!(
        name: "Secret Brand",
        slug: "secret-brand"
      )

      # Try to access it from @workspace context
      # acts_as_tenant will prevent finding it
      get workspace_brand_url(@workspace.slug, other_brand.id)
      assert_redirected_to workspace_brands_path(@workspace.slug)
      assert_equal "Brand not found", flash[:alert]
    end
  end

  test "should create brand in current workspace" do
    assert_difference("Brand.count") do
      post workspace_brands_url(@workspace.slug), params: {
        brand: { name: "New Brand", slug: "new-brand" }
      }
    end

    # Verify brand was created in correct workspace
    brand = Brand.last
    assert_equal @workspace.id, brand.workspace_id
    assert_redirected_to workspace_brand_url(@workspace.slug, brand)
  end

  test "viewer cannot create brands" do
    membership = @user.workspace_memberships.find_by(workspace: @workspace)
    membership.update!(role: :viewer)

    post workspace_brands_url(@workspace.slug), params: {
      brand: { name: "New Brand", slug: "new-brand" }
    }

    assert_response :forbidden
  end

  test "editor can create and update brands" do
    membership = @user.workspace_memberships.find_by(workspace: @workspace)
    membership.update!(role: :editor)

    # Create
    post workspace_brands_url(@workspace.slug), params: {
      brand: { name: "Editor Brand", slug: "editor-brand" }
    }
    assert_response :redirect

    # Update
    patch workspace_brand_url(@workspace.slug, @brand), params: {
      brand: { name: "Updated Name" }
    }
    assert_response :redirect
  end

  test "only admin can destroy brands" do
    membership = @user.workspace_memberships.find_by(workspace: @workspace)
    membership.update!(role: :editor)

    delete workspace_brand_url(@workspace.slug, @brand)
    assert_response :forbidden

    membership.update!(role: :admin)
    delete workspace_brand_url(@workspace.slug, @brand)
    assert_response :redirect
  end
end
```

### File: `test/controllers/workspaces_controller_test.rb`

```ruby
require "test_helper"

class WorkspacesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    @workspace = workspaces(:acme)
    sign_in @user
  end

  test "should get index" do
    get workspaces_url
    assert_response :success
  end

  test "should create workspace and make user owner" do
    assert_difference("Workspace.count") do
      post workspaces_url, params: {
        workspace: { name: "New Workspace", slug: "new-workspace" }
      }
    end

    workspace = Workspace.last
    membership = workspace.workspace_memberships.find_by(user: @user)

    assert_equal "owner", membership.role
    assert_redirected_to workspace_url(workspace.slug)
  end

  test "should switch workspace and set current tenant" do
    post switch_workspace_path(@workspace.slug)

    assert_equal @workspace.id, session[:current_workspace_id]
    assert_redirected_to workspace_url(@workspace.slug)
  end

  test "should not access workspace without membership" do
    other_workspace = Workspace.create!(name: "Private", slug: "private")

    assert_raises(ActiveRecord::RecordNotFound) do
      get workspace_url(other_workspace.slug)
    end
  end
end
```

### File: `test/models/brand_test.rb`

Test model-level tenant scoping:

```ruby
require "test_helper"

class BrandTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:acme)
    @other_workspace = workspaces(:techcorp)
  end

  test "should require workspace" do
    brand = Brand.new(name: "Test", slug: "test")
    assert_not brand.valid?
    assert_includes brand.errors[:workspace], "must exist"
  end

  test "should automatically scope queries to current tenant" do
    # Create brands in different workspaces
    acme_brand = ActsAsTenant.with_tenant(@workspace) do
      Brand.create!(name: "Acme Brand", slug: "acme-brand")
    end

    techcorp_brand = ActsAsTenant.with_tenant(@other_workspace) do
      Brand.create!(name: "TechCorp Brand", slug: "techcorp-brand")
    end

    # Query with tenant set
    ActsAsTenant.with_tenant(@workspace) do
      brands = Brand.all
      assert_includes brands, acme_brand
      assert_not_includes brands, techcorp_brand
    end

    # Query with different tenant
    ActsAsTenant.with_tenant(@other_workspace) do
      brands = Brand.all
      assert_includes brands, techcorp_brand
      assert_not_includes brands, acme_brand
    end
  end

  test "should automatically assign workspace on create" do
    ActsAsTenant.with_tenant(@workspace) do
      brand = Brand.create!(name: "Auto Brand", slug: "auto-brand")
      assert_equal @workspace.id, brand.workspace_id
    end
  end

  test "should enforce unique slug within workspace" do
    ActsAsTenant.with_tenant(@workspace) do
      Brand.create!(name: "Brand 1", slug: "same-slug")
      duplicate = Brand.new(name: "Brand 2", slug: "same-slug")

      assert_not duplicate.valid?
      assert_includes duplicate.errors[:slug], "has already been taken"
    end
  end

  test "should allow same slug in different workspaces" do
    acme_brand = ActsAsTenant.with_tenant(@workspace) do
      Brand.create!(name: "Brand", slug: "same-slug")
    end

    techcorp_brand = ActsAsTenant.with_tenant(@other_workspace) do
      Brand.create!(name: "Brand", slug: "same-slug")
    end

    assert acme_brand.persisted?
    assert techcorp_brand.persisted?
    assert_equal "same-slug", acme_brand.slug
    assert_equal "same-slug", techcorp_brand.slug
  end
end
```

---

## Step 10: Advanced acts_as_tenant Usage

### Using ActsAsTenant.with_tenant for Temporary Context

Sometimes you need to temporarily switch tenant context:

```ruby
# In a background job or rake task
class BrandExportJob < ApplicationJob
  def perform(workspace_id, brand_id)
    workspace = Workspace.find(workspace_id)

    # Set tenant context for this job
    ActsAsTenant.with_tenant(workspace) do
      brand = Brand.find(brand_id)  # Automatically scoped
      # ... export logic
    end
  end
end

# In a rake task
namespace :brands do
  desc "Generate reports for all workspaces"
  task generate_reports: :environment do
    Workspace.find_each do |workspace|
      ActsAsTenant.with_tenant(workspace) do
        brands = Brand.all  # Scoped to current workspace
        puts "Workspace: #{workspace.name} - Brands: #{brands.count}"
      end
    end
  end
end
```

### Bypassing Tenant Scoping (Use with Caution!)

In rare cases, you may need to query across all tenants:

```ruby
# ⚠️ DANGEROUS - Bypasses tenant scoping
ActsAsTenant.without_tenant do
  all_brands = Brand.all  # Returns brands from ALL workspaces
  total_count = Brand.count  # Count across all workspaces
end

# Use case: Admin dashboard showing global statistics
class AdminDashboardController < ApplicationController
  before_action :require_super_admin

  def index
    @stats = ActsAsTenant.without_tenant do
      {
        total_workspaces: Workspace.count,
        total_brands: Brand.count,
        total_projects: Project.count
      }
    end
  end
end
```

### Handling Associations Across Tenants

Some associations may span tenants (like User):

```ruby
class Project < ApplicationRecord
  acts_as_tenant :workspace

  # This association is scoped to workspace
  belongs_to :brand

  # This association is NOT scoped (users are global)
  belongs_to :created_by, class_name: "User"

  # acts_as_tenant will NOT scope the created_by association
  # because User doesn't have acts_as_tenant
end

# Querying
project = Project.find(1)  # Scoped to current workspace
project.brand              # Also scoped to current workspace
project.created_by         # NOT scoped - can be from any workspace
```

---

## Success Criteria Checklist

- [ ] acts_as_tenant gem installed and configured
- [ ] Initializer created with require_tenant = true
- [ ] Brand model uses acts_as_tenant :workspace
- [ ] Project model uses acts_as_tenant :workspace
- [ ] Task model uses acts_as_tenant :workspace
- [ ] Authorization concern created with role hierarchy (viewer < editor < admin < owner)
- [ ] ApplicationController sets ActsAsTenant.current_tenant from URL
- [ ] WorkspacesController handles CRUD and switching
- [ ] BrandsController uses automatic scoping (Brand.all, Brand.find, etc.)
- [ ] Routes configured with /:workspace_slug prefix
- [ ] Workspace switcher UI component created
- [ ] Session tracks current workspace
- [ ] Authorization checks enforce role-based permissions
- [ ] Workspace not found scenarios handled gracefully
- [ ] Controller tests verify workspace isolation with acts_as_tenant
- [ ] Controller tests verify role-based authorization
- [ ] Model tests verify automatic tenant scoping
- [ ] Model tests verify automatic workspace_id assignment
- [ ] Users cannot access resources from other workspaces
- [ ] Workspace switching updates session and ActsAsTenant.current_tenant

---

## Testing Checklist

### Manual Testing

1. **Workspace Creation**
   ```bash
   # Sign in as user
   # Navigate to /workspaces/new
   # Create workspace "Test Workspace"
   # Verify you're redirected to workspace dashboard
   # Verify you're set as owner
   # Verify ActsAsTenant.current_tenant is set
   ```

2. **Workspace Switching**
   ```bash
   # Create second workspace
   # Use workspace switcher dropdown
   # Switch between workspaces
   # Verify URL changes to /:workspace_slug
   # Verify session persists workspace
   # Verify ActsAsTenant.current_tenant changes
   ```

3. **Resource Isolation with acts_as_tenant**
   ```bash
   # Create brand in Workspace A
   # Note the brand ID
   # Switch to Workspace B
   # Try to access Workspace A brand URL with same ID
   # Verify 404 or redirect (acts_as_tenant prevents access)
   # Try Brand.find(id) in console - should raise RecordNotFound
   ```

4. **Automatic Scoping**
   ```bash
   # In Rails console:
   workspace = Workspace.first
   ActsAsTenant.current_tenant = workspace

   # All queries are now scoped
   Brand.all  # Only brands in workspace
   Brand.create(name: "Test")  # Automatically assigned to workspace

   # Switch tenant
   ActsAsTenant.current_tenant = Workspace.last
   Brand.all  # Different brands!
   ```

5. **Role-Based Access**
   ```bash
   # As owner: create, edit, delete brands ✓
   # Change role to admin: create, edit, delete brands ✓
   # Change role to editor: create, edit brands ✓ (delete fails)
   # Change role to viewer: view only (create/edit/delete fail)
   ```

### Automated Testing

```bash
# Run all tests
rails test

# Run controller tests
rails test:controllers

# Run specific tests
rails test test/controllers/workspaces_controller_test.rb
rails test test/controllers/brands_controller_test.rb

# Run model tests (important for acts_as_tenant!)
rails test test/models/brand_test.rb

# Run with coverage
COVERAGE=true rails test
```

---

## Troubleshooting

### Issue: "ActsAsTenant::Errors::NoTenantSet" error

**Cause:** Trying to query a tenant-scoped model without setting current tenant

**Solution:**
```ruby
# ❌ Wrong - No tenant set
Brand.all  # Raises NoTenantSet error

# ✅ Correct - Set tenant first
ActsAsTenant.current_tenant = workspace
Brand.all  # Works!

# Or use with_tenant block
ActsAsTenant.with_tenant(workspace) do
  Brand.all  # Works!
end

# In controllers, ensure set_current_tenant runs
before_action :set_current_tenant
before_action :require_workspace
```

### Issue: Can access other workspace's resources

**Cause:** Not using acts_as_tenant on model, or bypassing it

**Solution:**
```ruby
# ✅ Ensure model has acts_as_tenant
class Brand < ApplicationRecord
  acts_as_tenant :workspace  # This is required!
end

# ❌ Don't bypass tenant scoping
Brand.unscoped.all  # Bypasses acts_as_tenant!

# ✅ Use normal queries
Brand.all  # Automatically scoped
```

### Issue: "Validation failed: Workspace must exist"

**Cause:** Creating record without tenant set

**Solution:**
```ruby
# ❌ Wrong - No tenant set
brand = Brand.create(name: "Test")  # Fails validation

# ✅ Correct - Set tenant first
ActsAsTenant.current_tenant = workspace
brand = Brand.create(name: "Test")  # workspace_id set automatically

# Or in tests
ActsAsTenant.with_tenant(workspace) do
  brand = Brand.create(name: "Test")
end
```

### Issue: Tests failing with "NoTenantSet"

**Cause:** Not setting tenant in test setup

**Solution:**
```ruby
# In test_helper.rb
class ActiveSupport::TestCase
  teardown do
    ActsAsTenant.current_tenant = nil
  end
end

# In individual tests
test "should create brand" do
  ActsAsTenant.with_tenant(@workspace) do
    brand = Brand.create!(name: "Test")
    assert brand.persisted?
  end
end

# Or in controller tests (tenant set automatically from URL)
test "should get index" do
  get workspace_brands_url(@workspace.slug)
  assert_response :success
end
```

### Issue: Background jobs failing with tenant errors

**Cause:** No tenant context in background jobs

**Solution:**
```ruby
# ❌ Wrong - No tenant context
class BrandJob < ApplicationJob
  def perform(brand_id)
    brand = Brand.find(brand_id)  # NoTenantSet error!
  end
end

# ✅ Correct - Pass workspace_id and set tenant
class BrandJob < ApplicationJob
  def perform(workspace_id, brand_id)
    workspace = Workspace.find(workspace_id)
    ActsAsTenant.with_tenant(workspace) do
      brand = Brand.find(brand_id)  # Works!
    end
  end
end

# When enqueuing
BrandJob.perform_later(current_workspace.id, @brand.id)
```

### Issue: Workspace switcher not showing

**Cause:** Missing current_workspace helper or partial

**Solution:**
```ruby
# In ApplicationController
helper_method :current_workspace

def current_workspace
  ActsAsTenant.current_tenant  # Return current tenant
end

# Verify partial exists
# app/views/shared/_workspace_switcher.html.erb

# Check it's rendered in layout
<%= render "shared/workspace_switcher" if user_signed_in? %>
```

---

## Query Performance and Database Indexes

### Important: Add Database Indexes

acts_as_tenant adds `WHERE workspace_id = ?` to every query. Make sure you have proper indexes!

```ruby
# In migration files
class AddIndexesToBrands < ActiveRecord::Migration[7.1]
  def change
    # Composite index for tenant scoping
    add_index :brands, [:workspace_id, :id]

    # Unique constraint scoped to workspace
    add_index :brands, [:workspace_id, :slug], unique: true

    # For queries that filter by other columns
    add_index :brands, [:workspace_id, :created_at]
  end
end

class AddIndexesToProjects < ActiveRecord::Migration[7.1]
  def change
    add_index :projects, [:workspace_id, :id]
    add_index :projects, [:workspace_id, :brand_id]
    add_index :projects, [:workspace_id, :status]
    add_index :projects, [:workspace_id, :created_at]
  end
end
```

### Query Analysis

Check that queries are using indexes:

```ruby
# In Rails console
ActsAsTenant.current_tenant = Workspace.first

# Check query plan
Brand.all.explain
# Should show: Index Scan using index_brands_on_workspace_id_and_id

# Check slow queries
Brand.where(status: 'active').explain
# Should use: Index Scan using index_brands_on_workspace_id_and_status
```

---

## Additional Enhancements

### 1. Workspace Invitation System

```ruby
# app/models/workspace_invitation.rb
class WorkspaceInvitation < ApplicationRecord
  belongs_to :workspace
  belongs_to :invited_by, class_name: "User"

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: %w[owner admin editor viewer] }

  before_create :generate_token

  def accept!(user)
    workspace.workspace_memberships.create!(user: user, role: role)
    destroy
  end

  private

  def generate_token
    self.token = SecureRandom.urlsafe_base64(32)
  end
end
```

### 2. Workspace Activity Log (with acts_as_tenant)

```ruby
# app/models/workspace_activity.rb
class WorkspaceActivity < ApplicationRecord
  acts_as_tenant :workspace  # Activities are also tenant-scoped!

  belongs_to :user
  belongs_to :trackable, polymorphic: true, optional: true

  scope :recent, -> { order(created_at: :desc).limit(50) }
end

# In controllers
after_action :log_activity, only: [:create, :update, :destroy]

def log_activity
  # No need to specify workspace - acts_as_tenant handles it!
  WorkspaceActivity.create!(
    user: current_user,
    action: action_name,
    trackable: @brand,
    metadata: { controller: controller_name }
  )
end
```

### 3. Workspace Settings

```ruby
# app/models/workspace_setting.rb
class WorkspaceSetting < ApplicationRecord
  belongs_to :workspace

  store :preferences, accessors: [
    :default_brand_color,
    :default_project_status,
    :time_tracking_enabled,
    :invoice_prefix,
    :currency
  ], coder: JSON
end
```

---

## acts_as_tenant vs. Manual Scoping: Summary

### Benefits of acts_as_tenant

✅ **Safety**: Impossible to forget scoping - automatic on all queries
✅ **Simplicity**: One line per model (`acts_as_tenant :workspace`)
✅ **Consistency**: Same scoping behavior everywhere
✅ **Less Code**: No need to manually scope every query
✅ **Automatic Assignment**: `workspace_id` set automatically on create
✅ **Validation**: Ensures `workspace_id` is always present
✅ **Testing**: Clear tenant context in tests

### When NOT to Use acts_as_tenant

❌ **Global Models**: User, Workspace, etc.
❌ **Cross-Tenant Associations**: WorkspaceMembership
❌ **Admin/Reporting**: Use `ActsAsTenant.without_tenant` carefully

### Migration Path

If you have existing manual scoping:

```ruby
# Before (manual scoping)
class BrandsController < ApplicationController
  def index
    @brands = @current_workspace.brands.all
  end

  def create
    @brand = @current_workspace.brands.build(brand_params)
  end
end

# After (acts_as_tenant)
class BrandsController < ApplicationController
  def index
    @brands = Brand.all  # Automatically scoped!
  end

  def create
    @brand = Brand.new(brand_params)  # workspace_id set automatically!
  end
end
```

---

## Next Steps

After completing multi-tenancy implementation with acts_as_tenant:

1. **Test thoroughly** - Verify workspace isolation and authorization
2. **Add database indexes** - Optimize tenant-scoped queries
3. **Add workspace invitations** - Allow owners/admins to invite team members
4. **Implement activity logging** - Track all workspace actions (also tenant-scoped!)
5. **Create workspace settings** - Allow customization per workspace
6. **Add workspace analytics** - Dashboard with metrics
7. **Implement workspace export** - Allow data export for compliance
8. **Background jobs** - Ensure tenant context in jobs

---

## Resources

### acts_as_tenant Documentation
- [ActsAsTenant GitHub](https://github.com/ErwinM/acts_as_tenant) - Official documentation
- [ActsAsTenant Wiki](https://github.com/ErwinM/acts_as_tenant/wiki) - Advanced usage

### Alternative Approaches
- [Apartment Gem](https://github.com/influitive/apartment) - Schema-based multi-tenancy (separate DB schema per tenant)
- [Row-Level Security](https://www.postgresql.org/docs/current/ddl-rowsecurity.html) - PostgreSQL native approach

### Related Topics
- [Pundit Authorization](https://github.com/varvet/pundit) - Alternative to custom authorization
- [Rails Multi-Tenancy Guide](https://guides.rubyonrails.org/active_record_querying.html#scopes)
- [Multi-Tenancy Best Practices](https://www.citusdata.com/blog/2016/10/03/designing-your-saas-database-for-high-scalability/)

---

## Key Takeaways

1. **acts_as_tenant handles SCOPING** (which workspace), not AUTHORIZATION (what users can do)
2. **Set tenant once** in ApplicationController, all queries are automatically scoped
3. **Models need** `acts_as_tenant :workspace` to be scoped
4. **Tests need** `ActsAsTenant.with_tenant(workspace)` or set via controller
5. **Background jobs** must set tenant context manually
6. **Database indexes** are critical for performance with tenant scoping
7. **Use `without_tenant`** sparingly and only when necessary

---

**Completion Time:** ~6 hours
**Difficulty:** Medium
**Impact:** Critical - Foundation for all workspace features
**Key Technology:** acts_as_tenant gem for automatic tenant scoping

