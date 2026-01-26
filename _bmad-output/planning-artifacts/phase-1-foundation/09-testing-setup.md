# Task 09: Testing Setup & Model Tests

## Overview
**Estimated Time:** 8 hours  
**Priority:** High  
**Dependencies:** Tasks 01-08 (Models, Database, Authentication)

## Objective
Establish a comprehensive testing infrastructure with RSpec, FactoryBot, and supporting gems to ensure code quality, maintainability, and >90% test coverage across the application.

## Testing Stack

### Core Testing Gems
```ruby
# Gemfile - Testing group
group :development, :test do
  gem 'rspec-rails', '~> 6.1'
  gem 'factory_bot_rails', '~> 6.4'
  gem 'faker', '~> 3.2'
  gem 'pry-byebug', '~> 3.10'
  gem 'pry-rails', '~> 0.3'
end

group :test do
  gem 'shoulda-matchers', '~> 6.0'
  gem 'database_cleaner-active_record', '~> 2.1'
  gem 'simplecov', '~> 0.22', require: false
  gem 'vcr', '~> 6.2'
  gem 'webmock', '~> 3.19'
  gem 'rspec-sidekiq', '~> 4.0'
  gem 'timecop', '~> 0.9'
end
```

## Step 1: Initial RSpec Setup

### 1.1 Install RSpec
```bash
# Install RSpec and generate configuration
bundle install
rails generate rspec:install

# This creates:
# - spec/spec_helper.rb
# - spec/rails_helper.rb
# - .rspec
```

### 1.2 Configure .rspec
```
# .rspec
--require spec_helper
--format documentation
--color
--order random
```

## Step 2: Configure spec/spec_helper.rb

### 2.1 Complete spec_helper.rb Configuration
```ruby
# spec/spec_helper.rb
require 'simplecov'
SimpleCov.start 'rails' do
  add_filter '/bin/'
  add_filter '/db/'
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/vendor/'
  
  add_group 'Models', 'app/models'
  add_group 'Controllers', 'app/controllers'
  add_group 'Services', 'app/services'
  add_group 'Jobs', 'app/jobs'
  add_group 'Mailers', 'app/mailers'
  add_group 'Helpers', 'app/helpers'
  
  minimum_coverage 90
  minimum_coverage_by_file 80
end

RSpec.configure do |config|
  # Expectations configuration
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    expectations.syntax = :expect
  end

  # Mocks configuration
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  # Shared context configuration
  config.shared_context_metadata_behavior = :apply_to_host_groups
  
  # Run specs in random order
  config.order = :random
  Kernel.srand config.seed
  
  # Filter lines from Rails gems in backtraces
  config.filter_rails_from_backtrace!
  
  # Allow focusing on specific tests
  config.filter_run_when_matching :focus
  
  # Disable monkey patching
  config.disable_monkey_patching!
  
  # Profile slowest examples
  config.profile_examples = 10
  
  # Output warnings
  config.warnings = true
end
```

## Step 3: Configure spec/rails_helper.rb

### 3.1 Complete rails_helper.rb Configuration
```ruby
# spec/rails_helper.rb
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'

# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?

require 'rspec/rails'
require 'shoulda/matchers'
require 'database_cleaner/active_record'
require 'vcr'
require 'webmock/rspec'

# Load support files
Dir[Rails.root.join('spec/support/**/*.rb')].sort.each { |f| require f }

# Maintain test schema
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # Use transactional fixtures (set to false when using Database Cleaner)
  config.use_transactional_fixtures = false

  # Infer spec type from file location
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces
  config.filter_rails_from_backtrace!

  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods
  
  # Include custom helpers
  config.include RequestSpecHelper, type: :request
  config.include AuthenticationHelper, type: :request
  config.include JsonHelper, type: :request

  # Database Cleaner configuration
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.strategy = :transaction
  end

  config.before(:each, js: true) do
    DatabaseCleaner.strategy = :truncation
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

  # Devise test helpers
  config.include Devise::Test::IntegrationHelpers, type: :request
end

# Shoulda Matchers Configuration
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

# VCR Configuration
VCR.configure do |config|
  config.cassette_library_dir = 'spec/vcr_cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.ignore_localhost = true
  config.default_cassette_options = {
    record: :once,
    match_requests_on: [:method, :uri, :body]
  }

  # Filter sensitive data
  config.filter_sensitive_data('<OPENAI_API_KEY>') { ENV['OPENAI_API_KEY'] }
  config.filter_sensitive_data('<ANTHROPIC_API_KEY>') { ENV['ANTHROPIC_API_KEY'] }
  config.filter_sensitive_data('<STRIPE_API_KEY>') { ENV['STRIPE_API_KEY'] }
end
```

## Step 4: Support Files Configuration

### 4.1 Database Cleaner Support
```ruby
# spec/support/database_cleaner.rb
RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
    DatabaseCleaner.strategy = :transaction
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end
```

### 4.2 FactoryBot Support
```ruby
# spec/support/factory_bot.rb
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  # Lint factories in development
  config.before(:suite) do
    if Rails.env.development?
      FactoryBot.lint(traits: true, verbose: true)
    end
  end
end
```

### 4.3 Shoulda Matchers Support
```ruby
# spec/support/shoulda_matchers.rb
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
```

### 4.4 Request Spec Helper
```ruby
# spec/support/request_spec_helper.rb
module RequestSpecHelper
  # Parse JSON response to ruby hash
  def json
    JSON.parse(response.body, symbolize_names: true)
  end

  # Return JSON headers
  def json_headers
    {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end

  # Return authenticated headers
  def authenticated_headers(user)
    token = JsonWebToken.encode(user_id: user.id)
    json_headers.merge('Authorization' => "Bearer #{token}")
  end
end
```

### 4.5 Authentication Helper
```ruby
# spec/support/authentication_helper.rb
module AuthenticationHelper
  # Generate JWT token for user
  def token_for(user)
    JsonWebToken.encode(user_id: user.id)
  end

  # Sign in user and return token
  def sign_in(user)
    token = token_for(user)
    { 'Authorization' => "Bearer #{token}" }
  end

  # Create and sign in user
  def create_and_sign_in_user(attributes = {})
    user = create(:user, attributes)
    [user, sign_in(user)]
  end
end
```

### 4.6 JSON Helper
```ruby
# spec/support/json_helper.rb
module JsonHelper
  def json_response
    @json_response ||= JSON.parse(response.body, symbolize_names: true)
  end

  def json_data
    json_response[:data]
  end

  def json_errors
    json_response[:errors]
  end

  def json_meta
    json_response[:meta]
  end
end
```

## Step 5: Factory Definitions

### 5.1 User Factory
```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    email { Faker::Internet.unique.email }
    password { 'Password123!' }
    password_confirmation { 'Password123!' }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    confirmed_at { Time.current }

    trait :unconfirmed do
      confirmed_at { nil }
    end

    trait :admin do
      role { :admin }
    end

    trait :with_workspaces do
      transient do
        workspaces_count { 2 }
      end

      after(:create) do |user, evaluator|
        create_list(:workspace_membership, evaluator.workspaces_count,
                    user: user, role: :owner)
      end
    end

    trait :suspended do
      suspended_at { Time.current }
    end
  end
end
```

### 5.2 Workspace Factory
```ruby
# spec/factories/workspaces.rb
FactoryBot.define do
  factory :workspace do
    name { Faker::Company.name }
    slug { Faker::Internet.unique.slug }

    trait :with_owner do
      after(:create) do |workspace|
        create(:workspace_membership, workspace: workspace, role: :owner)
      end
    end

    trait :with_members do
      transient do
        members_count { 3 }
      end

      after(:create) do |workspace, evaluator|
        create(:workspace_membership, workspace: workspace, role: :owner)
        create_list(:workspace_membership, evaluator.members_count - 1,
                    workspace: workspace, role: :member)
      end
    end

    trait :with_brands do
      transient do
        brands_count { 2 }
      end

      after(:create) do |workspace, evaluator|
        create_list(:brand, evaluator.brands_count, workspace: workspace)
      end
    end
  end
end
```

### 5.3 WorkspaceMembership Factory
```ruby
# spec/factories/workspace_memberships.rb
FactoryBot.define do
  factory :workspace_membership do
    association :user
    association :workspace
    role { :member }

    trait :owner do
      role { :owner }
    end

    trait :admin do
      role { :admin }
    end

    trait :member do
      role { :member }
    end

    trait :viewer do
      role { :viewer }
    end
  end
end
```

### 5.4 Brand Factory
```ruby
# spec/factories/brands.rb
FactoryBot.define do
  factory :brand do
    association :workspace
    name { Faker::Company.name }
    description { Faker::Company.catch_phrase }

    trait :with_guidelines do
      tone_of_voice { 'Professional and friendly' }
      target_audience { 'Tech-savvy professionals aged 25-45' }
      key_messages { ['Innovation', 'Quality', 'Trust'] }
    end

    trait :with_assets do
      logo_url { Faker::Internet.url }
      primary_color { Faker::Color.hex_color }
      secondary_color { Faker::Color.hex_color }
    end
  end
end
```

## Step 6: Model Tests

### 6.1 User Model Test
```ruby
# spec/models/user_spec.rb
require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should have_many(:workspace_memberships).dependent(:destroy) }
    it { should have_many(:workspaces).through(:workspace_memberships) }
    it { should have_many(:owned_workspaces).through(:workspace_memberships) }
  end

  describe 'validations' do
    subject { build(:user) }

    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
    it { should allow_value('user@example.com').for(:email) }
    it { should_not allow_value('invalid_email').for(:email) }
  end

  describe 'enums' do
    it { should define_enum_for(:role).with_values(user: 0, admin: 1) }
  end

  describe 'callbacks' do
    describe 'before_save' do
      it 'downcases email' do
        user = create(:user, email: 'USER@EXAMPLE.COM')
        expect(user.email).to eq('user@example.com')
      end
    end
  end

  describe '#full_name' do
    it 'returns first and last name combined' do
      user = build(:user, first_name: 'John', last_name: 'Doe')
      expect(user.full_name).to eq('John Doe')
    end
  end

  describe '#active_for_authentication?' do
    context 'when user is not suspended' do
      it 'returns true' do
        user = build(:user)
        expect(user.active_for_authentication?).to be true
      end
    end

    context 'when user is suspended' do
      it 'returns false' do
        user = build(:user, :suspended)
        expect(user.active_for_authentication?).to be false
      end
    end
  end

  describe '#workspace_role' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace) }

    context 'when user is a member' do
      before do
        create(:workspace_membership, user: user, workspace: workspace, role: :admin)
      end

      it 'returns the role' do
        expect(user.workspace_role(workspace)).to eq('admin')
      end
    end

    context 'when user is not a member' do
      it 'returns nil' do
        expect(user.workspace_role(workspace)).to be_nil
      end
    end
  end

  describe 'scopes' do
    describe '.confirmed' do
      let!(:confirmed_user) { create(:user) }
      let!(:unconfirmed_user) { create(:user, :unconfirmed) }

      it 'returns only confirmed users' do
        expect(User.confirmed).to include(confirmed_user)
        expect(User.confirmed).not_to include(unconfirmed_user)
      end
    end

    describe '.active' do
      let!(:active_user) { create(:user) }
      let!(:suspended_user) { create(:user, :suspended) }

      it 'returns only active users' do
        expect(User.active).to include(active_user)
        expect(User.active).not_to include(suspended_user)
      end
    end
  end
end
```

### 6.2 Workspace Model Test
```ruby
# spec/models/workspace_spec.rb
require 'rails_helper'

RSpec.describe Workspace, type: :model do
  describe 'associations' do
    it { should have_many(:workspace_memberships).dependent(:destroy) }
    it { should have_many(:users).through(:workspace_memberships) }
    it { should have_many(:brands).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:workspace) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:slug) }
    it { should validate_uniqueness_of(:slug).case_insensitive }
    it { should validate_length_of(:name).is_at_least(2).is_at_most(100) }
    it { should validate_length_of(:slug).is_at_least(2).is_at_most(50) }
  end

  describe 'callbacks' do
    describe 'before_validation' do
      context 'when slug is not set' do
        it 'generates slug from name' do
          workspace = build(:workspace, name: 'My Awesome Workspace', slug: nil)
          workspace.valid?
          expect(workspace.slug).to eq('my-awesome-workspace')
        end
      end

      context 'when slug is already set' do
        it 'does not override slug' do
          workspace = build(:workspace, name: 'My Workspace', slug: 'custom-slug')
          workspace.valid?
          expect(workspace.slug).to eq('custom-slug')
        end
      end
    end
  end

  describe '#owner' do
    let(:workspace) { create(:workspace) }
    let(:owner) { create(:user) }

    before do
      create(:workspace_membership, workspace: workspace, user: owner, role: :owner)
    end

    it 'returns the workspace owner' do
      expect(workspace.owner).to eq(owner)
    end
  end

  describe '#add_member' do
    let(:workspace) { create(:workspace) }
    let(:user) { create(:user) }

    it 'adds a member to the workspace' do
      expect {
        workspace.add_member(user, role: :member)
      }.to change(workspace.workspace_memberships, :count).by(1)
    end

    it 'sets the correct role' do
      workspace.add_member(user, role: :admin)
      membership = workspace.workspace_memberships.find_by(user: user)
      expect(membership.role).to eq('admin')
    end
  end

  describe '#remove_member' do
    let(:workspace) { create(:workspace) }
    let(:user) { create(:user) }

    before do
      create(:workspace_membership, workspace: workspace, user: user)
    end

    it 'removes a member from the workspace' do
      expect {
        workspace.remove_member(user)
      }.to change(workspace.workspace_memberships, :count).by(-1)
    end
  end

  describe 'scopes' do
    describe '.active' do
      let!(:active_workspace) { create(:workspace) }
      let!(:archived_workspace) { create(:workspace, archived_at: Time.current) }

      it 'returns only active workspaces' do
        expect(Workspace.active).to include(active_workspace)
        expect(Workspace.active).not_to include(archived_workspace)
      end
    end
  end
end
```

### 6.3 WorkspaceMembership Model Test
```ruby
# spec/models/workspace_membership_spec.rb
require 'rails_helper'

RSpec.describe WorkspaceMembership, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:workspace) }
  end

  describe 'validations' do
    subject { build(:workspace_membership) }

    it { should validate_presence_of(:role) }
    it { should validate_uniqueness_of(:user_id).scoped_to(:workspace_id) }
  end

  describe 'enums' do
    it do
      should define_enum_for(:role)
        .with_values(viewer: 0, member: 1, admin: 2, owner: 3)
    end
  end

  describe 'scopes' do
    let(:workspace) { create(:workspace) }

    describe '.owners' do
      let!(:owner_membership) { create(:workspace_membership, :owner, workspace: workspace) }
      let!(:member_membership) { create(:workspace_membership, :member, workspace: workspace) }

      it 'returns only owner memberships' do
        expect(WorkspaceMembership.owners).to include(owner_membership)
        expect(WorkspaceMembership.owners).not_to include(member_membership)
      end
    end

    describe '.admins' do
      let!(:admin_membership) { create(:workspace_membership, :admin, workspace: workspace) }
      let!(:member_membership) { create(:workspace_membership, :member, workspace: workspace) }

      it 'returns only admin memberships' do
        expect(WorkspaceMembership.admins).to include(admin_membership)
        expect(WorkspaceMembership.admins).not_to include(member_membership)
      end
    end
  end

  describe '#can_manage_workspace?' do
    context 'when role is owner' do
      it 'returns true' do
        membership = build(:workspace_membership, :owner)
        expect(membership.can_manage_workspace?).to be true
      end
    end

    context 'when role is admin' do
      it 'returns true' do
        membership = build(:workspace_membership, :admin)
        expect(membership.can_manage_workspace?).to be true
      end
    end

    context 'when role is member' do
      it 'returns false' do
        membership = build(:workspace_membership, :member)
        expect(membership.can_manage_workspace?).to be false
      end
    end
  end

  describe '#can_invite_members?' do
    context 'when role is owner or admin' do
      it 'returns true for owner' do
        membership = build(:workspace_membership, :owner)
        expect(membership.can_invite_members?).to be true
      end

      it 'returns true for admin' do
        membership = build(:workspace_membership, :admin)
        expect(membership.can_invite_members?).to be true
      end
    end

    context 'when role is member or viewer' do
      it 'returns false for member' do
        membership = build(:workspace_membership, :member)
        expect(membership.can_invite_members?).to be false
      end

      it 'returns false for viewer' do
        membership = build(:workspace_membership, :viewer)
        expect(membership.can_invite_members?).to be false
      end
    end
  end
end
```

### 6.4 Brand Model Test
```ruby
# spec/models/brand_spec.rb
require 'rails_helper'

RSpec.describe Brand, type: :model do
  describe 'associations' do
    it { should belong_to(:workspace) }
  end

  describe 'validations' do
    subject { build(:brand) }

    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_least(2).is_at_most(100) }
    it { should validate_length_of(:description).is_at_most(500) }
  end

  describe 'callbacks' do
    describe 'before_save' do
      it 'normalizes name' do
        brand = create(:brand, name: '  My Brand  ')
        expect(brand.name).to eq('My Brand')
      end
    end
  end

  describe '#complete?' do
    context 'when all required fields are present' do
      it 'returns true' do
        brand = build(:brand, :with_guidelines, :with_assets)
        expect(brand.complete?).to be true
      end
    end

    context 'when required fields are missing' do
      it 'returns false' do
        brand = build(:brand)
        expect(brand.complete?).to be false
      end
    end
  end

  describe 'scopes' do
    describe '.complete' do
      let!(:complete_brand) { create(:brand, :with_guidelines, :with_assets) }
      let!(:incomplete_brand) { create(:brand) }

      it 'returns only complete brands' do
        expect(Brand.complete).to include(complete_brand)
        expect(Brand.complete).not_to include(incomplete_brand)
      end
    end
  end
end
```

## Step 7: Test Helpers

### 7.1 Shared Examples
```ruby
# spec/support/shared_examples/api_authentication.rb
RSpec.shared_examples 'requires authentication' do
  context 'when not authenticated' do
    it 'returns 401 unauthorized' do
      subject
      expect(response).to have_http_status(:unauthorized)
    end
  end
end

RSpec.shared_examples 'requires workspace membership' do
  context 'when user is not a workspace member' do
    it 'returns 403 forbidden' do
      subject
      expect(response).to have_http_status(:forbidden)
    end
  end
end

RSpec.shared_examples 'requires admin role' do
  context 'when user is not an admin' do
    it 'returns 403 forbidden' do
      subject
      expect(response).to have_http_status(:forbidden)
    end
  end
end
```

### 7.2 Custom Matchers
```ruby
# spec/support/matchers/json_matchers.rb
RSpec::Matchers.define :have_json_key do |expected|
  match do |actual|
    json = JSON.parse(actual.body, symbolize_names: true)
    json.key?(expected)
  end

  failure_message do |actual|
    "expected JSON to have key #{expected}, but it didn't"
  end
end

RSpec::Matchers.define :have_json_value do |key, value|
  match do |actual|
    json = JSON.parse(actual.body, symbolize_names: true)
    json[key] == value
  end

  failure_message do |actual|
    json = JSON.parse(actual.body, symbolize_names: true)
    "expected JSON[#{key}] to be #{value}, but was #{json[key]}"
  end
end
```

## Step 8: Running Tests

### 8.1 Run All Tests
```bash
# Run all tests
bundle exec rspec

# Run with coverage
COVERAGE=true bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/user_spec.rb

# Run specific test
bundle exec rspec spec/models/user_spec.rb:10

# Run tests matching pattern
bundle exec rspec spec/models/

# Run with documentation format
bundle exec rspec --format documentation
```

### 8.2 Parallel Testing (Optional)
```ruby
# Gemfile
group :test do
  gem 'parallel_tests'
end
```

```bash
# Setup parallel test databases
bundle exec rake parallel:create
bundle exec rake parallel:prepare

# Run tests in parallel
bundle exec parallel_rspec spec/
```

## Step 9: CI/CD Configuration

### 9.1 GitHub Actions Configuration
```yaml
# .github/workflows/test.yml
name: Test Suite

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: aeo_test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

      redis:
        image: redis:7
        ports:
          - 6379:6379
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v3

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.2.2
          bundler-cache: true

      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y postgresql-client
          bundle install --jobs 4 --retry 3

      - name: Setup database
        env:
          RAILS_ENV: test
          DATABASE_URL: postgres://postgres:postgres@localhost:5432/aeo_test
        run: |
          bundle exec rails db:create
          bundle exec rails db:schema:load

      - name: Run tests
        env:
          RAILS_ENV: test
          DATABASE_URL: postgres://postgres:postgres@localhost:5432/aeo_test
          REDIS_URL: redis://localhost:6379/0
        run: |
          bundle exec rspec --format progress --format RspecJunitFormatter --out tmp/rspec.xml

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/.resultset.json
          flags: unittests
          name: codecov-umbrella

      - name: Archive test results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: tmp/rspec.xml
```

## Step 10: Testing Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      Testing Architecture                        │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                         Test Suite                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │    Model     │  │  Controller  │  │   Request    │         │
│  │    Tests     │  │    Tests     │  │    Tests     │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   Service    │  │     Job      │  │    Mailer    │         │
│  │    Tests     │  │    Tests     │  │    Tests     │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Testing Tools                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │    RSpec     │  │ FactoryBot   │  │   Shoulda    │         │
│  │  (Framework) │  │  (Fixtures)  │  │  (Matchers)  │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │  SimpleCov   │  │   Database   │  │     VCR      │         │
│  │  (Coverage)  │  │   Cleaner    │  │  (Mocking)   │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Test Database                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              PostgreSQL Test Database                     │  │
│  │  - Isolated from development                              │  │
│  │  - Cleaned between tests                                  │  │
│  │  - Seeded with factories                                  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    CI/CD Pipeline                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  GitHub Actions → Run Tests → Coverage Report → Deploy          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Success Criteria

### ✅ Configuration Complete
- [ ] RSpec installed and configured
- [ ] FactoryBot setup with factories for all models
- [ ] Shoulda Matchers configured
- [ ] SimpleCov configured with >90% target
- [ ] Database Cleaner setup
- [ ] VCR and WebMock configured
- [ ] All support files created

### ✅ Model Tests Complete
- [ ] User model tests (validations, associations, methods)
- [ ] Workspace model tests
- [ ] WorkspaceMembership model tests
- [ ] Brand model tests
- [ ] All tests passing
- [ ] Code coverage >90%

### ✅ Test Infrastructure
- [ ] Custom helpers created
- [ ] Shared examples defined
- [ ] Custom matchers implemented
- [ ] Test database configured
- [ ] CI/CD pipeline configured

### ✅ Documentation
- [ ] Testing guidelines documented
- [ ] Factory usage examples
- [ ] Test running instructions
- [ ] CI/CD setup documented

## Code Coverage Requirements

### Minimum Coverage Targets
- **Overall Coverage:** 90%
- **Per-File Coverage:** 80%
- **Models:** 95%
- **Controllers:** 85%
- **Services:** 90%
- **Jobs:** 85%

### Coverage Report
```bash
# Generate coverage report
COVERAGE=true bundle exec rspec

# View coverage report
open coverage/index.html
```

## Troubleshooting

### Common Issues

#### 1. Database Connection Errors
```bash
# Reset test database
RAILS_ENV=test bundle exec rails db:drop db:create db:schema:load
```

#### 2. Factory Validation Errors
```bash
# Lint factories to find issues
bundle exec rake factory_bot:lint
```

#### 3. Flaky Tests
```ruby
# Use Timecop for time-dependent tests
Timecop.freeze(Time.zone.local(2024, 1, 1, 12, 0, 0)) do
  # Your test code
end
```

#### 4. Slow Tests
```bash
# Profile slow tests
bundle exec rspec --profile 10

# Run specific slow test
bundle exec rspec spec/slow_spec.rb --format documentation
```

#### 5. VCR Cassette Issues
```bash
# Delete and re-record cassettes
rm -rf spec/vcr_cassettes
bundle exec rspec
```

### Performance Optimization

#### 1. Use build instead of create
```ruby
# Faster - doesn't hit database
user = build(:user)

# Slower - hits database
user = create(:user)
```

#### 2. Use build_stubbed for read-only tests
```ruby
# Fastest - doesn't hit database, returns stubbed object
user = build_stubbed(:user)
```

#### 3. Avoid unnecessary associations
```ruby
# Only create what you need
user = create(:user)  # Don't use :with_workspaces unless needed
```

## Best Practices

### 1. Test Organization
- One test file per model/controller/service
- Group related tests with `describe` and `context`
- Use descriptive test names
- Follow AAA pattern (Arrange, Act, Assert)

### 2. Factory Usage
- Use traits for variations
- Keep factories simple
- Use sequences for unique values
- Avoid callbacks when possible

### 3. Test Data
- Use factories, not fixtures
- Create minimal data needed
- Clean up after tests
- Use realistic but fake data

### 4. Assertions
- One assertion per test (when possible)
- Use specific matchers
- Test behavior, not implementation
- Avoid testing Rails internals

### 5. Mocking and Stubbing
- Mock external services
- Stub time-dependent code
- Use VCR for HTTP requests
- Don't over-mock

## Next Steps

After completing this task:

1. **Run Full Test Suite**
   ```bash
   bundle exec rspec
   ```

2. **Check Coverage**
   ```bash
   open coverage/index.html
   ```

3. **Proceed to Task 10:** Controller Tests & Request Specs

4. **Set up CI/CD:** Configure GitHub Actions for automated testing

## Estimated Timeline

- **Hour 1-2:** Install and configure testing gems
- **Hour 3-4:** Create support files and helpers
- **Hour 5-6:** Write factory definitions
- **Hour 6-7:** Write model tests
- **Hour 7-8:** CI/CD setup and documentation

## Resources

- [RSpec Documentation](https://rspec.info/)
- [FactoryBot Guide](https://github.com/thoughtbot/factory_bot)
- [Shoulda Matchers](https://github.com/thoughtbot/shoulda-matchers)
- [SimpleCov](https://github.com/simplecov-ruby/simplecov)
- [Better Specs](https://www.betterspecs.org/)

---

**Status:** Ready for Implementation
**Last Updated:** 2024-01-23

