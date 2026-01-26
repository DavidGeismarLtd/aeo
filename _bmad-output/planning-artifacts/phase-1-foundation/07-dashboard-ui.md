# Task 1.7: Dashboard UI Implementation

**Estimated Time:** 8 hours

---

## 📋 Overview

Build a beautiful, responsive dashboard that serves as the main landing page after authentication. The dashboard displays key statistics, brand performance metrics, and provides quick access to core functionality.

**What You'll Build:**
- Statistics cards showing key metrics
- Brand list with visibility scores
- Empty states for new workspaces
- Loading states for async data
- Responsive Tailwind UI components
- Cached performance optimizations

---

## 🎯 Learning Objectives

After completing this task, you will understand:
- How to build dashboard controllers with statistics
- Tailwind CSS utility classes for beautiful UIs
- Rails caching strategies for performance
- Empty state and loading state patterns
- Responsive design principles
- View component organization

---

## 📦 Prerequisites

Before starting this task, ensure you have completed:
- ✅ Task 1.1: Rails Initialization
- ✅ Task 1.2: Database Setup
- ✅ Task 1.3: Devise Authentication
- ✅ Task 1.4: Core Models (Brand, Workspace)
- ✅ Task 1.5: Multi-tenancy Setup

**Required Knowledge:**
- Basic Rails controllers and views
- ERB templating
- Tailwind CSS basics
- Rails caching concepts

---

## 🏗️ Architecture Overview

### Dashboard Data Flow

```
User Request
    ↓
DashboardController#index
    ↓
Check Cache (15 min TTL)
    ↓
    ├─→ Cache Hit → Return Cached Data
    ↓
    └─→ Cache Miss → Calculate Statistics
            ↓
        Query Database
            ↓
        Aggregate Metrics
            ↓
        Store in Cache
            ↓
        Return Data
    ↓
Render View
    ↓
Display Statistics Cards
Display Brand List
Display Charts (Placeholder)
```

### Component Hierarchy

```
dashboard/index.html.erb
├── Statistics Section
│   ├── Total Brands Card
│   ├── Total Mentions Card
│   ├── Average Score Card
│   └── Mentions This Week Card
├── Brand List Section
│   ├── Brand Card (each brand)
│   │   ├── Brand Name
│   │   ├── Visibility Score
│   │   ├── Mention Count
│   │   └── Action Buttons
│   └── Empty State (if no brands)
└── Charts Section (Placeholder)
    └── Coming Soon Message
```

---

## 📝 Step-by-Step Implementation

### Step 1: Generate Dashboard Controller

**Time Estimate:** 15 minutes

Generate the dashboard controller and set up routes:

```bash
# Generate controller
rails generate controller Dashboard index

# This creates:
# - app/controllers/dashboard_controller.rb
# - app/views/dashboard/index.html.erb
# - spec/controllers/dashboard_controller_spec.rb (if using RSpec)
```

**Update Routes:**

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Devise routes
  devise_for :users

  # Authenticated routes
  authenticated :user do
    # Workspace routes
    resources :workspaces, only: [:index, :new, :create, :show, :edit, :update]

    # Workspace-scoped routes
    scope ':workspace_slug', as: :workspace do
      # Dashboard is the workspace home
      get '/', to: 'dashboard#index', as: :dashboard

      resources :brands
      resources :settings, only: [:index, :update]
      resources :team_members, only: [:index, :create, :destroy]
    end

    # Root redirects to workspaces
    root to: 'workspaces#index', as: :authenticated_root
  end

  # Unauthenticated root
  root to: redirect('/users/sign_in')
end
```

**Verify Routes:**

```bash
rails routes | grep dashboard
# Should show: GET /:workspace_slug(.:format) dashboard#index
```

---

### Step 2: Implement Dashboard Controller

**Time Estimate:** 1 hour

Create the controller with statistics calculation and caching:

```ruby
# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :set_workspace

  def index
    # Load brands with associations for efficiency
    @brands = @workspace.brands
                        .active
                        .includes(:visibility_scores, :mentions)
                        .order(created_at: :desc)

    # Calculate and cache dashboard statistics
    @stats = fetch_dashboard_stats
  end

  private

  def set_workspace
    @workspace = current_user.workspaces.find_by!(slug: params[:workspace_slug])
  rescue ActiveRecord::RecordNotFound
    redirect_to workspaces_path, alert: 'Workspace not found'
  end

  def fetch_dashboard_stats
    # Cache for 15 minutes to improve performance
    Rails.cache.fetch(dashboard_cache_key, expires_in: 15.minutes) do
      calculate_dashboard_stats
    end
  end

  def dashboard_cache_key
    # Cache key includes workspace ID and current date
    # This ensures fresh data each day and per workspace
    "workspace:#{@workspace.id}:dashboard:#{Date.current}"
  end

  def calculate_dashboard_stats
    {
      total_brands: calculate_total_brands,
      total_mentions: calculate_total_mentions,
      avg_visibility_score: calculate_avg_visibility_score,
      mentions_this_week: calculate_mentions_this_week,
      top_brand: find_top_brand,
      recent_activity: calculate_recent_activity
    }
  end

  def calculate_total_brands
    @workspace.brands.active.count
  end

  def calculate_total_mentions
    # Count mentions from last 30 days
    @workspace.brands
              .joins(:mentions)
              .where('mentions.detected_at >= ?', 30.days.ago)
              .count
  end

  def calculate_avg_visibility_score
    # Average visibility score from current day
    score = @workspace.brands
                      .joins(:visibility_scores)
                      .where(visibility_scores: { date: Date.current })
                      .average('visibility_scores.overall_score')

    score&.round(1) || 0
  end

  def calculate_mentions_this_week
    @workspace.brands
              .joins(:mentions)
              .where('mentions.detected_at >= ?', 1.week.ago)
              .count
  end

  def find_top_brand
    # Find brand with highest visibility score today
    @workspace.brands
              .joins(:visibility_scores)
              .where(visibility_scores: { date: Date.current })
              .order('visibility_scores.overall_score DESC')
              .first
  end

  def calculate_recent_activity
    # Count of mentions in last 24 hours
    @workspace.brands
              .joins(:mentions)
              .where('mentions.detected_at >= ?', 24.hours.ago)
              .count
  end
end
```

**Key Features:**
- ✅ Workspace scoping with `set_workspace`
- ✅ Efficient database queries with `includes`
- ✅ 15-minute cache for statistics
- ✅ Cache key includes workspace and date
- ✅ Separate methods for each statistic
- ✅ Error handling for missing workspace

---

### Step 3: Create Dashboard View

**Time Estimate:** 2 hours

Build the main dashboard view with Tailwind CSS:

```erb
<!-- app/views/dashboard/index.html.erb -->
<div class="min-h-screen bg-gray-50">
  <!-- Page Header -->
  <div class="bg-white shadow">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
      <div class="md:flex md:items-center md:justify-between">
        <div class="flex-1 min-w-0">
          <h1 class="text-3xl font-bold text-gray-900">
            <%= @workspace.name %> Dashboard
          </h1>
          <p class="mt-1 text-sm text-gray-500">
            Welcome back! Here's what's happening with your brands.
          </p>
        </div>
        <div class="mt-4 flex md:mt-0 md:ml-4">
          <%= link_to workspace_brands_path(@workspace),
              class: "inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500" do %>
            <svg class="-ml-1 mr-2 h-5 w-5 text-gray-500" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
              <path d="M10 12a2 2 0 100-4 2 2 0 000 4z" />
              <path fill-rule="evenodd" d="M.458 10C1.732 5.943 5.522 3 10 3s8.268 2.943 9.542 7c-1.274 4.057-5.064 7-9.542 7S1.732 14.057.458 10zM14 10a4 4 0 11-8 0 4 4 0 018 0z" clip-rule="evenodd" />
            </svg>
            View All Brands
          <% end %>
          <%= link_to new_workspace_brand_path(@workspace),
              class: "ml-3 inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500" do %>
            <svg class="-ml-1 mr-2 h-5 w-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clip-rule="evenodd" />
            </svg>
            Add Brand
          <% end %>
        </div>
      </div>
    </div>
  </div>

  <!-- Main Content -->
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <!-- Statistics Cards -->
    <%= render 'statistics_cards', stats: @stats %>

    <!-- Brand List or Empty State -->
    <div class="mt-8">
      <% if @brands.any? %>
        <%= render 'brand_list', brands: @brands %>
      <% else %>
        <%= render 'empty_state' %>
      <% end %>
    </div>

    <!-- Charts Section (Placeholder) -->
    <div class="mt-8">
      <%= render 'charts_placeholder' %>
    </div>
  </div>
</div>
```

---

### Step 4: Create Statistics Cards Partial

**Time Estimate:** 1 hour

Create beautiful statistics cards with Tailwind CSS:

```erb
<!-- app/views/dashboard/_statistics_cards.html.erb -->
<div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
  <!-- Total Brands Card -->
  <div class="bg-white overflow-hidden shadow rounded-lg">
    <div class="p-5">
      <div class="flex items-center">
        <div class="flex-shrink-0">
          <div class="flex items-center justify-center h-12 w-12 rounded-md bg-indigo-500 text-white">
            <svg class="h-6 w-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
            </svg>
          </div>
        </div>
        <div class="ml-5 w-0 flex-1">
          <dl>
            <dt class="text-sm font-medium text-gray-500 truncate">
              Total Brands
            </dt>
            <dd class="flex items-baseline">
              <div class="text-2xl font-semibold text-gray-900">
                <%= stats[:total_brands] %>
              </div>
            </dd>
          </dl>
        </div>
      </div>
    </div>
    <div class="bg-gray-50 px-5 py-3">
      <div class="text-sm">
        <%= link_to workspace_brands_path(@workspace), class: "font-medium text-indigo-600 hover:text-indigo-500" do %>
          View all brands
          <span aria-hidden="true"> &rarr;</span>
        <% end %>
      </div>
    </div>
  </div>

  <!-- Total Mentions Card -->
  <div class="bg-white overflow-hidden shadow rounded-lg">
    <div class="p-5">
      <div class="flex items-center">
        <div class="flex-shrink-0">
          <div class="flex items-center justify-center h-12 w-12 rounded-md bg-green-500 text-white">
            <svg class="h-6 w-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z" />
            </svg>
          </div>
        </div>
        <div class="ml-5 w-0 flex-1">
          <dl>
            <dt class="text-sm font-medium text-gray-500 truncate">
              Total Mentions
            </dt>
            <dd class="flex items-baseline">
              <div class="text-2xl font-semibold text-gray-900">
                <%= number_with_delimiter(stats[:total_mentions]) %>
              </div>
              <div class="ml-2 flex items-baseline text-sm font-semibold text-gray-500">
                Last 30 days
              </div>
            </dd>
          </dl>
        </div>
      </div>
    </div>
    <div class="bg-gray-50 px-5 py-3">
      <div class="text-sm">
        <span class="font-medium text-gray-700">
          <%= stats[:mentions_this_week] %> this week
        </span>
      </div>
    </div>
  </div>

  <!-- Average Visibility Score Card -->
  <div class="bg-white overflow-hidden shadow rounded-lg">
    <div class="p-5">
      <div class="flex items-center">
        <div class="flex-shrink-0">
          <div class="flex items-center justify-center h-12 w-12 rounded-md bg-yellow-500 text-white">
            <svg class="h-6 w-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
            </svg>
          </div>
        </div>
        <div class="ml-5 w-0 flex-1">
          <dl>
            <dt class="text-sm font-medium text-gray-500 truncate">
              Avg Visibility Score
            </dt>
            <dd class="flex items-baseline">
              <div class="text-2xl font-semibold text-gray-900">
                <%= stats[:avg_visibility_score] %>
              </div>
              <div class="ml-2 flex items-baseline text-sm font-semibold">
                <% if stats[:avg_visibility_score] >= 70 %>
                  <span class="text-green-600">Excellent</span>
                <% elsif stats[:avg_visibility_score] >= 50 %>
                  <span class="text-yellow-600">Good</span>
                <% else %>
                  <span class="text-red-600">Needs Work</span>
                <% end %>
              </div>
            </dd>
          </dl>
        </div>
      </div>
    </div>
    <div class="bg-gray-50 px-5 py-3">
      <div class="text-sm">
        <span class="font-medium text-gray-700">
          Today's average
        </span>
      </div>
    </div>
  </div>

  <!-- Recent Activity Card -->
  <div class="bg-white overflow-hidden shadow rounded-lg">
    <div class="p-5">
      <div class="flex items-center">
        <div class="flex-shrink-0">
          <div class="flex items-center justify-center h-12 w-12 rounded-md bg-purple-500 text-white">
            <svg class="h-6 w-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
            </svg>
          </div>
        </div>
        <div class="ml-5 w-0 flex-1">
          <dl>
            <dt class="text-sm font-medium text-gray-500 truncate">
              Recent Activity
            </dt>
            <dd class="flex items-baseline">
              <div class="text-2xl font-semibold text-gray-900">
                <%= stats[:recent_activity] %>
              </div>
              <div class="ml-2 flex items-baseline text-sm font-semibold text-gray-500">
                Last 24h
              </div>
            </dd>
          </dl>
        </div>
      </div>
    </div>
    <div class="bg-gray-50 px-5 py-3">
      <div class="text-sm">
        <% if stats[:top_brand] %>
          <span class="font-medium text-gray-700">
            Top: <%= stats[:top_brand].name %>
          </span>
        <% else %>
          <span class="font-medium text-gray-500">
            No data yet
          </span>
        <% end %>
      </div>
    </div>
  </div>
</div>
```

**Design Features:**
- ✅ 4-column grid (responsive to 1 column on mobile)
- ✅ Color-coded icons for each metric
- ✅ Large, readable numbers
- ✅ Contextual information in footer
- ✅ Conditional styling based on values
- ✅ Hover effects on links

---

### Step 5: Create Brand List Partial

**Time Estimate:** 1.5 hours

Display brands with visibility scores and actions:

```erb
<!-- app/views/dashboard/_brand_list.html.erb -->
<div class="bg-white shadow overflow-hidden sm:rounded-md">
  <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
    <h3 class="text-lg leading-6 font-medium text-gray-900">
      Your Brands
    </h3>
    <p class="mt-1 text-sm text-gray-500">
      <%= pluralize(brands.count, 'brand') %> being monitored
    </p>
  </div>

  <ul role="list" class="divide-y divide-gray-200">
    <% brands.each do |brand| %>
      <li>
        <div class="px-4 py-4 sm:px-6 hover:bg-gray-50 transition duration-150">
          <div class="flex items-center justify-between">
            <div class="flex items-center min-w-0 flex-1">
              <!-- Brand Icon -->
              <div class="flex-shrink-0">
                <div class="h-12 w-12 rounded-full bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center text-white font-bold text-lg">
                  <%= brand.name[0].upcase %>
                </div>
              </div>

              <!-- Brand Info -->
              <div class="min-w-0 flex-1 px-4">
                <div>
                  <p class="text-sm font-medium text-indigo-600 truncate">
                    <%= link_to brand.name, workspace_brand_path(@workspace, brand), class: "hover:text-indigo-900" %>
                  </p>
                  <p class="mt-1 flex items-center text-sm text-gray-500">
                    <% if brand.domain.present? %>
                      <svg class="flex-shrink-0 mr-1.5 h-4 w-4 text-gray-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M12.586 4.586a2 2 0 112.828 2.828l-3 3a2 2 0 01-2.828 0 1 1 0 00-1.414 1.414 4 4 0 005.656 0l3-3a4 4 0 00-5.656-5.656l-1.5 1.5a1 1 0 101.414 1.414l1.5-1.5zm-5 5a2 2 0 012.828 0 1 1 0 101.414-1.414 4 4 0 00-5.656 0l-3 3a4 4 0 105.656 5.656l1.5-1.5a1 1 0 10-1.414-1.414l-1.5 1.5a2 2 0 11-2.828-2.828l3-3z" clip-rule="evenodd" />
                      </svg>
                      <%= brand.domain %>
                    <% else %>
                      <span class="text-gray-400">No domain set</span>
                    <% end %>
                  </p>
                </div>

                <!-- Metrics -->
                <div class="mt-2 flex items-center space-x-4">
                  <!-- Mention Count -->
                  <div class="flex items-center text-sm text-gray-500">
                    <svg class="flex-shrink-0 mr-1.5 h-4 w-4 text-gray-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                      <path fill-rule="evenodd" d="M18 10c0 3.866-3.582 7-8 7a8.841 8.841 0 01-4.083-.98L2 17l1.338-3.123C2.493 12.767 2 11.434 2 10c0-3.866 3.582-7 8-7s8 3.134 8 7zM7 9H5v2h2V9zm8 0h-2v2h2V9zM9 9h2v2H9V9z" clip-rule="evenodd" />
                    </svg>
                    <%= pluralize(brand.mentions_count, 'mention') %>
                  </div>

                  <!-- Active Status -->
                  <% if brand.active? %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                      Active
                    </span>
                  <% else %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                      Inactive
                    </span>
                  <% end %>
                </div>
              </div>
            </div>

            <!-- Visibility Score -->
            <div class="ml-5 flex-shrink-0 flex items-center space-x-4">
              <div class="text-right">
                <p class="text-xs text-gray-500 mb-1">Visibility Score</p>
                <% score = brand.current_visibility_score %>
                <div class="flex items-center">
                  <div class="text-2xl font-bold <%= score_color_class(score) %>">
                    <%= score.round(1) %>
                  </div>
                  <div class="ml-2">
                    <%= render 'score_badge', score: score %>
                  </div>
                </div>
              </div>

              <!-- Actions -->
              <div class="flex items-center space-x-2">
                <%= link_to workspace_brand_path(@workspace, brand),
                    class: "inline-flex items-center p-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500",
                    title: "View Details" do %>
                  <svg class="h-5 w-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                    <path d="M10 12a2 2 0 100-4 2 2 0 000 4z" />
                    <path fill-rule="evenodd" d="M.458 10C1.732 5.943 5.522 3 10 3s8.268 2.943 9.542 7c-1.274 4.057-5.064 7-9.542 7S1.732 14.057.458 10zM14 10a4 4 0 11-8 0 4 4 0 018 0z" clip-rule="evenodd" />
                  </svg>
                <% end %>

                <%= link_to edit_workspace_brand_path(@workspace, brand),
                    class: "inline-flex items-center p-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500",
                    title: "Edit Brand" do %>
                  <svg class="h-5 w-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                    <path d="M13.586 3.586a2 2 0 112.828 2.828l-.793.793-2.828-2.828.793-.793zM11.379 5.793L3 14.172V17h2.828l8.38-8.379-2.83-2.828z" />
                  </svg>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </li>
    <% end %>
  </ul>
</div>
```

**Add Helper Methods:**

```ruby
# app/helpers/dashboard_helper.rb
module DashboardHelper
  def score_color_class(score)
    case score
    when 80..100
      'text-green-600'
    when 60..79
      'text-yellow-600'
    when 40..59
      'text-orange-600'
    else
      'text-red-600'
    end
  end

  def score_badge_class(score)
    case score
    when 80..100
      'bg-green-100 text-green-800'
    when 60..79
      'bg-yellow-100 text-yellow-800'
    when 40..59
      'bg-orange-100 text-orange-800'
    else
      'bg-red-100 text-red-800'
    end
  end

  def score_label(score)
    case score
    when 80..100
      'Excellent'
    when 60..79
      'Good'
    when 40..59
      'Fair'
    else
      'Poor'
    end
  end
end
```

**Create Score Badge Partial:**

```erb
<!-- app/views/dashboard/_score_badge.html.erb -->
<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium <%= score_badge_class(score) %>">
  <%= score_label(score) %>
</span>
```

---

### Step 6: Create Empty State Partial

**Time Estimate:** 30 minutes

Beautiful empty state when no brands exist:

```erb
<!-- app/views/dashboard/_empty_state.html.erb -->
<div class="bg-white shadow sm:rounded-lg">
  <div class="px-4 py-12 sm:px-6 lg:px-8">
    <div class="text-center">
      <!-- Icon -->
      <svg class="mx-auto h-24 w-24 text-gray-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
      </svg>

      <!-- Heading -->
      <h3 class="mt-6 text-2xl font-semibold text-gray-900">
        No brands yet
      </h3>

      <!-- Description -->
      <p class="mt-3 text-base text-gray-500 max-w-md mx-auto">
        Get started by adding your first brand to monitor. Track mentions, analyze sentiment, and measure visibility across AI platforms.
      </p>

      <!-- Action Button -->
      <div class="mt-8">
        <%= link_to new_workspace_brand_path(@workspace),
            class: "inline-flex items-center px-6 py-3 border border-transparent text-base font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500" do %>
          <svg class="-ml-1 mr-3 h-5 w-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clip-rule="evenodd" />
          </svg>
          Add Your First Brand
        <% end %>
      </div>

      <!-- Help Text -->
      <div class="mt-8 border-t border-gray-200 pt-8">
        <h4 class="text-sm font-medium text-gray-900 mb-4">
          What you can do with brands:
        </h4>
        <div class="grid grid-cols-1 gap-4 sm:grid-cols-3 max-w-3xl mx-auto">
          <div class="flex flex-col items-center">
            <div class="flex items-center justify-center h-12 w-12 rounded-md bg-indigo-100 text-indigo-600 mb-3">
              <svg class="h-6 w-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
              </svg>
            </div>
            <p class="text-sm text-gray-600 text-center">
              Track visibility across AI platforms
            </p>
          </div>

          <div class="flex flex-col items-center">
            <div class="flex items-center justify-center h-12 w-12 rounded-md bg-green-100 text-green-600 mb-3">
              <svg class="h-6 w-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z" />
              </svg>
            </div>
            <p class="text-sm text-gray-600 text-center">
              Monitor mentions and sentiment
            </p>
          </div>

          <div class="flex flex-col items-center">
            <div class="flex items-center justify-center h-12 w-12 rounded-md bg-yellow-100 text-yellow-600 mb-3">
              <svg class="h-6 w-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
              </svg>
            </div>
            <p class="text-sm text-gray-600 text-center">
              Analyze trends over time
            </p>
          </div>
        </div>
      </div>
    </div>
  </div>
</div>
```

---

### Step 7: Create Charts Placeholder Partial

**Time Estimate:** 15 minutes

Placeholder for future chart functionality:

```erb
<!-- app/views/dashboard/_charts_placeholder.html.erb -->
<div class="bg-white shadow sm:rounded-lg">
  <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
    <h3 class="text-lg leading-6 font-medium text-gray-900">
      Analytics & Trends
    </h3>
    <p class="mt-1 text-sm text-gray-500">
      Visualize your brand performance over time
    </p>
  </div>

  <div class="px-4 py-12 sm:px-6 lg:px-8">
    <div class="text-center">
      <div class="inline-flex items-center justify-center h-16 w-16 rounded-full bg-gray-100 mb-4">
        <svg class="h-8 w-8 text-gray-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
        </svg>
      </div>
      <h4 class="text-lg font-medium text-gray-900">
        Charts Coming Soon
      </h4>
      <p class="mt-2 text-sm text-gray-500 max-w-md mx-auto">
        We're working on beautiful charts to help you visualize your brand's visibility trends, sentiment analysis, and platform comparisons.
      </p>

      <!-- Preview of what's coming -->
      <div class="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-3 max-w-2xl mx-auto">
        <div class="bg-gray-50 rounded-lg p-4 border-2 border-dashed border-gray-300">
          <p class="text-sm font-medium text-gray-700">Visibility Trends</p>
          <p class="text-xs text-gray-500 mt-1">Track score changes over time</p>
        </div>
        <div class="bg-gray-50 rounded-lg p-4 border-2 border-dashed border-gray-300">
          <p class="text-sm font-medium text-gray-700">Sentiment Analysis</p>
          <p class="text-xs text-gray-500 mt-1">Positive vs negative mentions</p>
        </div>
        <div class="bg-gray-50 rounded-lg p-4 border-2 border-dashed border-gray-300">
          <p class="text-sm font-medium text-gray-700">Platform Comparison</p>
          <p class="text-xs text-gray-500 mt-1">Performance across platforms</p>
        </div>
      </div>
    </div>
  </div>
</div>
```

---

### Step 8: Add Loading States

**Time Estimate:** 30 minutes

Create loading states for async operations:

```erb
<!-- app/views/dashboard/_loading_skeleton.html.erb -->
<div class="animate-pulse">
  <!-- Statistics Cards Skeleton -->
  <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4 mb-8">
    <% 4.times do %>
      <div class="bg-white overflow-hidden shadow rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="h-12 w-12 bg-gray-200 rounded-md"></div>
            </div>
            <div class="ml-5 w-0 flex-1">
              <div class="h-4 bg-gray-200 rounded w-3/4 mb-2"></div>
              <div class="h-8 bg-gray-200 rounded w-1/2"></div>
            </div>
          </div>
        </div>
        <div class="bg-gray-50 px-5 py-3">
          <div class="h-4 bg-gray-200 rounded w-1/2"></div>
        </div>
      </div>
    <% end %>
  </div>

  <!-- Brand List Skeleton -->
  <div class="bg-white shadow overflow-hidden sm:rounded-md">
    <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
      <div class="h-6 bg-gray-200 rounded w-1/4 mb-2"></div>
      <div class="h-4 bg-gray-200 rounded w-1/6"></div>
    </div>

    <ul role="list" class="divide-y divide-gray-200">
      <% 3.times do %>
        <li class="px-4 py-4 sm:px-6">
          <div class="flex items-center justify-between">
            <div class="flex items-center min-w-0 flex-1">
              <div class="h-12 w-12 bg-gray-200 rounded-full"></div>
              <div class="min-w-0 flex-1 px-4">
                <div class="h-5 bg-gray-200 rounded w-1/3 mb-2"></div>
                <div class="h-4 bg-gray-200 rounded w-1/4"></div>
              </div>
            </div>
            <div class="h-8 bg-gray-200 rounded w-16"></div>
          </div>
        </li>
      <% end %>
    </ul>
  </div>
</div>
```

**Usage in Controller (Optional - for Turbo Frames):**

```ruby
# app/controllers/dashboard_controller.rb
def index
  # ... existing code ...

  respond_to do |format|
    format.html
    format.turbo_stream do
      render turbo_stream: turbo_stream.replace(
        'dashboard-content',
        partial: 'dashboard/content',
        locals: { brands: @brands, stats: @stats }
      )
    end
  end
end
```

---

### Step 9: Update Application Layout

**Time Estimate:** 30 minutes

Ensure the layout supports the dashboard:

```erb
<!-- app/views/layouts/application.html.erb -->
<!DOCTYPE html>
<html class="h-full bg-gray-50">
  <head>
    <title><%= content_for(:title) || "AEO - AI Engine Optimization" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body class="h-full">
    <% if user_signed_in? %>
      <!-- Navigation -->
      <%= render 'shared/navbar' %>

      <!-- Flash Messages -->
      <%= render 'shared/flash_messages' %>

      <!-- Main Content -->
      <%= yield %>
    <% else %>
      <!-- Unauthenticated Layout -->
      <div class="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
        <%= render 'shared/flash_messages' %>
        <%= yield %>
      </div>
    <% end %>
  </body>
</html>
```

**Create Navbar Partial:**

```erb
<!-- app/views/shared/_navbar.html.erb -->
<nav class="bg-white shadow-sm border-b border-gray-200">
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    <div class="flex justify-between h-16">
      <!-- Left Side: Logo & Navigation -->
      <div class="flex">
        <!-- Logo -->
        <div class="flex-shrink-0 flex items-center">
          <%= link_to workspace_dashboard_path(@workspace), class: "flex items-center" do %>
            <span class="text-2xl font-bold text-indigo-600">AEO</span>
          <% end %>
        </div>

        <!-- Navigation Links -->
        <div class="hidden sm:ml-6 sm:flex sm:space-x-8">
          <%= link_to workspace_dashboard_path(@workspace),
              class: "#{current_page?(workspace_dashboard_path(@workspace)) ? 'border-indigo-500 text-gray-900' : 'border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700'} inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium" do %>
            Dashboard
          <% end %>

          <%= link_to workspace_brands_path(@workspace),
              class: "#{current_page?(workspace_brands_path(@workspace)) ? 'border-indigo-500 text-gray-900' : 'border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700'} inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium" do %>
            Brands
          <% end %>
        </div>
      </div>

      <!-- Right Side: Workspace Switcher & User Menu -->
      <div class="flex items-center space-x-4">
        <!-- Workspace Switcher -->
        <% if @workspace %>
          <div class="relative" data-controller="dropdown">
            <button type="button"
                    data-action="click->dropdown#toggle"
                    class="flex items-center text-sm font-medium text-gray-700 hover:text-gray-900 focus:outline-none">
              <span class="mr-2"><%= @workspace.name %></span>
              <svg class="h-5 w-5 text-gray-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd" />
              </svg>
            </button>
          </div>
        <% end %>

        <!-- User Menu -->
        <div class="relative" data-controller="dropdown">
          <button type="button"
                  data-action="click->dropdown#toggle"
                  class="flex items-center text-sm rounded-full focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
            <span class="sr-only">Open user menu</span>
            <div class="h-8 w-8 rounded-full bg-indigo-600 flex items-center justify-center text-white font-medium">
              <%= current_user.email[0].upcase %>
            </div>
          </button>
        </div>
      </div>
    </div>
  </div>
</nav>
```

**Create Flash Messages Partial:**

```erb
<!-- app/views/shared/_flash_messages.html.erb -->
<% if flash.any? %>
  <div class="fixed top-4 right-4 z-50 space-y-2" data-controller="flash">
    <% flash.each do |type, message| %>
      <div class="max-w-sm w-full bg-white shadow-lg rounded-lg pointer-events-auto ring-1 ring-black ring-opacity-5 overflow-hidden"
           data-flash-target="message"
           data-action="click->flash#dismiss">
        <div class="p-4">
          <div class="flex items-start">
            <div class="flex-shrink-0">
              <% if type == 'notice' || type == 'success' %>
                <svg class="h-6 w-6 text-green-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              <% elsif type == 'alert' || type == 'error' %>
                <svg class="h-6 w-6 text-red-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              <% else %>
                <svg class="h-6 w-6 text-blue-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              <% end %>
            </div>
            <div class="ml-3 w-0 flex-1 pt-0.5">
              <p class="text-sm font-medium text-gray-900">
                <%= message %>
              </p>
            </div>
            <div class="ml-4 flex-shrink-0 flex">
              <button class="bg-white rounded-md inline-flex text-gray-400 hover:text-gray-500 focus:outline-none">
                <span class="sr-only">Close</span>
                <svg class="h-5 w-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
                </svg>
              </button>
            </div>
          </div>
        </div>
      </div>
    <% end %>
  </div>
<% end %>
```

---

### Step 10: Add Stimulus Controllers (Optional)

**Time Estimate:** 30 minutes

Add JavaScript interactivity with Stimulus:

```javascript
// app/javascript/controllers/dropdown_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  toggle(event) {
    event.stopPropagation()
    this.menuTarget.classList.toggle("hidden")
  }

  hide(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.add("hidden")
    }
  }

  connect() {
    document.addEventListener("click", this.hide.bind(this))
  }

  disconnect() {
    document.removeEventListener("click", this.hide.bind(this))
  }
}
```

```javascript
// app/javascript/controllers/flash_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["message"]

  connect() {
    // Auto-dismiss after 5 seconds
    setTimeout(() => {
      this.dismiss()
    }, 5000)
  }

  dismiss() {
    this.element.remove()
  }
}
```

---

## 🧪 Testing

### Controller Tests

**Time Estimate:** 1 hour

```ruby
# spec/controllers/dashboard_controller_spec.rb
require 'rails_helper'

RSpec.describe DashboardController, type: :controller do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, owner: user) }
  let!(:membership) { create(:workspace_membership, user: user, workspace: workspace) }

  before do
    sign_in user
  end

  describe 'GET #index' do
    context 'with valid workspace' do
      before do
        get :index, params: { workspace_slug: workspace.slug }
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'assigns @workspace' do
        expect(assigns(:workspace)).to eq(workspace)
      end

      it 'assigns @brands' do
        expect(assigns(:brands)).to eq(workspace.brands.active)
      end

      it 'assigns @stats' do
        expect(assigns(:stats)).to be_a(Hash)
        expect(assigns(:stats)).to have_key(:total_brands)
        expect(assigns(:stats)).to have_key(:total_mentions)
        expect(assigns(:stats)).to have_key(:avg_visibility_score)
      end

      it 'renders the index template' do
        expect(response).to render_template(:index)
      end
    end

    context 'with invalid workspace' do
      it 'redirects to workspaces path' do
        get :index, params: { workspace_slug: 'invalid-slug' }
        expect(response).to redirect_to(workspaces_path)
      end

      it 'sets an alert flash message' do
        get :index, params: { workspace_slug: 'invalid-slug' }
        expect(flash[:alert]).to eq('Workspace not found')
      end
    end

    context 'with brands and mentions' do
      let!(:brand1) { create(:brand, workspace: workspace, active: true) }
      let!(:brand2) { create(:brand, workspace: workspace, active: true) }
      let!(:mention1) { create(:mention, brand: brand1, detected_at: 1.day.ago) }
      let!(:mention2) { create(:mention, brand: brand2, detected_at: 2.days.ago) }

      before do
        get :index, params: { workspace_slug: workspace.slug }
      end

      it 'includes active brands' do
        expect(assigns(:brands)).to include(brand1, brand2)
      end

      it 'calculates correct total brands' do
        expect(assigns(:stats)[:total_brands]).to eq(2)
      end

      it 'calculates mentions correctly' do
        expect(assigns(:stats)[:total_mentions]).to be >= 2
      end
    end

    context 'caching' do
      it 'caches dashboard statistics' do
        expect(Rails.cache).to receive(:fetch).with(
          "workspace:#{workspace.id}:dashboard:#{Date.current}",
          expires_in: 15.minutes
        ).and_call_original

        get :index, params: { workspace_slug: workspace.slug }
      end
    end
  end
end
```

### View Tests

```ruby
# spec/views/dashboard/index.html.erb_spec.rb
require 'rails_helper'

RSpec.describe 'dashboard/index.html.erb', type: :view do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, owner: user) }
  let(:stats) do
    {
      total_brands: 5,
      total_mentions: 150,
      avg_visibility_score: 75.5,
      mentions_this_week: 25,
      top_brand: nil,
      recent_activity: 10
    }
  end

  before do
    assign(:workspace, workspace)
    assign(:stats, stats)
    allow(view).to receive(:current_user).and_return(user)
  end

  context 'with brands' do
    let!(:brands) { create_list(:brand, 3, workspace: workspace) }

    before do
      assign(:brands, brands)
      render
    end

    it 'displays the workspace name' do
      expect(rendered).to have_content(workspace.name)
    end

    it 'displays statistics cards' do
      expect(rendered).to have_content('Total Brands')
      expect(rendered).to have_content('5')
      expect(rendered).to have_content('Total Mentions')
      expect(rendered).to have_content('150')
    end

    it 'displays brand list' do
      brands.each do |brand|
        expect(rendered).to have_content(brand.name)
      end
    end

    it 'has add brand button' do
      expect(rendered).to have_link('Add Brand')
    end
  end

  context 'without brands' do
    before do
      assign(:brands, [])
      render
    end

    it 'displays empty state' do
      expect(rendered).to have_content('No brands yet')
    end

    it 'has call to action' do
      expect(rendered).to have_link('Add Your First Brand')
    end
  end
end
```

### Helper Tests

```ruby
# spec/helpers/dashboard_helper_spec.rb
require 'rails_helper'

RSpec.describe DashboardHelper, type: :helper do
  describe '#score_color_class' do
    it 'returns green for excellent scores' do
      expect(helper.score_color_class(85)).to eq('text-green-600')
    end

    it 'returns yellow for good scores' do
      expect(helper.score_color_class(65)).to eq('text-yellow-600')
    end

    it 'returns orange for fair scores' do
      expect(helper.score_color_class(45)).to eq('text-orange-600')
    end

    it 'returns red for poor scores' do
      expect(helper.score_color_class(25)).to eq('text-red-600')
    end
  end

  describe '#score_label' do
    it 'returns correct labels for score ranges' do
      expect(helper.score_label(85)).to eq('Excellent')
      expect(helper.score_label(65)).to eq('Good')
      expect(helper.score_label(45)).to eq('Fair')
      expect(helper.score_label(25)).to eq('Poor')
    end
  end
end
```

### Running Tests

```bash
# Run all dashboard tests
bundle exec rspec spec/controllers/dashboard_controller_spec.rb
bundle exec rspec spec/views/dashboard/
bundle exec rspec spec/helpers/dashboard_helper_spec.rb

# Run with coverage
COVERAGE=true bundle exec rspec spec/controllers/dashboard_controller_spec.rb
```

---

## ✅ Success Criteria

### Functional Requirements

- ✅ Dashboard loads successfully for authenticated users
- ✅ Statistics cards display correct metrics
- ✅ Brand list shows all active brands
- ✅ Empty state appears when no brands exist
- ✅ Navigation works correctly
- ✅ Workspace scoping functions properly
- ✅ Cache improves performance (verify with logs)

### UI/UX Requirements

- ✅ Responsive design works on mobile, tablet, desktop
- ✅ Tailwind classes applied correctly
- ✅ Icons display properly
- ✅ Colors follow design system
- ✅ Hover states work on interactive elements
- ✅ Loading states provide feedback
- ✅ Flash messages appear and dismiss

### Performance Requirements

- ✅ Dashboard loads in < 500ms (with cache)
- ✅ Statistics cached for 15 minutes
- ✅ Database queries optimized with `includes`
- ✅ No N+1 queries (verify with Bullet gem)

### Code Quality

- ✅ All tests passing
- ✅ Controller methods under 10 lines
- ✅ Views use partials for organization
- ✅ Helpers for reusable logic
- ✅ Consistent naming conventions

---

## 🐛 Troubleshooting

### Issue: Dashboard shows 404

**Solution:**
```bash
# Verify routes
rails routes | grep dashboard

# Ensure workspace slug is correct
rails console
> Workspace.first.slug
```

### Issue: Statistics not updating

**Solution:**
```ruby
# Clear cache manually
Rails.cache.clear

# Or clear specific workspace cache
Rails.cache.delete("workspace:#{workspace_id}:dashboard:#{Date.current}")
```

### Issue: Tailwind styles not applying

**Solution:**
```bash
# Rebuild Tailwind CSS
rails tailwindcss:build

# Watch for changes in development
rails tailwindcss:watch
```

### Issue: N+1 queries detected

**Solution:**
```ruby
# Add includes to controller
@brands = @workspace.brands
                    .active
                    .includes(:visibility_scores, :mentions)
                    .order(created_at: :desc)
```

### Issue: Flash messages not dismissing

**Solution:**
```javascript
// Verify Stimulus controller is loaded
// Check browser console for errors
// Ensure data-controller="flash" is present
```

---

## 📚 Additional Resources

### Tailwind CSS
- [Tailwind CSS Documentation](https://tailwindcss.com/docs)
- [Tailwind UI Components](https://tailwindui.com/)
- [Heroicons](https://heroicons.com/)

### Rails Caching
- [Rails Caching Guide](https://guides.rubyonrails.org/caching_with_rails.html)
- [Fragment Caching](https://guides.rubyonrails.org/caching_with_rails.html#fragment-caching)

### Hotwire
- [Turbo Documentation](https://turbo.hotwired.dev/)
- [Stimulus Documentation](https://stimulus.hotwired.dev/)

---

## 🎯 Next Steps

After completing the dashboard UI:

1. **Task 1.8: Brand Management UI**
   - Create/Edit/Delete brand forms
   - Brand detail pages
   - Brand settings

2. **Task 2.1: Monitoring Infrastructure**
   - Set up background jobs
   - Implement AI platform monitors
   - Create mention detection

3. **Add Charts & Analytics**
   - Install Chartkick
   - Create trend charts
   - Add sentiment visualizations

4. **Enhance Dashboard**
   - Real-time updates with Turbo Streams
   - Advanced filtering
   - Export functionality

---

## 📝 Summary

You've successfully built a beautiful, functional dashboard with:

- ✅ Statistics cards showing key metrics
- ✅ Brand list with visibility scores
- ✅ Empty states for new users
- ✅ Responsive Tailwind UI
- ✅ Performance optimizations with caching
- ✅ Comprehensive test coverage

The dashboard provides users with an at-a-glance view of their brand monitoring data and serves as the central hub for the application.

**Estimated Total Time:** 8 hours
**Actual Time:** __________ (fill in after completion)

---

**Great job! 🎉 Your dashboard is ready for users!**


