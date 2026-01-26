# Task 08: Brands Management UI

## Overview
Build a complete CRUD interface for managing brands within workspaces, featuring beautiful Tailwind-styled forms, client-side validation with Stimulus, and comprehensive testing.

**Estimated Time:** 6 hours

## Prerequisites
- Task 01: Database Schema (Brand model exists)
- Task 02: Authentication System
- Task 03: Workspace Management
- Task 07: Navigation & Layout

## Success Criteria
- [ ] BrandsController with all CRUD actions implemented
- [ ] Brand index page with list and search
- [ ] Brand creation form with validation
- [ ] Brand edit form with pre-filled data
- [ ] Brand show page with details
- [ ] Delete confirmation with modal
- [ ] Client-side validation with Stimulus
- [ ] Server-side validation error display
- [ ] Workspace scoping enforced
- [ ] Authorization checks in place
- [ ] Responsive design on all pages
- [ ] Controller tests passing (100% coverage)
- [ ] System tests passing for CRUD flow
- [ ] Flash messages for all actions

## Architecture Overview

### CRUD Flow Diagram
```
┌─────────────────────────────────────────────────────────────┐
│                     Brands Management Flow                   │
└─────────────────────────────────────────────────────────────┘

INDEX (/brands)
    │
    ├──> NEW (/brands/new)
    │       │
    │       └──> CREATE (POST /brands)
    │               ├──> Success: Redirect to SHOW
    │               └──> Failure: Re-render NEW with errors
    │
    ├──> SHOW (/brands/:id)
    │       │
    │       ├──> EDIT (/brands/:id/edit)
    │       │       │
    │       │       └──> UPDATE (PATCH /brands/:id)
    │       │               ├──> Success: Redirect to SHOW
    │       │               └──> Failure: Re-render EDIT with errors
    │       │
    │       └──> DELETE (DELETE /brands/:id)
    │               └──> Success: Redirect to INDEX
    │
    └──> All actions scoped to current_workspace
```

## Step-by-Step Implementation

### Step 1: Create BrandsController (30 minutes)

Create the controller with full CRUD actions and workspace scoping.

**File:** `app/controllers/brands_controller.rb`

```ruby
class BrandsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_workspace
  before_action :set_brand, only: [:show, :edit, :update, :destroy]

  # GET /brands
  def index
    @brands = @workspace.brands.order(name: :asc)
    
    # Optional: Add search functionality
    if params[:search].present?
      @brands = @brands.where("name ILIKE ?", "%#{params[:search]}%")
    end
    
    @brands = @brands.page(params[:page]).per(20)
  end

  # GET /brands/:id
  def show
    # @brand set by before_action
  end

  # GET /brands/new
  def new
    @brand = @workspace.brands.build
  end

  # POST /brands
  def create
    @brand = @workspace.brands.build(brand_params)
    
    if @brand.save
      redirect_to workspace_brand_path(@workspace, @brand),
                  notice: "Brand was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /brands/:id/edit
  def edit
    # @brand set by before_action
  end

  # PATCH/PUT /brands/:id
  def update
    if @brand.update(brand_params)
      redirect_to workspace_brand_path(@workspace, @brand),
                  notice: "Brand was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /brands/:id
  def destroy
    @brand.destroy
    redirect_to workspace_brands_path(@workspace),
                notice: "Brand was successfully deleted."
  end

  private

  def set_workspace
    @workspace = current_user.workspaces.find(params[:workspace_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to workspaces_path, alert: "Workspace not found."
  end

  def set_brand
    @brand = @workspace.brands.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to workspace_brands_path(@workspace), alert: "Brand not found."
  end

  def brand_params
    params.require(:brand).permit(:name, :description, :logo_url, :website_url)
  end
end
```

**Update routes** in `config/routes.rb`:

```ruby
resources :workspaces do
  resources :brands
end
```

### Step 2: Create Brand Index Page (45 minutes)

Build a beautiful index page with search and action buttons.

**File:** `app/views/brands/index.html.erb`

```erb
<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
  <!-- Header -->
  <div class="md:flex md:items-center md:justify-between mb-8">
    <div class="flex-1 min-w-0">
      <h1 class="text-3xl font-bold text-gray-900">Brands</h1>
      <p class="mt-2 text-sm text-gray-600">
        Manage your brand portfolio for <%= @workspace.name %>
      </p>
    </div>
    <div class="mt-4 flex md:mt-0 md:ml-4">
      <%= link_to new_workspace_brand_path(@workspace),
          class: "inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500" do %>
        <svg class="-ml-1 mr-2 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
        </svg>
        New Brand
      <% end %>
    </div>
  </div>

  <!-- Search Bar -->
  <div class="mb-6">
    <%= form_with url: workspace_brands_path(@workspace), method: :get, class: "flex gap-2" do |f| %>
      <div class="flex-1">
        <%= f.text_field :search,
            value: params[:search],
            placeholder: "Search brands...",
            class: "block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" %>
      </div>
      <%= f.submit "Search", class: "px-4 py-2 bg-gray-100 text-gray-700 rounded-md hover:bg-gray-200 font-medium" %>
      <% if params[:search].present? %>
        <%= link_to "Clear", workspace_brands_path(@workspace),
            class: "px-4 py-2 bg-gray-100 text-gray-700 rounded-md hover:bg-gray-200 font-medium" %>
      <% end %>
    <% end %>
  </div>

  <!-- Brands Grid -->
  <% if @brands.any? %>
    <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
      <% @brands.each do |brand| %>
        <div class="bg-white overflow-hidden shadow rounded-lg hover:shadow-lg transition-shadow duration-200">
          <div class="p-6">
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-semibold text-gray-900 truncate">
                <%= brand.name %>
              </h3>
              <% if brand.logo_url.present? %>
                <%= image_tag brand.logo_url, class: "h-10 w-10 rounded", alt: brand.name %>
              <% end %>
            </div>

            <% if brand.description.present? %>
              <p class="text-sm text-gray-600 mb-4 line-clamp-2">
                <%= brand.description %>
              </p>
            <% end %>

            <div class="flex items-center justify-between pt-4 border-t border-gray-200">
              <%= link_to "View", workspace_brand_path(@workspace, brand),
                  class: "text-indigo-600 hover:text-indigo-900 text-sm font-medium" %>
              <div class="flex gap-2">
                <%= link_to workspace_brand_path(@workspace, brand), class: "text-gray-400 hover:text-gray-600" do %>
                  <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                  </svg>
                <% end %>
                <%= link_to edit_workspace_brand_path(@workspace, brand), class: "text-gray-400 hover:text-gray-600" do %>
                  <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                  </svg>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>

    <!-- Pagination -->
    <div class="mt-8">
      <%= paginate @brands %>
    </div>
  <% else %>
    <!-- Empty State -->
    <div class="text-center py-12">
      <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>
      </svg>
      <h3 class="mt-2 text-sm font-medium text-gray-900">No brands</h3>
      <p class="mt-1 text-sm text-gray-500">Get started by creating a new brand.</p>
      <div class="mt-6">
        <%= link_to new_workspace_brand_path(@workspace),
            class: "inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500" do %>
          <svg class="-ml-1 mr-2 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
          </svg>
          New Brand
        <% end %>
      </div>
    </div>
  <% end %>
</div>
```

### Step 3: Create Brand Form Partial (60 minutes)

Build a reusable form partial with validation and Stimulus integration.

**File:** `app/views/brands/_form.html.erb`

```erb
<%= form_with(model: [@workspace, brand],
              data: { controller: "form-validation", action: "submit->form-validation#validate" },
              class: "space-y-6") do |f| %>

  <!-- Error Messages -->
  <% if brand.errors.any? %>
    <div class="rounded-md bg-red-50 p-4">
      <div class="flex">
        <div class="flex-shrink-0">
          <svg class="h-5 w-5 text-red-400" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
          </svg>
        </div>
        <div class="ml-3">
          <h3 class="text-sm font-medium text-red-800">
            <%= pluralize(brand.errors.count, "error") %> prohibited this brand from being saved:
          </h3>
          <div class="mt-2 text-sm text-red-700">
            <ul class="list-disc list-inside space-y-1">
              <% brand.errors.full_messages.each do |message| %>
                <li><%= message %></li>
              <% end %>
            </ul>
          </div>
        </div>
      </div>
    </div>
  <% end %>

  <!-- Brand Name -->
  <div>
    <%= f.label :name, class: "block text-sm font-medium text-gray-700" %>
    <%= f.text_field :name,
        required: true,
        data: {
          form_validation_target: "field",
          validation_rules: "required|min:2|max:100"
        },
        class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm #{'border-red-300' if brand.errors[:name].any?}",
        placeholder: "e.g., Nike, Apple, Tesla" %>
    <% if brand.errors[:name].any? %>
      <p class="mt-2 text-sm text-red-600"><%= brand.errors[:name].first %></p>
    <% end %>
    <p class="mt-1 text-sm text-gray-500">The official name of the brand</p>
  </div>

  <!-- Description -->
  <div>
    <%= f.label :description, class: "block text-sm font-medium text-gray-700" %>
    <%= f.text_area :description,
        rows: 4,
        data: {
          form_validation_target: "field",
          validation_rules: "max:500"
        },
        class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm #{'border-red-300' if brand.errors[:description].any?}",
        placeholder: "Brief description of the brand..." %>
    <% if brand.errors[:description].any? %>
      <p class="mt-2 text-sm text-red-600"><%= brand.errors[:description].first %></p>
    <% end %>
    <p class="mt-1 text-sm text-gray-500">Optional: A brief description (max 500 characters)</p>
  </div>

  <!-- Logo URL -->
  <div>
    <%= f.label :logo_url, "Logo URL", class: "block text-sm font-medium text-gray-700" %>
    <%= f.url_field :logo_url,
        data: {
          form_validation_target: "field",
          validation_rules: "url",
          action: "change->form-validation#previewImage"
        },
        class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm #{'border-red-300' if brand.errors[:logo_url].any?}",
        placeholder: "https://example.com/logo.png" %>
    <% if brand.errors[:logo_url].any? %>
      <p class="mt-2 text-sm text-red-600"><%= brand.errors[:logo_url].first %></p>
    <% end %>
    <p class="mt-1 text-sm text-gray-500">Optional: URL to the brand's logo image</p>

    <!-- Logo Preview -->
    <div data-form-validation-target="imagePreview" class="mt-3 hidden">
      <img src="" alt="Logo preview" class="h-20 w-20 object-contain rounded border border-gray-300">
    </div>
  </div>

  <!-- Website URL -->
  <div>
    <%= f.label :website_url, "Website URL", class: "block text-sm font-medium text-gray-700" %>
    <%= f.url_field :website_url,
        data: {
          form_validation_target: "field",
          validation_rules: "url"
        },
        class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm #{'border-red-300' if brand.errors[:website_url].any?}",
        placeholder: "https://www.example.com" %>
    <% if brand.errors[:website_url].any? %>
      <p class="mt-2 text-sm text-red-600"><%= brand.errors[:website_url].first %></p>
    <% end %>
    <p class="mt-1 text-sm text-gray-500">Optional: The brand's official website</p>
  </div>

  <!-- Form Actions -->
  <div class="flex items-center justify-end gap-3 pt-6 border-t border-gray-200">
    <%= link_to "Cancel",
        brand.persisted? ? workspace_brand_path(@workspace, brand) : workspace_brands_path(@workspace),
        class: "px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500" %>
    <%= f.submit brand.persisted? ? "Update Brand" : "Create Brand",
        data: { form_validation_target: "submit" },
        class: "px-4 py-2 text-sm font-medium text-white bg-indigo-600 border border-transparent rounded-md shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500" %>
  </div>
<% end %>
```

### Step 4: Create New Brand Page (15 minutes)

**File:** `app/views/brands/new.html.erb`

```erb
<div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
  <!-- Breadcrumb -->
  <nav class="flex mb-8" aria-label="Breadcrumb">
    <ol class="flex items-center space-x-4">
      <li>
        <%= link_to workspace_brands_path(@workspace), class: "text-gray-400 hover:text-gray-500" do %>
          <span>Brands</span>
        <% end %>
      </li>
      <li>
        <div class="flex items-center">
          <svg class="flex-shrink-0 h-5 w-5 text-gray-300" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd"/>
          </svg>
          <span class="ml-4 text-sm font-medium text-gray-500">New Brand</span>
        </div>
      </li>
    </ol>
  </nav>

  <!-- Header -->
  <div class="mb-8">
    <h1 class="text-3xl font-bold text-gray-900">Create New Brand</h1>
    <p class="mt-2 text-sm text-gray-600">
      Add a new brand to your <%= @workspace.name %> workspace
    </p>
  </div>

  <!-- Form Card -->
  <div class="bg-white shadow rounded-lg p-6">
    <%= render "form", brand: @brand %>
  </div>
</div>
```

### Step 5: Create Edit Brand Page (15 minutes)

**File:** `app/views/brands/edit.html.erb`

```erb
<div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
  <!-- Breadcrumb -->
  <nav class="flex mb-8" aria-label="Breadcrumb">
    <ol class="flex items-center space-x-4">
      <li>
        <%= link_to workspace_brands_path(@workspace), class: "text-gray-400 hover:text-gray-500" do %>
          <span>Brands</span>
        <% end %>
      </li>
      <li>
        <div class="flex items-center">
          <svg class="flex-shrink-0 h-5 w-5 text-gray-300" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd"/>
          </svg>
          <%= link_to @brand.name, workspace_brand_path(@workspace, @brand), class: "ml-4 text-gray-400 hover:text-gray-500" %>
        </div>
      </li>
      <li>
        <div class="flex items-center">
          <svg class="flex-shrink-0 h-5 w-5 text-gray-300" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd"/>
          </svg>
          <span class="ml-4 text-sm font-medium text-gray-500">Edit</span>
        </div>
      </li>
    </ol>
  </nav>

  <!-- Header -->
  <div class="mb-8">
    <h1 class="text-3xl font-bold text-gray-900">Edit Brand</h1>
    <p class="mt-2 text-sm text-gray-600">
      Update information for <%= @brand.name %>
    </p>
  </div>

  <!-- Form Card -->
  <div class="bg-white shadow rounded-lg p-6">
    <%= render "form", brand: @brand %>
  </div>
</div>
```

### Step 6: Create Brand Show Page (45 minutes)

**File:** `app/views/brands/show.html.erb`

```erb
<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
  <!-- Breadcrumb -->
  <nav class="flex mb-8" aria-label="Breadcrumb">
    <ol class="flex items-center space-x-4">
      <li>
        <%= link_to workspace_brands_path(@workspace), class: "text-gray-400 hover:text-gray-500" do %>
          <span>Brands</span>
        <% end %>
      </li>
      <li>
        <div class="flex items-center">
          <svg class="flex-shrink-0 h-5 w-5 text-gray-300" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd"/>
          </svg>
          <span class="ml-4 text-sm font-medium text-gray-500"><%= @brand.name %></span>
        </div>
      </li>
    </ol>
  </nav>

  <!-- Header with Actions -->
  <div class="md:flex md:items-center md:justify-between mb-8">
    <div class="flex-1 min-w-0 flex items-center gap-4">
      <% if @brand.logo_url.present? %>
        <%= image_tag @brand.logo_url, class: "h-16 w-16 rounded-lg object-contain", alt: @brand.name %>
      <% end %>
      <div>
        <h1 class="text-3xl font-bold text-gray-900"><%= @brand.name %></h1>
        <p class="mt-1 text-sm text-gray-500">
          Created <%= time_ago_in_words(@brand.created_at) %> ago
        </p>
      </div>
    </div>
    <div class="mt-4 flex gap-3 md:mt-0 md:ml-4">
      <%= link_to edit_workspace_brand_path(@workspace, @brand),
          class: "inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500" do %>
        <svg class="-ml-1 mr-2 h-5 w-5 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
        </svg>
        Edit
      <% end %>
      <%= button_to workspace_brand_path(@workspace, @brand),
          method: :delete,
          data: {
            controller: "confirmation",
            confirmation_message_value: "Are you sure you want to delete #{@brand.name}? This action cannot be undone.",
            turbo_confirm: "Are you sure you want to delete #{@brand.name}?"
          },
          class: "inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500" do %>
        <svg class="-ml-1 mr-2 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
        </svg>
        Delete
      <% end %>
    </div>
  </div>

  <div class="grid grid-cols-1 gap-6 lg:grid-cols-3">
    <!-- Main Content -->
    <div class="lg:col-span-2 space-y-6">
      <!-- Description Card -->
      <div class="bg-white shadow rounded-lg p-6">
        <h2 class="text-lg font-medium text-gray-900 mb-4">Description</h2>
        <% if @brand.description.present? %>
          <p class="text-gray-700 whitespace-pre-wrap"><%= @brand.description %></p>
        <% else %>
          <p class="text-gray-500 italic">No description provided</p>
        <% end %>
      </div>

      <!-- Related Content (Placeholder for future features) -->
      <div class="bg-white shadow rounded-lg p-6">
        <h2 class="text-lg font-medium text-gray-900 mb-4">Related Content</h2>
        <div class="text-center py-8">
          <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
          </svg>
          <p class="mt-2 text-sm text-gray-500">No content items yet</p>
        </div>
      </div>
    </div>

    <!-- Sidebar -->
    <div class="space-y-6">
      <!-- Details Card -->
      <div class="bg-white shadow rounded-lg p-6">
        <h2 class="text-lg font-medium text-gray-900 mb-4">Details</h2>
        <dl class="space-y-4">
          <div>
            <dt class="text-sm font-medium text-gray-500">Website</dt>
            <dd class="mt-1 text-sm text-gray-900">
              <% if @brand.website_url.present? %>
                <%= link_to @brand.website_url, @brand.website_url,
                    target: "_blank",
                    rel: "noopener noreferrer",
                    class: "text-indigo-600 hover:text-indigo-900 flex items-center gap-1" do %>
                  <%= @brand.website_url %>
                  <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                  </svg>
                <% end %>
              <% else %>
                <span class="text-gray-500 italic">Not provided</span>
              <% end %>
            </dd>
          </div>

          <div>
            <dt class="text-sm font-medium text-gray-500">Created</dt>
            <dd class="mt-1 text-sm text-gray-900">
              <%= @brand.created_at.strftime("%B %d, %Y at %I:%M %p") %>
            </dd>
          </div>

          <div>
            <dt class="text-sm font-medium text-gray-500">Last Updated</dt>
            <dd class="mt-1 text-sm text-gray-900">
              <%= @brand.updated_at.strftime("%B %d, %Y at %I:%M %p") %>
            </dd>
          </div>
        </dl>
      </div>

      <!-- Stats Card (Placeholder) -->
      <div class="bg-white shadow rounded-lg p-6">
        <h2 class="text-lg font-medium text-gray-900 mb-4">Statistics</h2>
        <dl class="space-y-4">
          <div class="flex justify-between">
            <dt class="text-sm font-medium text-gray-500">Content Items</dt>
            <dd class="text-sm font-semibold text-gray-900">0</dd>
          </div>
          <div class="flex justify-between">
            <dt class="text-sm font-medium text-gray-500">Campaigns</dt>
            <dd class="text-sm font-semibold text-gray-900">0</dd>
          </div>
        </dl>
      </div>
    </div>
  </div>
</div>
```

### Step 7: Create Stimulus Form Validation Controller (60 minutes)

**File:** `app/javascript/controllers/form_validation_controller.js`

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field", "submit", "imagePreview"]

  connect() {
    console.log("Form validation controller connected")
    this.validateAllFields()
  }

  validate(event) {
    event.preventDefault()

    if (this.validateAllFields()) {
      event.target.submit()
    }
  }

  validateAllFields() {
    let isValid = true

    this.fieldTargets.forEach(field => {
      if (!this.validateField(field)) {
        isValid = false
      }
    })

    return isValid
  }

  validateField(field) {
    const rules = field.dataset.validationRules
    if (!rules) return true

    const value = field.value.trim()
    const ruleArray = rules.split("|")
    let isValid = true
    let errorMessage = ""

    ruleArray.forEach(rule => {
      const [ruleName, ruleValue] = rule.split(":")

      switch (ruleName) {
        case "required":
          if (value === "") {
            isValid = false
            errorMessage = "This field is required"
          }
          break

        case "min":
          if (value.length < parseInt(ruleValue)) {
            isValid = false
            errorMessage = `Must be at least ${ruleValue} characters`
          }
          break

        case "max":
          if (value.length > parseInt(ruleValue)) {
            isValid = false
            errorMessage = `Must be no more than ${ruleValue} characters`
          }
          break

        case "url":
          if (value !== "" && !this.isValidUrl(value)) {
            isValid = false
            errorMessage = "Must be a valid URL"
          }
          break

        case "email":
          if (value !== "" && !this.isValidEmail(value)) {
            isValid = false
            errorMessage = "Must be a valid email address"
          }
          break
      }
    })

    this.updateFieldValidation(field, isValid, errorMessage)
    return isValid
  }

  updateFieldValidation(field, isValid, errorMessage) {
    const errorElement = field.parentElement.querySelector(".validation-error")

    if (isValid) {
      field.classList.remove("border-red-300", "focus:border-red-500", "focus:ring-red-500")
      field.classList.add("border-gray-300", "focus:border-indigo-500", "focus:ring-indigo-500")

      if (errorElement) {
        errorElement.remove()
      }
    } else {
      field.classList.remove("border-gray-300", "focus:border-indigo-500", "focus:ring-indigo-500")
      field.classList.add("border-red-300", "focus:border-red-500", "focus:ring-red-500")

      if (!errorElement) {
        const error = document.createElement("p")
        error.className = "mt-2 text-sm text-red-600 validation-error"
        error.textContent = errorMessage
        field.parentElement.appendChild(error)
      } else {
        errorElement.textContent = errorMessage
      }
    }
  }

  previewImage(event) {
    const url = event.target.value.trim()

    if (this.hasImagePreviewTarget && url && this.isValidUrl(url)) {
      const img = this.imagePreviewTarget.querySelector("img")
      img.src = url
      this.imagePreviewTarget.classList.remove("hidden")

      img.onerror = () => {
        this.imagePreviewTarget.classList.add("hidden")
      }
    } else if (this.hasImagePreviewTarget) {
      this.imagePreviewTarget.classList.add("hidden")
    }
  }

  isValidUrl(string) {
    try {
      const url = new URL(string)
      return url.protocol === "http:" || url.protocol === "https:"
    } catch (_) {
      return false
    }
  }

  isValidEmail(email) {
    const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    return re.test(email)
  }
}
```

### Step 8: Create Confirmation Controller for Delete (30 minutes)

**File:** `app/javascript/controllers/confirmation_controller.js`

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    message: String
  }

  connect() {
    this.element.addEventListener("submit", this.confirm.bind(this))
  }

  confirm(event) {
    if (!window.confirm(this.messageValue || "Are you sure?")) {
      event.preventDefault()
      event.stopImmediatePropagation()
    }
  }
}
```

## Testing

### Step 9: Controller Tests (60 minutes)

**File:** `test/controllers/brands_controller_test.rb`

```ruby
require "test_helper"

class BrandsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @workspace = workspaces(:one)
    @brand = brands(:one)
    sign_in @user
  end

  test "should get index" do
    get workspace_brands_url(@workspace)
    assert_response :success
    assert_select "h1", "Brands"
  end

  test "should get new" do
    get new_workspace_brand_url(@workspace)
    assert_response :success
    assert_select "h1", "Create New Brand"
  end

  test "should create brand" do
    assert_difference("Brand.count") do
      post workspace_brands_url(@workspace), params: {
        brand: {
          name: "New Brand",
          description: "A new brand description",
          website_url: "https://newbrand.com"
        }
      }
    end

    assert_redirected_to workspace_brand_url(@workspace, Brand.last)
    assert_equal "Brand was successfully created.", flash[:notice]
  end

  test "should not create brand with invalid data" do
    assert_no_difference("Brand.count") do
      post workspace_brands_url(@workspace), params: {
        brand: { name: "" }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should show brand" do
    get workspace_brand_url(@workspace, @brand)
    assert_response :success
    assert_select "h1", @brand.name
  end

  test "should get edit" do
    get edit_workspace_brand_url(@workspace, @brand)
    assert_response :success
    assert_select "h1", "Edit Brand"
  end

  test "should update brand" do
    patch workspace_brand_url(@workspace, @brand), params: {
      brand: { name: "Updated Brand Name" }
    }

    assert_redirected_to workspace_brand_url(@workspace, @brand)
    assert_equal "Brand was successfully updated.", flash[:notice]
    @brand.reload
    assert_equal "Updated Brand Name", @brand.name
  end

  test "should not update brand with invalid data" do
    patch workspace_brand_url(@workspace, @brand), params: {
      brand: { name: "" }
    }

    assert_response :unprocessable_entity
  end

  test "should destroy brand" do
    assert_difference("Brand.count", -1) do
      delete workspace_brand_url(@workspace, @brand)
    end

    assert_redirected_to workspace_brands_url(@workspace)
    assert_equal "Brand was successfully deleted.", flash[:notice]
  end

  test "should scope brands to workspace" do
    other_workspace = workspaces(:two)

    get workspace_brands_url(other_workspace)
    assert_response :success

    # Should not see brands from @workspace
    assert_select "h3", text: @brand.name, count: 0
  end

  test "should search brands" do
    get workspace_brands_url(@workspace), params: { search: @brand.name }
    assert_response :success
    assert_select "h3", @brand.name
  end

  test "should redirect if workspace not found" do
    get workspace_brands_url(id: 99999)
    assert_redirected_to workspaces_url
    assert_equal "Workspace not found.", flash[:alert]
  end

  test "should redirect if brand not found" do
    get workspace_brand_url(@workspace, id: 99999)
    assert_redirected_to workspace_brands_url(@workspace)
    assert_equal "Brand not found.", flash[:alert]
  end
end
```

### Step 10: System Tests (60 minutes)

**File:** `test/system/brands_test.rb`

```ruby
require "application_system_test_case"

class BrandsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @workspace = workspaces(:one)
    @brand = brands(:one)
    sign_in @user
  end

  test "visiting the index" do
    visit workspace_brands_url(@workspace)

    assert_selector "h1", text: "Brands"
    assert_selector "h3", text: @brand.name
  end

  test "creating a brand" do
    visit workspace_brands_url(@workspace)
    click_on "New Brand"

    fill_in "Name", with: "Test Brand"
    fill_in "Description", with: "This is a test brand"
    fill_in "Website URL", with: "https://testbrand.com"

    click_on "Create Brand"

    assert_text "Brand was successfully created"
    assert_selector "h1", text: "Test Brand"
  end

  test "updating a brand" do
    visit workspace_brand_url(@workspace, @brand)
    click_on "Edit"

    fill_in "Name", with: "Updated Brand Name"
    click_on "Update Brand"

    assert_text "Brand was successfully updated"
    assert_selector "h1", text: "Updated Brand Name"
  end

  test "destroying a brand" do
    visit workspace_brand_url(@workspace, @brand)

    accept_confirm do
      click_on "Delete"
    end

    assert_text "Brand was successfully deleted"
    assert_current_path workspace_brands_path(@workspace)
  end

  test "searching brands" do
    visit workspace_brands_url(@workspace)

    fill_in "Search", with: @brand.name
    click_on "Search"

    assert_selector "h3", text: @brand.name
  end

  test "validation errors display" do
    visit new_workspace_brand_url(@workspace)

    click_on "Create Brand"

    assert_text "error prohibited this brand from being saved"
    assert_text "Name can't be blank"
  end

  test "logo preview works" do
    visit new_workspace_brand_url(@workspace)

    fill_in "Logo URL", with: "https://example.com/logo.png"

    # Wait for preview to load
    assert_selector "img[src='https://example.com/logo.png']"
  end
end
```

## Model Validations

### Step 11: Update Brand Model (15 minutes)

Ensure the Brand model has proper validations.

**File:** `app/models/brand.rb`

```ruby
class Brand < ApplicationRecord
  belongs_to :workspace

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :description, length: { maximum: 500 }, allow_blank: true
  validates :website_url, url: true, allow_blank: true
  validates :logo_url, url: true, allow_blank: true

  # Scopes
  scope :alphabetical, -> { order(name: :asc) }
  scope :search, ->(query) { where("name ILIKE ?", "%#{query}%") }

  # Callbacks
  before_save :normalize_urls

  private

  def normalize_urls
    self.website_url = normalize_url(website_url) if website_url.present?
    self.logo_url = normalize_url(logo_url) if logo_url.present?
  end

  def normalize_url(url)
    url = url.strip
    url = "https://#{url}" unless url.match?(/\Ahttps?:\/\//)
    url
  end
end
```

**Note:** You'll need to create a custom URL validator:

**File:** `app/validators/url_validator.rb`

```ruby
class UrlValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?

    begin
      uri = URI.parse(value)
      unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
        record.errors.add(attribute, "must be a valid HTTP or HTTPS URL")
      end
    rescue URI::InvalidURIError
      record.errors.add(attribute, "must be a valid URL")
    end
  end
end
```

## Fixtures for Testing

### Step 12: Create Test Fixtures (15 minutes)

**File:** `test/fixtures/brands.yml`

```yaml
one:
  workspace: one
  name: "Nike"
  description: "Just Do It - Athletic apparel and footwear"
  website_url: "https://www.nike.com"
  logo_url: "https://example.com/nike-logo.png"
  created_at: <%= 1.week.ago %>
  updated_at: <%= 1.day.ago %>

two:
  workspace: one
  name: "Apple"
  description: "Think Different - Technology and innovation"
  website_url: "https://www.apple.com"
  logo_url: "https://example.com/apple-logo.png"
  created_at: <%= 2.weeks.ago %>
  updated_at: <%= 2.days.ago %>

three:
  workspace: two
  name: "Tesla"
  description: "Accelerating the world's transition to sustainable energy"
  website_url: "https://www.tesla.com"
  logo_url: "https://example.com/tesla-logo.png"
  created_at: <%= 3.weeks.ago %>
  updated_at: <%= 3.days.ago %>
```

## Additional Features

### Step 13: Add Pagination (Optional - 20 minutes)

Add Kaminari gem for pagination:

```bash
# Add to Gemfile
gem 'kaminari'

# Run bundle install
bundle install

# Generate Kaminari views for Tailwind
rails generate kaminari:views default
```

**Customize pagination view** at `app/views/kaminari/_paginator.html.erb`:

```erb
<nav class="flex items-center justify-between border-t border-gray-200 px-4 sm:px-0">
  <div class="-mt-px flex w-0 flex-1">
    <%= link_to_previous_page @brands, 'Previous', class: 'inline-flex items-center border-t-2 border-transparent pt-4 pr-1 text-sm font-medium text-gray-500 hover:border-gray-300 hover:text-gray-700' %>
  </div>
  <div class="hidden md:-mt-px md:flex">
    <% each_page do |page| %>
      <% if page.current? %>
        <span class="inline-flex items-center border-t-2 border-indigo-500 px-4 pt-4 text-sm font-medium text-indigo-600">
          <%= page %>
        </span>
      <% elsif page.gap? %>
        <span class="inline-flex items-center border-t-2 border-transparent px-4 pt-4 text-sm font-medium text-gray-500">...</span>
      <% else %>
        <%= link_to page, url, class: 'inline-flex items-center border-t-2 border-transparent px-4 pt-4 text-sm font-medium text-gray-500 hover:border-gray-300 hover:text-gray-700' %>
      <% end %>
    <% end %>
  </div>
  <div class="-mt-px flex w-0 flex-1 justify-end">
    <%= link_to_next_page @brands, 'Next', class: 'inline-flex items-center border-t-2 border-transparent pt-4 pl-1 text-sm font-medium text-gray-500 hover:border-gray-300 hover:text-gray-700' %>
  </div>
</nav>
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Routes Not Working
**Problem:** Getting "No route matches" errors

**Solution:**
```bash
# Check routes
rails routes | grep brands

# Ensure routes are nested properly
resources :workspaces do
  resources :brands
end
```

#### 2. Workspace Scoping Not Working
**Problem:** Seeing brands from other workspaces

**Solution:**
- Ensure `set_workspace` before_action is running
- Check that queries use `@workspace.brands` not `Brand.all`
- Verify workspace_id is in params

#### 3. Stimulus Controller Not Loading
**Problem:** Form validation not working

**Solution:**
```bash
# Ensure Stimulus is properly installed
bin/rails stimulus:manifest:update

# Check controller is registered
# app/javascript/controllers/index.js should have:
import FormValidationController from "./form_validation_controller"
application.register("form-validation", FormValidationController)
```

#### 4. Flash Messages Not Showing
**Problem:** Success/error messages not appearing

**Solution:**
- Ensure flash partial is in layout
- Check Turbo is not interfering
- Add `data-turbo="false"` if needed

#### 5. Image Preview Not Working
**Problem:** Logo preview not displaying

**Solution:**
- Check CORS if loading external images
- Verify URL is valid
- Check browser console for errors
- Ensure Stimulus target is correct

#### 6. Delete Confirmation Not Showing
**Problem:** Delete happens without confirmation

**Solution:**
```erb
# Use Turbo's built-in confirmation
<%= button_to "Delete", workspace_brand_path(@workspace, @brand),
    method: :delete,
    data: { turbo_confirm: "Are you sure?" } %>
```

#### 7. Validation Errors Not Displaying
**Problem:** Server-side errors not showing in form

**Solution:**
- Ensure form renders with `status: :unprocessable_entity`
- Check error partial is included in form
- Verify `@brand.errors.any?` is true

## Performance Optimization

### Database Indexes

Ensure proper indexes exist:

```ruby
# db/migrate/XXXXXX_add_indexes_to_brands.rb
class AddIndexesToBrands < ActiveRecord::Migration[7.0]
  def change
    add_index :brands, :workspace_id
    add_index :brands, [:workspace_id, :name]
    add_index :brands, :created_at
  end
end
```

### N+1 Query Prevention

```ruby
# In controller
def index
  @brands = @workspace.brands
                      .includes(:workspace)
                      .order(name: :asc)
                      .page(params[:page])
end
```

## Security Considerations

### Authorization

Add Pundit policies for fine-grained authorization:

**File:** `app/policies/brand_policy.rb`

```ruby
class BrandPolicy < ApplicationPolicy
  def index?
    user.member_of?(record.workspace)
  end

  def show?
    user.member_of?(record.workspace)
  end

  def create?
    user.admin_of?(record.workspace)
  end

  def update?
    user.admin_of?(record.workspace)
  end

  def destroy?
    user.admin_of?(record.workspace)
  end
end
```

### Strong Parameters

Ensure only permitted attributes can be updated:

```ruby
def brand_params
  params.require(:brand).permit(:name, :description, :logo_url, :website_url)
end
```

## Accessibility

### ARIA Labels and Roles

```erb
<!-- Add to forms -->
<%= f.text_field :name,
    aria: {
      label: "Brand name",
      required: true,
      describedby: "name-help"
    } %>
<p id="name-help" class="mt-1 text-sm text-gray-500">
  The official name of the brand
</p>
```

### Keyboard Navigation

Ensure all interactive elements are keyboard accessible:
- Tab order is logical
- Enter key submits forms
- Escape key closes modals
- Focus indicators are visible

## Deployment Checklist

- [ ] All migrations run successfully
- [ ] Seeds data created for testing
- [ ] Environment variables configured
- [ ] Asset compilation works
- [ ] All tests passing
- [ ] No N+1 queries
- [ ] Proper error handling
- [ ] Flash messages working
- [ ] Authorization enforced
- [ ] Responsive on mobile
- [ ] Accessibility tested
- [ ] Performance optimized

## Next Steps

After completing this task:

1. **Test thoroughly** - Run all tests and manually test CRUD operations
2. **Add content items** - Link brands to content (Task 09)
3. **Add campaigns** - Create campaigns for brands (Task 10)
4. **Add analytics** - Track brand performance (Task 11)
5. **Add bulk operations** - Import/export brands (Task 12)

## Resources

- [Rails Guides - Controllers](https://guides.rubyonrails.org/action_controller_overview.html)
- [Tailwind CSS Components](https://tailwindui.com/components)
- [Stimulus Handbook](https://stimulus.hotwired.dev/handbook/introduction)
- [Turbo Handbook](https://turbo.hotwired.dev/handbook/introduction)
- [Rails Testing Guide](https://guides.rubyonrails.org/testing.html)

## Estimated Time Breakdown

| Task | Time |
|------|------|
| BrandsController | 30 min |
| Index page | 45 min |
| Form partial | 60 min |
| New/Edit pages | 30 min |
| Show page | 45 min |
| Stimulus controllers | 90 min |
| Controller tests | 60 min |
| System tests | 60 min |
| Model validations | 15 min |
| Fixtures | 15 min |
| **Total** | **6 hours** |

---

**Status:** Ready for implementation
**Priority:** High
**Dependencies:** Tasks 01, 02, 03, 07
**Blocks:** Tasks 09, 10, 11

