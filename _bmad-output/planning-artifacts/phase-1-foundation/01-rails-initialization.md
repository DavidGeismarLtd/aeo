# Task: Rails Application Initialization

## Overview
**Estimated Time:** 4 hours  
**Difficulty:** Beginner-Friendly  
**Phase:** Foundation (Phase 1)

This task covers the complete initialization of a new Rails 7 application with modern tooling, authentication via Devise, PostgreSQL database, background jobs with Sidekiq, and a comprehensive testing setup.

## What You'll Accomplish
- Create a new Rails 7 application
- Configure PostgreSQL as the database
- Set up Devise for user authentication
- Install and configure Sidekiq for background jobs
- Set up Tailwind CSS for styling
- Configure Turbo and Stimulus for modern JavaScript
- Install comprehensive testing framework (RSpec)
- Configure development tools and environment variables

## Prerequisites
- Ruby 3.2+ installed
- PostgreSQL installed and running
- Redis installed and running
- Node.js and Yarn installed
- Basic command line knowledge

## Step-by-Step Instructions

### Step 1: Create New Rails Application (15 minutes)

```bash
# Create new Rails app with PostgreSQL and modern frontend
rails new aeo \
  --database=postgresql \
  --css=tailwind \
  --javascript=esbuild \
  --skip-test \
  -T

# Navigate into the project
cd aeo
```

**What this does:**
- `--database=postgresql`: Sets PostgreSQL as the database
- `--css=tailwind`: Installs Tailwind CSS
- `--javascript=esbuild`: Uses esbuild for JavaScript bundling
- `--skip-test` / `-T`: Skips default Test::Unit (we'll use RSpec)

### Step 2: Configure Gemfile (20 minutes)

Replace the contents of your `Gemfile` with the following:

```ruby
source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.2.2"

# Core Rails gems
gem "rails", "~> 7.1.0"
gem "sprockets-rails"
gem "pg", "~> 1.5"
gem "puma", "~> 6.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "tailwindcss-rails"
gem "jbuilder"
gem "redis", "~> 5.0"
gem "kredis"

# Authentication
gem "devise", "~> 4.9"

# Multi-tenancy
gem "acts_as_tenant", "~> 1.0"

# Background Jobs
gem "sidekiq", "~> 7.1"

# Use Active Model has_secure_password
# gem "bcrypt", "~> 3.1.7"  # NOT NEEDED - Using Devise instead

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ mingw mswin x64_mingw jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Active Storage variants
gem "image_processing", "~> 1.2"

group :development, :test do
  # Debugging
  gem "debug", platforms: %i[ mri mingw x64_mingw ]
  
  # Testing framework
  gem "rspec-rails", "~> 6.0"
  gem "factory_bot_rails", "~> 6.2"
  gem "faker", "~> 3.2"
  
  # Environment variables
  gem "dotenv-rails", "~> 2.8"
end

group :development do
  gem "web-console"
  
  # Development tools
  gem "annotate", "~> 3.2"
  gem "bullet", "~> 7.1"
  gem "letter_opener", "~> 1.8"
  
  # Code quality
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "shoulda-matchers", "~> 5.3"
  gem "vcr", "~> 6.2"
  gem "webmock", "~> 3.19"
  gem "simplecov", require: false
end
```

### Step 3: Install Dependencies (10 minutes)

```bash
# Install all gems
bundle install

# Install JavaScript dependencies
yarn install
```

**Expected output:** All gems should install successfully. If you encounter errors, see the Troubleshooting section.

### Step 4: Configure Database (15 minutes)

Edit `config/database.yml`:

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  username: <%= ENV.fetch("POSTGRES_USER", "postgres") %>
  password: <%= ENV.fetch("POSTGRES_PASSWORD", "") %>
  host: <%= ENV.fetch("POSTGRES_HOST", "localhost") %>

development:
  <<: *default
  database: aeo_development

test:
  <<: *default
  database: aeo_test

production:
  <<: *default
  database: aeo_production
  username: aeo
  password: <%= ENV["AEO_DATABASE_PASSWORD"] %>
```

### Step 5: Set Up Environment Variables (10 minutes)

Create `.env` file in the project root:

```bash
# Database Configuration
POSTGRES_USER=postgres
POSTGRES_PASSWORD=
POSTGRES_HOST=localhost

# Redis Configuration
REDIS_URL=redis://localhost:6379/0

# Rails Configuration
RAILS_ENV=development
RAILS_MAX_THREADS=5

# Devise Secret Key (generate with: rails secret)
DEVISE_SECRET_KEY=your_devise_secret_key_here

# Application Settings
APP_HOST=localhost:3000
```

**Important:** Add `.env` to your `.gitignore`:

```bash
echo ".env" >> .gitignore
```

### Step 6: Create Database (5 minutes)

```bash
# Create development and test databases
rails db:create

# Expected output:
# Created database 'aeo_development'
# Created database 'aeo_test'
```

### Step 7: Configure Application Settings (15 minutes)

Edit `config/application.rb` and add the following inside the `class Application < Rails::Application` block:

```ruby
module Aeo
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Configuration for the application, engines, and railties goes here.
    config.autoload_lib(ignore: %w(assets tasks))

    # Don't generate system test files.
    config.generators.system_tests = nil

    # Configure generators
    config.generators do |g|
      g.test_framework :rspec,
        fixtures: false,
        view_specs: false,
        helper_specs: false,
        routing_specs: false,
        request_specs: true,
        controller_specs: false
      g.fixture_replacement :factory_bot, dir: "spec/factories"
    end

    # Active Job configuration for Sidekiq
    config.active_job.queue_adapter = :sidekiq

    # Time zone configuration
    config.time_zone = "UTC"
    config.active_record.default_timezone = :utc

    # Locale configuration
    config.i18n.default_locale = :en
    config.i18n.available_locales = [:en]
  end
end
```

### Step 8: Install and Configure Devise (30 minutes)

```bash
# Install Devise
rails generate devise:install

# Generate User model with Devise
rails generate devise User

# Generate Devise views (for customization)
rails generate devise:views

# Run migrations
rails db:migrate
```

**Configure Devise:** Edit `config/initializers/devise.rb` and update these key settings:

```ruby
Devise.setup do |config|
  # Secret key for Devise (use environment variable in production)
  config.secret_key = ENV.fetch("DEVISE_SECRET_KEY") { Rails.application.credentials.secret_key_base }

  # Mailer sender
  config.mailer_sender = 'noreply@aeo.com'

  # Configure password length
  config.password_length = 8..128

  # Email confirmation
  config.reconfirmable = true

  # Timeout configuration
  config.timeout_in = 30.minutes

  # Remember me configuration
  config.remember_for = 2.weeks
end
```

**Configure Action Mailer for Development:** Edit `config/environments/development.rb`:

```ruby
# Add inside Rails.application.configure block
config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
config.action_mailer.delivery_method = :letter_opener
config.action_mailer.perform_deliveries = true
```

### Step 9: Install and Configure RSpec (20 minutes)

```bash
# Install RSpec
rails generate rspec:install

# Create spec directories
mkdir -p spec/models
mkdir -p spec/requests
mkdir -p spec/factories
mkdir -p spec/support
```

**Configure RSpec:** Edit `spec/rails_helper.rb` and add the following before `RSpec.configure`:

```ruby
require 'shoulda/matchers'
require 'vcr'
require 'webmock/rspec'

# SimpleCov for code coverage
require 'simplecov'
SimpleCov.start 'rails' do
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/vendor/'
end

# VCR Configuration
VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.ignore_localhost = true
end
```

Add inside the `RSpec.configure` block:

```ruby
RSpec.configure do |config|
  # Existing configuration...

  # Factory Bot
  config.include FactoryBot::Syntax::Methods

  # Database Cleaner
  config.use_transactional_fixtures = true

  # Devise helpers
  config.include Devise::Test::IntegrationHelpers, type: :request
end
```

**Configure Shoulda Matchers:** Create `spec/support/shoulda_matchers.rb`:

```ruby
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
```

### Step 10: Configure Sidekiq (15 minutes)

Create `config/sidekiq.yml`:

```yaml
:concurrency: 5
:timeout: 25
:verbose: true
:queues:
  - default
  - mailers
  - active_storage_analysis
  - active_storage_purge

development:
  :concurrency: 3

production:
  :concurrency: 10
```

**Mount Sidekiq Web UI:** Edit `config/routes.rb`:

```ruby
require 'sidekiq/web'

Rails.application.routes.draw do
  # Devise routes
  devise_for :users

  # Sidekiq Web UI (protect in production!)
  mount Sidekiq::Web => '/sidekiq'

  # Root path
  root "home#index"

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
```

### Step 11: Configure Development Tools (10 minutes)

**Annotate Models:** Create `lib/tasks/auto_annotate_models.rake`:

```ruby
if Rails.env.development?
  require 'annotate'
  task :set_annotation_options do
    Annotate.set_defaults(
      'routes'                    => 'false',
      'position_in_routes'        => 'before',
      'position_in_class'         => 'before',
      'position_in_test'          => 'before',
      'position_in_fixture'       => 'before',
      'position_in_factory'       => 'before',
      'position_in_serializer'    => 'before',
      'show_foreign_keys'         => 'true',
      'show_complete_foreign_keys' => 'false',
      'show_indexes'              => 'true',
      'simple_indexes'            => 'false',
      'model_dir'                 => 'app/models',
      'root_dir'                  => '',
      'include_version'           => 'false',
      'require'                   => '',
      'exclude_tests'             => 'false',
      'exclude_fixtures'          => 'false',
      'exclude_factories'         => 'false',
      'exclude_serializers'       => 'false',
      'exclude_scaffolds'         => 'true',
      'exclude_controllers'       => 'true',
      'exclude_helpers'           => 'true',
      'exclude_sti_subclasses'    => 'false',
      'ignore_model_sub_dir'      => 'false',
      'ignore_columns'            => nil,
      'ignore_routes'             => nil,
      'ignore_unknown_models'     => 'false',
      'hide_limit_column_types'   => 'integer,boolean,float,string,text',
      'hide_default_column_types' => 'json,jsonb,hstore',
      'skip_on_db_migrate'        => 'false',
      'format_bare'               => 'true',
      'format_rdoc'               => 'false',
      'format_markdown'           => 'false',
      'sort'                      => 'false',
      'force'                     => 'false',
      'frozen'                    => 'false',
      'classified_sort'           => 'true',
      'trace'                     => 'false',
      'wrapper_open'              => nil,
      'wrapper_close'             => nil,
      'with_comment'              => 'true'
    )
  end

  Annotate.load_tasks
end
```

**Bullet Configuration:** Edit `config/environments/development.rb`:

```ruby
# Add inside Rails.application.configure block
config.after_initialize do
  Bullet.enable = true
  Bullet.alert = true
  Bullet.bullet_logger = true
  Bullet.console = true
  Bullet.rails_logger = true
  Bullet.add_footer = true
end
```

### Step 12: Create Initial Controllers and Views (20 minutes)

```bash
# Generate home controller
rails generate controller Home index
```

Edit `app/views/home/index.html.erb`:

```erb
<div class="min-h-screen bg-gray-100 py-6 flex flex-col justify-center sm:py-12">
  <div class="relative py-3 sm:max-w-xl sm:mx-auto">
    <div class="relative px-4 py-10 bg-white shadow-lg sm:rounded-3xl sm:p-20">
      <div class="max-w-md mx-auto">
        <div class="divide-y divide-gray-200">
          <div class="py-8 text-base leading-6 space-y-4 text-gray-700 sm:text-lg sm:leading-7">
            <h1 class="text-3xl font-bold text-gray-900 mb-4">Welcome to AEO</h1>
            <p>Your Rails application is successfully initialized!</p>

            <div class="pt-6 space-y-2">
              <% if user_signed_in? %>
                <p class="text-green-600">✓ Signed in as <%= current_user.email %></p>
                <%= button_to "Sign Out", destroy_user_session_path, method: :delete,
                    class: "bg-red-500 text-white px-4 py-2 rounded hover:bg-red-600" %>
              <% else %>
                <p class="text-gray-600">Not signed in</p>
                <div class="space-x-2">
                  <%= link_to "Sign In", new_user_session_path,
                      class: "bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600 inline-block" %>
                  <%= link_to "Sign Up", new_user_registration_path,
                      class: "bg-green-500 text-white px-4 py-2 rounded hover:bg-green-600 inline-block" %>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</div>
```

### Step 13: Run Initial Tests (10 minutes)

```bash
# Run RSpec to verify setup
bundle exec rspec

# Expected output: 0 examples, 0 failures (no tests yet)
```

### Step 14: Start the Application (5 minutes)

```bash
# In one terminal: Start Rails server
bin/rails server

# In another terminal: Start Sidekiq
bundle exec sidekiq

# In another terminal: Start Tailwind CSS watcher
bin/rails tailwindcss:watch
```

Visit `http://localhost:3000` - you should see the welcome page!

## Workflow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Rails Initialization                      │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Step 1: Create Rails App (rails new)                       │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Step 2-3: Configure Gemfile & Install Dependencies         │
│  • Add Devise, Sidekiq, Testing gems                        │
│  • Run bundle install                                       │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Step 4-6: Database Setup                                   │
│  • Configure database.yml                                   │
│  • Set up .env file                                         │
│  • Create databases                                         │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Step 7: Configure Application                              │
│  • Update application.rb                                    │
│  • Set generators, time zone, locale                        │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Step 8: Install Devise                                     │
│  • Generate Devise config                                   │
│  • Create User model                                        │
│  • Run migrations                                           │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Step 9: Configure RSpec & Testing                          │
│  • Install RSpec                                            │
│  • Configure FactoryBot, Shoulda, VCR                       │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Step 10: Configure Sidekiq                                 │
│  • Create sidekiq.yml                                       │
│  • Mount Sidekiq Web UI                                     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Step 11: Development Tools                                 │
│  • Configure Annotate                                       │
│  • Configure Bullet                                         │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Step 12-14: Create Views & Test                            │
│  • Generate home controller                                 │
│  • Run tests                                                │
│  • Start servers                                            │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
                    ┌───────────────┐
                    │   SUCCESS!    │
                    └───────────────┘
```

## Success Criteria Checklist

Use this checklist to verify your setup is complete:

- [ ] Rails application created successfully
- [ ] All gems installed without errors (`bundle install` succeeds)
- [ ] PostgreSQL databases created (development and test)
- [ ] `.env` file created and added to `.gitignore`
- [ ] Devise installed and User model created
- [ ] Can access Devise sign-up page at `/users/sign_up`
- [ ] Can create a new user account
- [ ] RSpec installed and configured
- [ ] `bundle exec rspec` runs without errors
- [ ] Sidekiq configured and can start with `bundle exec sidekiq`
- [ ] Tailwind CSS working (styles visible on home page)
- [ ] Rails server starts successfully (`bin/rails server`)
- [ ] Home page loads at `http://localhost:3000`
- [ ] Can sign up, sign in, and sign out
- [ ] Letter Opener opens emails in browser (test by signing up)
- [ ] Annotate gem ready (run `rails db:migrate` to test)
- [ ] Bullet gem active (check console for N+1 query warnings)

## Troubleshooting

### Common Issues and Solutions

#### 1. PostgreSQL Connection Error

**Error:** `FATAL: role "postgres" does not exist`

**Solution:**
```bash
# Create postgres user
createuser -s postgres

# Or use your system username
# Update .env file with your username
POSTGRES_USER=your_username
```

#### 2. Redis Connection Error

**Error:** `Error connecting to Redis on localhost:6379`

**Solution:**
```bash
# Start Redis (macOS with Homebrew)
brew services start redis

# Or start manually
redis-server

# Verify Redis is running
redis-cli ping
# Should return: PONG
```

#### 3. Bundle Install Fails

**Error:** Various gem installation errors

**Solution:**
```bash
# Update bundler
gem update bundler

# Clear bundle cache
bundle clean --force

# Reinstall
bundle install
```

#### 4. Database Already Exists

**Error:** `database "aeo_development" already exists`

**Solution:**
```bash
# Drop and recreate
rails db:drop db:create db:migrate
```

#### 5. Webpacker/JavaScript Issues

**Error:** JavaScript not loading or compilation errors

**Solution:**
```bash
# Reinstall JavaScript dependencies
rm -rf node_modules
yarn install

# Rebuild
bin/rails assets:precompile
```

#### 6. Devise Secret Key Warning

**Error:** `Devise.secret_key was not set`

**Solution:**
```bash
# Generate a secret key
rails secret

# Add to .env file
DEVISE_SECRET_KEY=<generated_secret_key>
```

#### 7. Tailwind CSS Not Loading

**Error:** Styles not appearing

**Solution:**
```bash
# Rebuild Tailwind
bin/rails tailwindcss:build

# Or run the watcher
bin/rails tailwindcss:watch
```

## Testing Your Setup

### 1. Test User Registration

```bash
# Start the server
bin/rails server

# Visit http://localhost:3000/users/sign_up
# Fill out the form and submit
# Check your terminal for Letter Opener output
```

### 2. Test Background Jobs

Create a test job:

```bash
rails generate job TestJob
```

Edit `app/jobs/test_job.rb`:

```ruby
class TestJob < ApplicationJob
  queue_as :default

  def perform(*args)
    Rails.logger.info "Test job executed with args: #{args}"
  end
end
```

Test in Rails console:

```bash
rails console
> TestJob.perform_later("Hello", "World")
# Check Sidekiq terminal for output
```

### 3. Test Database Connection

```bash
rails console
> User.count
# Should return 0 (or number of users created)
```

## Next Steps

After completing this initialization, you're ready to move on to:

1. **Database Schema Design** - Design your core models and relationships
2. **User Roles & Permissions** - Implement authorization (e.g., with Pundit)
3. **API Setup** - Configure API endpoints if needed
4. **Frontend Components** - Build reusable Stimulus components
5. **Testing Strategy** - Write your first model and request specs

## Additional Resources

- [Rails Guides](https://guides.rubyonrails.org/)
- [Devise Documentation](https://github.com/heartcombo/devise)
- [Sidekiq Documentation](https://github.com/sidekiq/sidekiq/wiki)
- [RSpec Rails Documentation](https://github.com/rspec/rspec-rails)
- [Tailwind CSS Documentation](https://tailwindcss.com/docs)
- [Turbo Documentation](https://turbo.hotwired.dev/)
- [Stimulus Documentation](https://stimulus.hotwired.dev/)

## Notes

- **Security:** Never commit `.env` file to version control
- **Production:** Use proper secret management (Rails credentials or environment variables)
- **Devise:** We're using Devise instead of bcrypt for full-featured authentication
- **Testing:** Always run tests before committing code
- **Background Jobs:** Sidekiq requires Redis to be running
- **Tailwind:** The watcher must be running during development for CSS changes

---

**Estimated Completion Time:** 4 hours
**Difficulty Level:** Beginner-Friendly
**Prerequisites:** Ruby, PostgreSQL, Redis installed
**Next Task:** Database Schema Design & Model Creation

