---
document_type: Implementation Guide - Phase 1
product_name: GEO Platform
phase: Foundation (Weeks 1-2)
version: 1.0
date: 2026-01-23
author: David Geismar
tech_stack: Ruby on Rails 7.x, PostgreSQL, Redis, Sidekiq, Tailwind CSS
---

# Phase 1: Foundation (Weeks 1-2)

## Overview

**Goal:** Set up the foundational infrastructure and core models for the GEO platform

**Duration:** 2 weeks

**Team:** 2-3 developers

**Deliverables:**
- Rails application initialized with all dependencies
- Database schema for core models
- User authentication system
- Multi-tenancy (Workspaces)
- Basic dashboard UI
- Development environment fully configured

---

## Week 1: Project Setup & Core Infrastructure

### Feature 1.1: Rails Application Initialization

**Estimated Time:** 4 hours

#### Step 1: Create New Rails Application

```bash
# Create new Rails 7 app with PostgreSQL and Tailwind
rails new geo_platform \
  --database=postgresql \
  --css=tailwind \
  --skip-test \
  --skip-jbuilder

cd geo_platform
```

#### Step 2: Configure Gemfile

```ruby
# Gemfile
source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.2.2"

# Core Rails
gem "rails", "~> 7.1.0"
gem "pg", "~> 1.5"
gem "puma", "~> 6.0"

# Frontend
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "tailwindcss-rails"

# Background Jobs
gem "sidekiq", "~> 7.0"
gem "redis", "~> 5.0"

# Authentication
gem "bcrypt", "~> 3.1.7"

# API Clients
gem "httparty", "~> 0.21"
gem "ruby-openai", "~> 6.0"

# Utilities
gem "dotenv-rails", groups: [:development, :test]
gem "pagy", "~> 6.0" # Pagination

group :development, :test do
  gem "debug", platforms: %i[ mri mingw x64_mingw ]
  gem "rspec-rails", "~> 6.0"
  gem "factory_bot_rails", "~> 6.2"
  gem "faker", "~> 3.2"
end

group :test do
  gem "shoulda-matchers", "~> 5.3"
  gem "vcr", "~> 6.1"
  gem "webmock", "~> 3.18"
  gem "simplecov", require: false
end

group :development do
  gem "web-console"
  gem "annotate" # Add schema comments to models
  gem "bullet" # N+1 query detection
  gem "letter_opener" # Preview emails in browser
end
```

#### Step 3: Install Dependencies

```bash
bundle install

# Install Tailwind CSS
rails tailwindcss:install

# Install RSpec
rails generate rspec:install

# Install Sidekiq
bundle exec rails generate sidekiq:install
```

#### Step 4: Configure Database

```yaml
# config/database.yml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000

development:
  <<: *default
  database: geo_platform_development
  
  # Enable PostgreSQL extensions
  schema_search_path: "public,extensions"

test:
  <<: *default
  database: geo_platform_test

production:
  <<: *default
  url: <%= ENV['DATABASE_URL'] %>
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
```

#### Step 5: Create Database and Enable Extensions

```bash
# Create databases
rails db:create

# Create migration for PostgreSQL extensions
rails generate migration EnablePostgresExtensions
```

```ruby
# db/migrate/XXXXXX_enable_postgres_extensions.rb
class EnablePostgresExtensions < ActiveRecord::Migration[7.1]
  def change
    # Enable extensions
    enable_extension 'pgcrypto'      # UUID generation
    enable_extension 'pg_trgm'       # Trigram matching for fuzzy search
    enable_extension 'hstore'        # Key-value storage
    
    # Create schema for TimescaleDB (we'll add TimescaleDB later)
    execute "CREATE SCHEMA IF NOT EXISTS timescaledb"
  end
end
```

```bash
rails db:migrate
```

#### Step 6: Configure Redis and Sidekiq

```yaml
# config/sidekiq.yml
:concurrency: 5
:max_retries: 3

:queues:
  - [critical, 10]
  - [default, 5]
  - [monitoring, 3]
  - [analysis, 2]
  - [low, 1]

production:
  :concurrency: 10
```

```ruby
# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end
```

```ruby
# config/routes.rb
Rails.application.routes.draw do
  require 'sidekiq/web'
  
  # Mount Sidekiq web UI (protect in production!)
  mount Sidekiq::Web => '/sidekiq'
  
  # Health check
  get '/health', to: 'health#index'
  
  root 'dashboard#index'
end
```

#### Step 7: Configure Environment Variables

```bash
# .env.development
DATABASE_URL=postgresql://localhost/geo_platform_development
REDIS_URL=redis://localhost:6379/0

# API Keys (get these from respective services)
OPENAI_API_KEY=your_openai_key_here
ANTHROPIC_API_KEY=your_anthropic_key_here
```

```ruby
# config/application.rb
module GeoPlatform
  class Application < Rails::Application
    config.load_defaults 7.1
    
    # Autoload lib directory
    config.autoload_paths << Rails.root.join('lib')
    
    # Active Job adapter
    config.active_job.queue_adapter = :sidekiq
    
    # Time zone
    config.time_zone = 'UTC'
    config.active_record.default_timezone = :utc
  end
end
```

---

### Feature 1.2: Core Database Models

**Estimated Time:** 8 hours

#### Step 1: Create User Model

```bash
rails generate model User \
  email:string \
  password_digest:string \
  first_name:string \
  last_name:string \
  confirmed_at:datetime \
  confirmation_token:string \
  reset_password_token:string \
  reset_password_sent_at:datetime
```

```ruby
# db/migrate/XXXXXX_create_users.rb
class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users, id: :uuid do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :first_name
      t.string :last_name
      t.datetime :confirmed_at
      t.string :confirmation_token
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.timestamps

      t.index :email, unique: true
      t.index :confirmation_token, unique: true
      t.index :reset_password_token, unique: true
    end
  end
end
```

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_secure_password

  # Associations
  has_many :workspace_memberships, dependent: :destroy
  has_many :workspaces, through: :workspace_memberships

  # Validations
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }

  # Callbacks
  before_save :downcase_email
  before_create :generate_confirmation_token

  # Scopes
  scope :confirmed, -> { where.not(confirmed_at: nil) }
  scope :unconfirmed, -> { where(confirmed_at: nil) }

  def confirmed?
    confirmed_at.present?
  end

  def confirm!
    update(confirmed_at: Time.current, confirmation_token: nil)
  end

  def generate_password_reset_token!
    self.reset_password_token = SecureRandom.urlsafe_base64
    self.reset_password_sent_at = Time.current
    save!
  end

  def password_reset_expired?
    reset_password_sent_at < 2.hours.ago
  end

  private

  def downcase_email
    self.email = email.downcase if email.present?
  end

  def generate_confirmation_token
    self.confirmation_token = SecureRandom.urlsafe_base64
  end
end
```

#### Step 2: Create Workspace Model

```bash
rails generate model Workspace \
  name:string \
  slug:string \
  settings:jsonb
```

```ruby
# db/migrate/XXXXXX_create_workspaces.rb
class CreateWorkspaces < ActiveRecord::Migration[7.1]
  def change
    create_table :workspaces, id: :uuid do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.jsonb :settings, default: {}
      t.timestamps

      t.index :slug, unique: true
    end
  end
end
```

```ruby
# app/models/workspace.rb
class Workspace < ApplicationRecord
  # Associations
  has_many :workspace_memberships, dependent: :destroy
  has_many :users, through: :workspace_memberships
  has_many :brands, dependent: :destroy
  has_many :ai_platform_configs, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :slug, format: { with: /\A[a-z0-9-]+\z/, message: "only lowercase letters, numbers, and hyphens" }

  # Callbacks
  before_validation :generate_slug, on: :create

  # Encrypt sensitive settings
  encrypts :settings, deterministic: false

  def owner
    workspace_memberships.find_by(role: 'owner')&.user
  end

  def admins
    users.joins(:workspace_memberships).where(workspace_memberships: { role: ['owner', 'admin'] })
  end

  private

  def generate_slug
    return if slug.present?

    base_slug = name.parameterize
    candidate_slug = base_slug
    counter = 1

    while Workspace.exists?(slug: candidate_slug)
      candidate_slug = "#{base_slug}-#{counter}"
      counter += 1
    end

    self.slug = candidate_slug
  end
end
```

#### Step 3: Create WorkspaceMembership Model

```bash
rails generate model WorkspaceMembership \
  workspace:references \
  user:references \
  role:string
```

```ruby
# db/migrate/XXXXXX_create_workspace_memberships.rb
class CreateWorkspaceMemberships < ActiveRecord::Migration[7.1]
  def change
    create_table :workspace_memberships, id: :uuid do |t|
      t.references :workspace, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :role, null: false, default: 'viewer'
      t.timestamps

      t.index [:workspace_id, :user_id], unique: true
    end
  end
end
```

```ruby
# app/models/workspace_membership.rb
class WorkspaceMembership < ApplicationRecord
  belongs_to :workspace
  belongs_to :user

  # Validations
  validates :role, presence: true, inclusion: { in: %w[owner admin editor viewer] }
  validates :user_id, uniqueness: { scope: :workspace_id }

  # Scopes
  scope :owners, -> { where(role: 'owner') }
  scope :admins, -> { where(role: ['owner', 'admin']) }
  scope :editors, -> { where(role: ['owner', 'admin', 'editor']) }

  # Role checks
  def owner?
    role == 'owner'
  end

  def admin?
    role.in?(['owner', 'admin'])
  end

  def editor?
    role.in?(['owner', 'admin', 'editor'])
  end

  def viewer?
    role == 'viewer'
  end
end
```

#### Step 4: Create Brand Model

```bash
rails generate model Brand \
  workspace:references \
  name:string \
  domain:string \
  description:text \
  metadata:jsonb \
  active:boolean
```

```ruby
# db/migrate/XXXXXX_create_brands.rb
class CreateBrands < ActiveRecord::Migration[7.1]
  def change
    create_table :brands, id: :uuid do |t|
      t.references :workspace, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.string :domain
      t.text :description
      t.jsonb :metadata, default: {}
      t.boolean :active, default: true
      t.integer :mentions_count, default: 0
      t.timestamps

      t.index [:workspace_id, :name]
      t.index :domain
      t.index :active
    end
  end
end
```

```ruby
# app/models/brand.rb
class Brand < ApplicationRecord
  belongs_to :workspace
  has_many :brand_variations, dependent: :destroy
  has_many :mentions, dependent: :destroy
  has_many :visibility_scores, dependent: :destroy
  has_many :competitors, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :name, uniqueness: { scope: :workspace_id }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  # Cache expensive queries
  def current_visibility_score
    Rails.cache.fetch("brand:#{id}:visibility_score:#{Date.current}", expires_in: 1.hour) do
      visibility_scores.where(date: Date.current, ai_platform_id: nil).first&.overall_score || 0
    end
  end

  def mention_count_last_30_days
    Rails.cache.fetch("brand:#{id}:mention_count:30d", expires_in: 30.minutes) do
      mentions.where(detected_at: 30.days.ago..Time.current).count
    end
  end
end
```

#### Step 5: Run Migrations

```bash
rails db:migrate
```

#### Step 6: Create Factories for Testing

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { 'password123' }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    confirmed_at { Time.current }

    trait :unconfirmed do
      confirmed_at { nil }
    end
  end
end

# spec/factories/workspaces.rb
FactoryBot.define do
  factory :workspace do
    name { Faker::Company.name }
    settings { {} }

    trait :with_owner do
      after(:create) do |workspace|
        create(:workspace_membership, workspace: workspace, role: 'owner')
      end
    end
  end
end

# spec/factories/workspace_memberships.rb
FactoryBot.define do
  factory :workspace_membership do
    workspace
    user
    role { 'viewer' }

    trait :owner do
      role { 'owner' }
    end

    trait :admin do
      role { 'admin' }
    end

    trait :editor do
      role { 'editor' }
    end
  end
end

# spec/factories/brands.rb
FactoryBot.define do
  factory :brand do
    workspace
    name { Faker::Company.name }
    domain { Faker::Internet.domain_name }
    description { Faker::Company.catch_phrase }
    metadata { { industry: 'Technology', product_category: 'SaaS' } }
    active { true }
  end
end
```

### Feature 1.3: Authentication System

**Estimated Time:** 6 hours

#### Step 1: Create Authentication Concern

```ruby
# app/controllers/concerns/authentication.rb
module Authentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :user_signed_in?
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def user_signed_in?
    current_user.present?
  end

  def require_authentication
    unless user_signed_in?
      session[:return_to] = request.fullpath
      redirect_to login_path, alert: 'Please sign in to continue'
    end
  end

  def sign_in(user)
    session[:user_id] = user.id
    @current_user = user
  end

  def sign_out
    session.delete(:user_id)
    @current_user = nil
  end
end
```

#### Step 2: Create Sessions Controller

```bash
rails generate controller Sessions new create destroy
```

```ruby
# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  skip_before_action :require_authentication, only: [:new, :create]

  def new
    # Login form
  end

  def create
    user = User.find_by(email: params[:email].downcase)

    if user && user.authenticate(params[:password])
      if user.confirmed?
        sign_in(user)
        redirect_to session.delete(:return_to) || root_path, notice: 'Signed in successfully'
      else
        redirect_to login_path, alert: 'Please confirm your email address'
      end
    else
      flash.now[:alert] = 'Invalid email or password'
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    sign_out
    redirect_to root_path, notice: 'Signed out successfully'
  end
end
```

#### Step 3: Create Registrations Controller

```bash
rails generate controller Registrations new create
```

```ruby
# app/controllers/registrations_controller.rb
class RegistrationsController < ApplicationController
  skip_before_action :require_authentication

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      # Create a default workspace for the user
      workspace = Workspace.create!(name: "#{@user.first_name}'s Workspace")
      WorkspaceMembership.create!(workspace: workspace, user: @user, role: 'owner')

      # Send confirmation email (implement later)
      # UserMailer.confirmation_email(@user).deliver_later

      redirect_to login_path, notice: 'Account created! Please check your email to confirm.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation, :first_name, :last_name)
  end
end
```

#### Step 4: Create Confirmations Controller

```bash
rails generate controller Confirmations show
```

```ruby
# app/controllers/confirmations_controller.rb
class ConfirmationsController < ApplicationController
  skip_before_action :require_authentication

  def show
    user = User.find_by(confirmation_token: params[:token])

    if user && !user.confirmed?
      user.confirm!
      sign_in(user)
      redirect_to root_path, notice: 'Email confirmed successfully!'
    else
      redirect_to root_path, alert: 'Invalid or expired confirmation link'
    end
  end
end
```

#### Step 5: Create Password Resets Controller

```bash
rails generate controller PasswordResets new create edit update
```

```ruby
# app/controllers/password_resets_controller.rb
class PasswordResetsController < ApplicationController
  skip_before_action :require_authentication

  def new
    # Request password reset form
  end

  def create
    user = User.find_by(email: params[:email].downcase)

    if user
      user.generate_password_reset_token!
      # UserMailer.password_reset_email(user).deliver_later
      redirect_to login_path, notice: 'Password reset instructions sent to your email'
    else
      flash.now[:alert] = 'Email address not found'
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @user = User.find_by(reset_password_token: params[:token])

    unless @user && !@user.password_reset_expired?
      redirect_to new_password_reset_path, alert: 'Invalid or expired reset link'
    end
  end

  def update
    @user = User.find_by(reset_password_token: params[:token])

    if @user && !@user.password_reset_expired?
      if @user.update(password_params.merge(reset_password_token: nil, reset_password_sent_at: nil))
        sign_in(@user)
        redirect_to root_path, notice: 'Password reset successfully'
      else
        render :edit, status: :unprocessable_entity
      end
    else
      redirect_to new_password_reset_path, alert: 'Invalid or expired reset link'
    end
  end

  private

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
```

#### Step 6: Update Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  require 'sidekiq/web'
  mount Sidekiq::Web => '/sidekiq'

  # Authentication
  get    '/login',  to: 'sessions#new'
  post   '/login',  to: 'sessions#create'
  delete '/logout', to: 'sessions#destroy'

  get  '/signup', to: 'registrations#new'
  post '/signup', to: 'registrations#create'

  get '/confirm/:token', to: 'confirmations#show', as: :confirm_email

  resources :password_resets, only: [:new, :create, :edit, :update]

  # Health check
  get '/health', to: 'health#index'

  # Dashboard (requires authentication)
  root 'dashboard#index'
end
```

#### Step 7: Update Application Controller

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Authentication

  before_action :require_authentication
end
```

#### Step 8: Create Login View

```erb
<!-- app/views/sessions/new.html.erb -->
<div class="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
  <div class="max-w-md w-full space-y-8">
    <div>
      <h2 class="mt-6 text-center text-3xl font-extrabold text-gray-900">
        Sign in to your account
      </h2>
    </div>

    <%= form_with url: login_path, method: :post, class: "mt-8 space-y-6" do |f| %>
      <div class="rounded-md shadow-sm -space-y-px">
        <div>
          <%= label_tag :email, "Email address", class: "sr-only" %>
          <%= email_field_tag :email, nil,
              class: "appearance-none rounded-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-t-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm",
              placeholder: "Email address",
              required: true,
              autofocus: true %>
        </div>
        <div>
          <%= label_tag :password, "Password", class: "sr-only" %>
          <%= password_field_tag :password, nil,
              class: "appearance-none rounded-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-b-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm",
              placeholder: "Password",
              required: true %>
        </div>
      </div>

      <div class="flex items-center justify-between">
        <div class="text-sm">
          <%= link_to "Forgot your password?", new_password_reset_path, class: "font-medium text-indigo-600 hover:text-indigo-500" %>
        </div>
      </div>

      <div>
        <%= submit_tag "Sign in", class: "group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500" %>
      </div>

      <div class="text-center text-sm">
        Don't have an account?
        <%= link_to "Sign up", signup_path, class: "font-medium text-indigo-600 hover:text-indigo-500" %>
      </div>
    <% end %>
  </div>
</div>
```

#### Step 9: Create Registration View

```erb
<!-- app/views/registrations/new.html.erb -->
<div class="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
  <div class="max-w-md w-full space-y-8">
    <div>
      <h2 class="mt-6 text-center text-3xl font-extrabold text-gray-900">
        Create your account
      </h2>
    </div>

    <%= form_with model: @user, url: signup_path, class: "mt-8 space-y-6" do |f| %>
      <%= render 'shared/error_messages', object: @user %>

      <div class="rounded-md shadow-sm space-y-4">
        <div class="grid grid-cols-2 gap-4">
          <div>
            <%= f.label :first_name, class: "block text-sm font-medium text-gray-700" %>
            <%= f.text_field :first_name,
                class: "mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm",
                required: true %>
          </div>
          <div>
            <%= f.label :last_name, class: "block text-sm font-medium text-gray-700" %>
            <%= f.text_field :last_name,
                class: "mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm",
                required: true %>
          </div>
        </div>

        <div>
          <%= f.label :email, class: "block text-sm font-medium text-gray-700" %>
          <%= f.email_field :email,
              class: "mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm",
              required: true %>
        </div>

        <div>
          <%= f.label :password, class: "block text-sm font-medium text-gray-700" %>
          <%= f.password_field :password,
              class: "mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm",
              required: true %>
          <p class="mt-1 text-sm text-gray-500">Minimum 8 characters</p>
        </div>

        <div>
          <%= f.label :password_confirmation, class: "block text-sm font-medium text-gray-700" %>
          <%= f.password_field :password_confirmation,
              class: "mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm",
              required: true %>
        </div>
      </div>

      <div>
        <%= f.submit "Create account", class: "w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500" %>
      </div>

      <div class="text-center text-sm">
        Already have an account?
        <%= link_to "Sign in", login_path, class: "font-medium text-indigo-600 hover:text-indigo-500" %>
      </div>
    <% end %>
  </div>
</div>
```

### Feature 1.4: Multi-tenancy Implementation

**Estimated Time:** 4 hours

#### Step 1: Create Authorization Concern

```ruby
# app/controllers/concerns/authorization.rb
module Authorization
  extend ActiveSupport::Concern

  included do
    helper_method :current_workspace, :current_workspace_membership
  end

  def current_workspace
    @current_workspace ||= find_workspace
  end

  def current_workspace_membership
    @current_workspace_membership ||= current_workspace&.workspace_memberships&.find_by(user: current_user)
  end

  def set_current_workspace
    unless current_workspace
      redirect_to workspaces_path, alert: 'Workspace not found'
    end
  end

  def authorize_workspace_admin!
    unless current_workspace_membership&.admin?
      redirect_to root_path, alert: 'You are not authorized to perform this action'
    end
  end

  def authorize_workspace_editor!
    unless current_workspace_membership&.editor?
      redirect_to root_path, alert: 'You are not authorized to perform this action'
    end
  end

  private

  def find_workspace
    if params[:workspace_slug]
      current_user.workspaces.find_by(slug: params[:workspace_slug])
    elsif session[:current_workspace_id]
      current_user.workspaces.find_by(id: session[:current_workspace_id])
    else
      current_user.workspaces.first
    end
  end
end
```

#### Step 2: Create Workspaces Controller

```bash
rails generate controller Workspaces index show new create edit update
```

```ruby
# app/controllers/workspaces_controller.rb
class WorkspacesController < ApplicationController
  include Authorization

  before_action :set_workspace, only: [:show, :edit, :update, :switch]
  before_action :authorize_workspace_admin!, only: [:edit, :update]

  def index
    @workspaces = current_user.workspaces.order(created_at: :desc)
  end

  def show
    redirect_to workspace_dashboard_path(@workspace)
  end

  def new
    @workspace = Workspace.new
  end

  def create
    @workspace = Workspace.new(workspace_params)

    if @workspace.save
      WorkspaceMembership.create!(workspace: @workspace, user: current_user, role: 'owner')
      session[:current_workspace_id] = @workspace.id
      redirect_to workspace_dashboard_path(@workspace), notice: 'Workspace created successfully'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # Edit workspace settings
  end

  def update
    if @workspace.update(workspace_params)
      redirect_to workspace_dashboard_path(@workspace), notice: 'Workspace updated successfully'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def switch
    session[:current_workspace_id] = @workspace.id
    redirect_to workspace_dashboard_path(@workspace), notice: "Switched to #{@workspace.name}"
  end

  private

  def set_workspace
    @workspace = current_user.workspaces.find_by(slug: params[:slug] || params[:workspace_slug])
    redirect_to workspaces_path, alert: 'Workspace not found' unless @workspace
  end

  def workspace_params
    params.require(:workspace).permit(:name, settings: {})
  end
end
```

#### Step 3: Update Application Controller

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Authentication
  include Authorization

  before_action :require_authentication
  before_action :set_current_workspace
end
```

#### Step 4: Create Dashboard Controller

```bash
rails generate controller Dashboard index
```

```ruby
# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  def index
    @brands = current_workspace.brands.active.includes(:visibility_scores)

    # Cache dashboard statistics
    @dashboard_stats = Rails.cache.fetch(
      "workspace:#{current_workspace.id}:dashboard:#{Date.current}",
      expires_in: 15.minutes
    ) do
      calculate_dashboard_stats
    end
  end

  private

  def calculate_dashboard_stats
    {
      total_brands: current_workspace.brands.active.count,
      total_mentions: current_workspace.brands.joins(:mentions)
        .where(mentions: { detected_at: 30.days.ago..Time.current }).count,
      avg_visibility_score: current_workspace.brands.joins(:visibility_scores)
        .where(visibility_scores: { date: Date.current })
        .average('visibility_scores.overall_score')&.round(1) || 0,
      mentions_this_week: current_workspace.brands.joins(:mentions)
        .where(mentions: { detected_at: 1.week.ago..Time.current }).count
    }
  end
end
```

#### Step 5: Update Routes with Workspace Scoping

```ruby
# config/routes.rb
Rails.application.routes.draw do
  require 'sidekiq/web'
  mount Sidekiq::Web => '/sidekiq'

  # Authentication
  get    '/login',  to: 'sessions#new'
  post   '/login',  to: 'sessions#create'
  delete '/logout', to: 'sessions#destroy'

  get  '/signup', to: 'registrations#new'
  post '/signup', to: 'registrations#create'

  get '/confirm/:token', to: 'confirmations#show', as: :confirm_email

  resources :password_resets, only: [:new, :create, :edit, :update]

  # Workspaces
  resources :workspaces, param: :slug, only: [:index, :new, :create, :edit, :update] do
    member do
      post :switch
    end
  end

  # Workspace-scoped routes
  scope ':workspace_slug', as: :workspace do
    get '/', to: 'dashboard#index', as: :dashboard

    resources :brands do
      resources :mentions, only: [:index, :show]
      resources :visibility_scores, only: [:index]
    end

    resources :settings, only: [:index, :update]
    resources :team_members, only: [:index, :create, :destroy]
  end

  # Health check
  get '/health', to: 'health#index'

  # Root redirects to workspaces
  root to: redirect('/workspaces')
end
```

---

### Feature 1.5: Basic Dashboard UI

**Estimated Time:** 6 hours

#### Step 1: Create Application Layout

```erb
<!-- app/views/layouts/application.html.erb -->
<!DOCTYPE html>
<html>
  <head>
    <title>GEO Platform</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= stylesheet_link_tag "tailwind", "inter-font", "data-turbo-track": "reload" %>
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body class="bg-gray-50">
    <% if user_signed_in? %>
      <%= render 'shared/navbar' %>

      <div class="flex">
        <%= render 'shared/sidebar' %>

        <main class="flex-1 p-8">
          <%= render 'shared/flash_messages' %>
          <%= yield %>
        </main>
      </div>
    <% else %>
      <%= render 'shared/flash_messages' %>
      <%= yield %>
    <% end %>
  </body>
</html>
```

#### Step 2: Create Navbar Partial

```erb
<!-- app/views/shared/_navbar.html.erb -->
<nav class="bg-white shadow-sm border-b border-gray-200">
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    <div class="flex justify-between h-16">
      <div class="flex">
        <div class="flex-shrink-0 flex items-center">
          <%= link_to "GEO Platform", workspace_dashboard_path(current_workspace), class: "text-xl font-bold text-indigo-600" %>
        </div>
      </div>

      <div class="flex items-center space-x-4">
        <!-- Workspace Switcher -->
        <div class="relative" data-controller="dropdown">
          <button type="button" class="flex items-center space-x-2 text-sm font-medium text-gray-700 hover:text-gray-900" data-action="click->dropdown#toggle">
            <span><%= current_workspace.name %></span>
            <svg class="h-5 w-5" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd"/>
            </svg>
          </button>

          <div class="hidden absolute right-0 mt-2 w-56 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5" data-dropdown-target="menu">
            <div class="py-1">
              <% current_user.workspaces.each do |workspace| %>
                <%= link_to workspace.name, switch_workspace_path(workspace), method: :post,
                    class: "block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 #{'bg-gray-50' if workspace == current_workspace}" %>
              <% end %>
              <div class="border-t border-gray-100"></div>
              <%= link_to "Create workspace", new_workspace_path, class: "block px-4 py-2 text-sm text-indigo-600 hover:bg-gray-100" %>
            </div>
          </div>
        </div>

        <!-- User Menu -->
        <div class="relative" data-controller="dropdown">
          <button type="button" class="flex items-center space-x-2 text-sm font-medium text-gray-700 hover:text-gray-900" data-action="click->dropdown#toggle">
            <span><%= current_user.first_name %></span>
            <div class="h-8 w-8 rounded-full bg-indigo-600 flex items-center justify-center text-white">
              <%= current_user.first_name[0].upcase %>
            </div>
          </button>

          <div class="hidden absolute right-0 mt-2 w-48 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5" data-dropdown-target="menu">
            <div class="py-1">
              <%= link_to "Settings", workspace_settings_path(current_workspace), class: "block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100" %>
              <%= link_to "Sign out", logout_path, method: :delete, class: "block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100" %>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</nav>
```

#### Step 3: Create Sidebar Partial

```erb
<!-- app/views/shared/_sidebar.html.erb -->
<aside class="w-64 bg-white border-r border-gray-200 min-h-screen">
  <nav class="mt-5 px-2 space-y-1">
    <%= link_to workspace_dashboard_path(current_workspace),
        class: "group flex items-center px-2 py-2 text-sm font-medium rounded-md #{current_page?(workspace_dashboard_path(current_workspace)) ? 'bg-indigo-100 text-indigo-900' : 'text-gray-600 hover:bg-gray-50'}" do %>
      <svg class="mr-3 h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"/>
      </svg>
      Dashboard
    <% end %>

    <%= link_to workspace_brands_path(current_workspace),
        class: "group flex items-center px-2 py-2 text-sm font-medium rounded-md #{current_page?(workspace_brands_path(current_workspace)) ? 'bg-indigo-100 text-indigo-900' : 'text-gray-600 hover:bg-gray-50'}" do %>
      <svg class="mr-3 h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"/>
      </svg>
      Brands
    <% end %>

    <%= link_to workspace_settings_path(current_workspace),
        class: "group flex items-center px-2 py-2 text-sm font-medium rounded-md #{current_page?(workspace_settings_path(current_workspace)) ? 'bg-indigo-100 text-indigo-900' : 'text-gray-600 hover:bg-gray-50'}" do %>
      <svg class="mr-3 h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/>
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
      </svg>
      Settings
    <% end %>
  </nav>
</aside>
```

#### Step 4: Create Dashboard View

```erb
<!-- app/views/dashboard/index.html.erb -->
<div class="space-y-6">
  <div class="flex justify-between items-center">
    <h1 class="text-2xl font-bold text-gray-900">Dashboard</h1>
    <%= link_to "Add Brand", new_workspace_brand_path(current_workspace),
        class: "inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700" %>
  </div>

  <!-- Stats Cards -->
  <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
    <div class="bg-white overflow-hidden shadow rounded-lg">
      <div class="p-5">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"/>
            </svg>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Total Brands</dt>
              <dd class="text-3xl font-semibold text-gray-900"><%= @dashboard_stats[:total_brands] %></dd>
            </dl>
          </div>
        </div>
      </div>
    </div>

    <div class="bg-white overflow-hidden shadow rounded-lg">
      <div class="p-5">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-5l-5 5v-5z"/>
            </svg>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Mentions (30d)</dt>
              <dd class="text-3xl font-semibold text-gray-900"><%= @dashboard_stats[:total_mentions] %></dd>
            </dl>
          </div>
        </div>
      </div>
    </div>

    <div class="bg-white overflow-hidden shadow rounded-lg">
      <div class="p-5">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
            </svg>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Avg Visibility Score</dt>
              <dd class="text-3xl font-semibold text-gray-900"><%= @dashboard_stats[:avg_visibility_score] %></dd>
            </dl>
          </div>
        </div>
      </div>
    </div>

    <div class="bg-white overflow-hidden shadow rounded-lg">
      <div class="p-5">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"/>
            </svg>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">This Week</dt>
              <dd class="text-3xl font-semibold text-gray-900"><%= @dashboard_stats[:mentions_this_week] %></dd>
            </dl>
          </div>
        </div>
      </div>
    </div>
  </div>

  <!-- Brands List -->
  <div class="bg-white shadow overflow-hidden sm:rounded-md">
    <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
      <h3 class="text-lg leading-6 font-medium text-gray-900">Your Brands</h3>
    </div>

    <% if @brands.any? %>
      <ul class="divide-y divide-gray-200">
        <% @brands.each do |brand| %>
          <li>
            <%= link_to workspace_brand_path(current_workspace, brand), class: "block hover:bg-gray-50" do %>
              <div class="px-4 py-4 sm:px-6">
                <div class="flex items-center justify-between">
                  <div class="flex-1">
                    <p class="text-sm font-medium text-indigo-600 truncate"><%= brand.name %></p>
                    <p class="text-sm text-gray-500"><%= brand.domain %></p>
                  </div>
                  <div class="ml-2 flex-shrink-0 flex">
                    <p class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800">
                      Score: <%= brand.current_visibility_score.round %>
                    </p>
                  </div>
                </div>
              </div>
            <% end %>
          </li>
        <% end %>
      </ul>
    <% else %>
      <div class="text-center py-12">
        <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"/>
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">No brands</h3>
        <p class="mt-1 text-sm text-gray-500">Get started by creating a new brand.</p>
        <div class="mt-6">
          <%= link_to "Add Brand", new_workspace_brand_path(current_workspace),
              class: "inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700" %>
        </div>
      </div>
    <% end %>
  </div>
</div>
```

### Feature 1.6: Stimulus Dropdown Controller

**Estimated Time:** 2 hours

#### Step 1: Create Dropdown Controller

```javascript
// app/javascript/controllers/dropdown_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.boundClose = this.close.bind(this)
  }

  toggle(event) {
    event.stopPropagation()

    if (this.menuTarget.classList.contains('hidden')) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.menuTarget.classList.remove('hidden')
    document.addEventListener('click', this.boundClose)
  }

  close() {
    this.menuTarget.classList.add('hidden')
    document.removeEventListener('click', this.boundClose)
  }

  disconnect() {
    document.removeEventListener('click', this.boundClose)
  }
}
```

#### Step 2: Create Flash Messages Partial

```erb
<!-- app/views/shared/_flash_messages.html.erb -->
<% if flash.any? %>
  <div class="fixed top-4 right-4 z-50 space-y-2">
    <% flash.each do |type, message| %>
      <div class="max-w-sm w-full bg-white shadow-lg rounded-lg pointer-events-auto ring-1 ring-black ring-opacity-5 overflow-hidden"
           data-controller="flash"
           data-flash-delay-value="5000">
        <div class="p-4">
          <div class="flex items-start">
            <div class="flex-shrink-0">
              <% if type == 'notice' %>
                <svg class="h-6 w-6 text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
              <% else %>
                <svg class="h-6 w-6 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
              <% end %>
            </div>
            <div class="ml-3 w-0 flex-1 pt-0.5">
              <p class="text-sm font-medium text-gray-900"><%= message %></p>
            </div>
            <div class="ml-4 flex-shrink-0 flex">
              <button type="button"
                      class="bg-white rounded-md inline-flex text-gray-400 hover:text-gray-500"
                      data-action="click->flash#close">
                <span class="sr-only">Close</span>
                <svg class="h-5 w-5" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"/>
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

#### Step 3: Create Flash Stimulus Controller

```javascript
// app/javascript/controllers/flash_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: Number }

  connect() {
    const delay = this.delayValue || 5000
    this.timeout = setTimeout(() => {
      this.close()
    }, delay)
  }

  close() {
    this.element.remove()
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }
}
```

#### Step 4: Create Error Messages Partial

```erb
<!-- app/views/shared/_error_messages.html.erb -->
<% if object.errors.any? %>
  <div class="rounded-md bg-red-50 p-4 mb-4">
    <div class="flex">
      <div class="flex-shrink-0">
        <svg class="h-5 w-5 text-red-400" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
        </svg>
      </div>
      <div class="ml-3">
        <h3 class="text-sm font-medium text-red-800">
          <%= pluralize(object.errors.count, "error") %> prohibited this <%= object.class.name.downcase %> from being saved:
        </h3>
        <div class="mt-2 text-sm text-red-700">
          <ul class="list-disc pl-5 space-y-1">
            <% object.errors.full_messages.each do |message| %>
              <li><%= message %></li>
            <% end %>
          </ul>
        </div>
      </div>
    </div>
  </div>
<% end %>
```

---

## Week 2: Testing & Documentation

### Feature 1.7: Model Tests

**Estimated Time:** 4 hours

```ruby
# spec/models/user_spec.rb
require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should have_many(:workspace_memberships).dependent(:destroy) }
    it { should have_many(:workspaces).through(:workspace_memberships) }
  end

  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should allow_value('user@example.com').for(:email) }
    it { should_not allow_value('invalid').for(:email) }

    context 'password' do
      it { should validate_length_of(:password).is_at_least(8).on(:create) }
    end
  end

  describe 'callbacks' do
    it 'downcases email before save' do
      user = create(:user, email: 'USER@EXAMPLE.COM')
      expect(user.email).to eq('user@example.com')
    end

    it 'generates confirmation token before create' do
      user = build(:user, :unconfirmed)
      user.save
      expect(user.confirmation_token).to be_present
    end
  end

  describe '#confirmed?' do
    it 'returns true when confirmed_at is present' do
      user = create(:user, confirmed_at: Time.current)
      expect(user.confirmed?).to be true
    end

    it 'returns false when confirmed_at is nil' do
      user = build(:user, :unconfirmed)
      expect(user.confirmed?).to be false
    end
  end

  describe '#confirm!' do
    it 'sets confirmed_at and clears confirmation_token' do
      user = create(:user, :unconfirmed)
      user.confirm!

      expect(user.confirmed_at).to be_present
      expect(user.confirmation_token).to be_nil
    end
  end
end

# spec/models/workspace_spec.rb
require 'rails_helper'

RSpec.describe Workspace, type: :model do
  describe 'associations' do
    it { should have_many(:workspace_memberships).dependent(:destroy) }
    it { should have_many(:users).through(:workspace_memberships) }
    it { should have_many(:brands).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:slug) }
    it { should validate_uniqueness_of(:slug) }
  end

  describe 'slug generation' do
    it 'generates slug from name' do
      workspace = create(:workspace, name: 'My Awesome Workspace')
      expect(workspace.slug).to eq('my-awesome-workspace')
    end

    it 'handles duplicate slugs' do
      create(:workspace, name: 'Test')
      workspace2 = create(:workspace, name: 'Test')

      expect(workspace2.slug).to eq('test-1')
    end
  end

  describe '#owner' do
    it 'returns the workspace owner' do
      workspace = create(:workspace)
      owner = create(:user)
      create(:workspace_membership, workspace: workspace, user: owner, role: 'owner')

      expect(workspace.owner).to eq(owner)
    end
  end
end

# spec/models/brand_spec.rb
require 'rails_helper'

RSpec.describe Brand, type: :model do
  describe 'associations' do
    it { should belong_to(:workspace) }
    it { should have_many(:mentions).dependent(:destroy) }
    it { should have_many(:visibility_scores).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }

    it 'validates uniqueness of name scoped to workspace' do
      workspace = create(:workspace)
      create(:brand, workspace: workspace, name: 'Test Brand')

      duplicate = build(:brand, workspace: workspace, name: 'Test Brand')
      expect(duplicate).not_to be_valid
    end
  end

  describe 'scopes' do
    let!(:active_brand) { create(:brand, active: true) }
    let!(:inactive_brand) { create(:brand, active: false) }

    it 'returns only active brands' do
      expect(Brand.active).to include(active_brand)
      expect(Brand.active).not_to include(inactive_brand)
    end
  end
end
```

### Feature 1.8: Controller Tests

**Estimated Time:** 4 hours

```ruby
# spec/requests/sessions_spec.rb
require 'rails_helper'

RSpec.describe "Sessions", type: :request do
  describe "GET /login" do
    it "renders the login page" do
      get login_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /login" do
    let(:user) { create(:user, email: 'user@example.com', password: 'password123') }

    context "with valid credentials" do
      it "signs in the user" do
        post login_path, params: { email: user.email, password: 'password123' }

        expect(session[:user_id]).to eq(user.id)
        expect(response).to redirect_to(root_path)
      end
    end

    context "with invalid credentials" do
      it "does not sign in the user" do
        post login_path, params: { email: user.email, password: 'wrong' }

        expect(session[:user_id]).to be_nil
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with unconfirmed user" do
      let(:unconfirmed_user) { create(:user, :unconfirmed, password: 'password123') }

      it "does not sign in the user" do
        post login_path, params: { email: unconfirmed_user.email, password: 'password123' }

        expect(session[:user_id]).to be_nil
        expect(response).to redirect_to(login_path)
      end
    end
  end

  describe "DELETE /logout" do
    let(:user) { create(:user) }

    before { sign_in user }

    it "signs out the user" do
      delete logout_path

      expect(session[:user_id]).to be_nil
      expect(response).to redirect_to(root_path)
    end
  end
end

# spec/requests/registrations_spec.rb
require 'rails_helper'

RSpec.describe "Registrations", type: :request do
  describe "POST /signup" do
    let(:valid_params) do
      {
        user: {
          email: 'newuser@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          first_name: 'John',
          last_name: 'Doe'
        }
      }
    end

    it "creates a new user" do
      expect {
        post signup_path, params: valid_params
      }.to change(User, :count).by(1)
    end

    it "creates a default workspace" do
      expect {
        post signup_path, params: valid_params
      }.to change(Workspace, :count).by(1)
    end

    it "creates workspace membership with owner role" do
      post signup_path, params: valid_params

      user = User.last
      workspace = Workspace.last
      membership = WorkspaceMembership.find_by(user: user, workspace: workspace)

      expect(membership.role).to eq('owner')
    end
  end
end

# spec/support/authentication_helper.rb
module AuthenticationHelper
  def sign_in(user)
    post login_path, params: { email: user.email, password: user.password }
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelper, type: :request
end
```

---

## Phase 1 Completion Checklist

### Week 1
- [ ] Rails application initialized
- [ ] All gems installed and configured
- [ ] PostgreSQL database created with extensions
- [ ] Redis and Sidekiq configured
- [ ] User model created with authentication
- [ ] Workspace model created with multi-tenancy
- [ ] WorkspaceMembership model created with roles
- [ ] Brand model created
- [ ] All migrations run successfully
- [ ] Factory definitions created

### Week 2
- [ ] Authentication system implemented (login, signup, logout)
- [ ] Password reset functionality
- [ ] Email confirmation (structure in place)
- [ ] Multi-tenancy with workspace scoping
- [ ] Workspace switcher
- [ ] Basic dashboard UI with Tailwind
- [ ] Navbar and sidebar navigation
- [ ] Flash messages with Stimulus
- [ ] Model tests written (>80% coverage)
- [ ] Controller tests written (>80% coverage)

---

## Next Steps

After completing Phase 1, you should have:

✅ **A fully functional Rails application** with authentication and multi-tenancy
✅ **Core database models** for users, workspaces, and brands
✅ **Beautiful UI** built with Tailwind CSS
✅ **Comprehensive test suite** with RSpec
✅ **Development environment** ready for Phase 2

**Ready for Phase 2: Monitoring Infrastructure** 🚀

In Phase 2, you'll build:
- AI platform integration (ChatGPT, Claude, Perplexity)
- Mention detection service
- Background job infrastructure with Sidekiq
- Real-time monitoring dashboard
- Alert system

---

**END OF PHASE 1 DOCUMENT**


