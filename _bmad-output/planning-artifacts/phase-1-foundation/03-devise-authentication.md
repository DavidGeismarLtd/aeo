# Task: Devise Authentication Setup

**Estimated Time:** 6 hours
**Priority:** High
**Dependencies:** Database setup, Rails application initialized

---

## Overview

Set up Devise for user authentication with email confirmation, custom fields, and Tailwind CSS styling. This provides the foundation for user management in the AEO application.

---

## Step-by-Step Instructions

### 1. Install Devise Gem

**Add to Gemfile:**
```ruby
# Gemfile
gem 'devise', '~> 4.9'
```

**Install:**
```bash
bundle install
rails generate devise:install
```

---

### 2. Configure Devise Initializer

**Edit `config/initializers/devise.rb`:**

```ruby
# config/initializers/devise.rb
Devise.setup do |config|
  # Secret key for Devise
  config.secret_key = Rails.application.credentials.secret_key_base

  # Mailer sender
  config.mailer_sender = 'noreply@aeo-app.com'

  # ORM
  require 'devise/orm/active_record'

  # Authentication keys
  config.authentication_keys = [:email]
  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]

  # Password configuration
  config.password_length = 8..128
  config.reset_password_within = 6.hours

  # Confirmation
  config.reconfirmable = true
  config.confirm_within = 3.days

  # Remember me
  config.remember_for = 2.weeks
  config.expire_all_remember_me_on_sign_out = true

  # Sign out behavior
  config.sign_out_via = :delete

  # Modules
  # Available: :confirmable, :lockable, :timeoutable, :trackable, :omniauthable
end
```

---

### 3. Generate User Model with UUID

**Generate Devise User model:**
```bash
rails generate devise User
```

**Modify the migration to use UUID:**

```ruby
# db/migrate/XXXXXX_devise_create_users.rb
class DeviseCreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users, id: :uuid do |t|
      ## Database authenticatable
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      ## Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at

      ## Confirmable
      t.string   :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string   :unconfirmed_email

      ## Custom fields
      t.string :first_name, null: false
      t.string :last_name, null: false

      t.timestamps null: false
    end

    add_index :users, :email,                unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :confirmation_token,   unique: true
  end
end
```

**Run migration:**
```bash
rails db:migrate
```

---

### 4. Configure User Model

**Edit `app/models/user.rb`:**

```ruby
# app/models/user.rb
class User < ApplicationRecord
  # Devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable

  # Validations
  validates :first_name, presence: true, length: { maximum: 50 }
  validates :last_name, presence: true, length: { maximum: 50 }
  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  # Callbacks
  before_save :downcase_email

  # Instance methods
  def full_name
    "#{first_name} #{last_name}"
  end

  def initials
    "#{first_name[0]}#{last_name[0]}".upcase
  end

  private

  def downcase_email
    self.email = email.downcase if email.present?
  end
end
```

---

### 5. Configure Routes

**Edit `config/routes.rb`:**

```ruby
# config/routes.rb
Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: 'users/registrations',
    sessions: 'users/sessions',
    passwords: 'users/passwords',
    confirmations: 'users/confirmations'
  }

  # Authenticated root
  authenticated :user do
    root 'dashboard#index', as: :authenticated_root
  end

  # Public root
  root 'pages#home'
end
```

---

### 6. Generate and Customize Devise Views

**Generate Devise views:**
```bash
rails generate devise:views
```

**Customize Registration Form with Tailwind (`app/views/devise/registrations/new.html.erb`):**

```erb
<div class="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
  <div class="max-w-md w-full space-y-8">
    <div>
      <h2 class="mt-6 text-center text-3xl font-extrabold text-gray-900">
        Create your account
      </h2>
      <p class="mt-2 text-center text-sm text-gray-600">
        Or
        <%= link_to "sign in to your account", new_user_session_path, class: "font-medium text-indigo-600 hover:text-indigo-500" %>
      </p>
    </div>

    <%= form_for(resource, as: resource_name, url: registration_path(resource_name), html: { class: "mt-8 space-y-6" }) do |f| %>
      <%= render "devise/shared/error_messages", resource: resource %>

      <div class="rounded-md shadow-sm -space-y-px">
        <div class="grid grid-cols-2 gap-4 mb-4">
          <div>
            <%= f.label :first_name, class: "block text-sm font-medium text-gray-700" %>
            <%= f.text_field :first_name, autofocus: true, autocomplete: "given-name",
                class: "mt-1 appearance-none rounded-md relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm",
                placeholder: "First name" %>
          </div>

          <div>
            <%= f.label :last_name, class: "block text-sm font-medium text-gray-700" %>
            <%= f.text_field :last_name, autocomplete: "family-name",
                class: "mt-1 appearance-none rounded-md relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm",
                placeholder: "Last name" %>
          </div>
        </div>

        <div class="mb-4">
          <%= f.label :email, class: "block text-sm font-medium text-gray-700" %>
          <%= f.email_field :email, autocomplete: "email",
              class: "mt-1 appearance-none rounded-md relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm",
              placeholder: "Email address" %>
        </div>

        <div class="mb-4">
          <%= f.label :password, class: "block text-sm font-medium text-gray-700" %>
          <%= f.password_field :password, autocomplete: "new-password",
              class: "mt-1 appearance-none rounded-md relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm",
              placeholder: "Password (8+ characters)" %>
        </div>

        <div class="mb-4">
          <%= f.label :password_confirmation, class: "block text-sm font-medium text-gray-700" %>
          <%= f.password_field :password_confirmation, autocomplete: "new-password",
              class: "mt-1 appearance-none rounded-md relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm",
              placeholder: "Confirm password" %>
        </div>
      </div>

      <div>
        <%= f.submit "Sign up", class: "group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 cursor-pointer" %>
      </div>
    <% end %>

    <div class="text-center text-sm">
      <%= render "devise/shared/links" %>
    </div>
  </div>
</div>
```

**Customize Sign In Form (`app/views/devise/sessions/new.html.erb`):**

```erb
<div class="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
  <div class="max-w-md w-full space-y-8">
    <div>
      <h2 class="mt-6 text-center text-3xl font-extrabold text-gray-900">
        Sign in to your account
      </h2>
      <p class="mt-2 text-center text-sm text-gray-600">
        Or
        <%= link_to "create a new account", new_user_registration_path, class: "font-medium text-indigo-600 hover:text-indigo-500" %>
      </p>
    </div>

    <%= form_for(resource, as: resource_name, url: session_path(resource_name), html: { class: "mt-8 space-y-6" }) do |f| %>
      <div class="rounded-md shadow-sm -space-y-px">
        <div class="mb-4">
          <%= f.label :email, class: "block text-sm font-medium text-gray-700" %>
          <%= f.email_field :email, autofocus: true, autocomplete: "email",
              class: "mt-1 appearance-none rounded-md relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm",
              placeholder: "Email address" %>
        </div>

        <div class="mb-4">
          <%= f.label :password, class: "block text-sm font-medium text-gray-700" %>
          <%= f.password_field :password, autocomplete: "current-password",
              class: "mt-1 appearance-none rounded-md relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm",
              placeholder: "Password" %>
        </div>
      </div>

      <% if devise_mapping.rememberable? %>
        <div class="flex items-center">
          <%= f.check_box :remember_me, class: "h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded" %>
          <%= f.label :remember_me, class: "ml-2 block text-sm text-gray-900" %>
        </div>
      <% end %>

      <div>
        <%= f.submit "Sign in", class: "group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 cursor-pointer" %>
      </div>
    <% end %>

    <div class="text-center text-sm space-y-2">
      <%= render "devise/shared/links" %>
    </div>
  </div>
</div>
```

---


### 7. Create Custom Devise Controllers

**Generate controllers:**
```bash
mkdir -p app/controllers/users
```

**Registrations Controller (`app/controllers/users/registrations_controller.rb`):**

```ruby
# app/controllers/users/registrations_controller.rb
class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_sign_up_params, only: [:create]
  before_action :configure_account_update_params, only: [:update]

  protected

  # Permit additional parameters for sign up
  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name])
  end

  # Permit additional parameters for account update
  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name])
  end

  # Redirect after sign up
  def after_sign_up_path_for(resource)
    flash[:notice] = "Welcome! Please check your email to confirm your account."
    root_path
  end

  # Redirect after inactive sign up (email confirmation required)
  def after_inactive_sign_up_path_for(resource)
    flash[:notice] = "Please check your email to confirm your account."
    root_path
  end
end
```

**Sessions Controller (`app/controllers/users/sessions_controller.rb`):**

```ruby
# app/controllers/users/sessions_controller.rb
class Users::SessionsController < Devise::SessionsController
  # Override to add custom behavior
  def create
    super do |resource|
      flash[:notice] = "Welcome back, #{resource.first_name}!"
    end
  end

  def destroy
    super do
      flash[:notice] = "You have been signed out successfully."
    end
  end
end
```

**Passwords Controller (`app/controllers/users/passwords_controller.rb`):**

```ruby
# app/controllers/users/passwords_controller.rb
class Users::PasswordsController < Devise::PasswordsController
  # Override to add custom behavior if needed
end
```

**Confirmations Controller (`app/controllers/users/confirmations_controller.rb`):**

```ruby
# app/controllers/users/confirmations_controller.rb
class Users::ConfirmationsController < Devise::ConfirmationsController
  # Override to add custom behavior if needed

  protected

  def after_confirmation_path_for(resource_name, resource)
    flash[:notice] = "Your email has been confirmed. Welcome to AEO!"
    new_user_session_path
  end
end
```

---

### 8. Configure Mailer Settings

**Development Environment (`config/environments/development.rb`):**

```ruby
# config/environments/development.rb
Rails.application.configure do
  # ... other configurations

  # Devise mailer configuration
  config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
  config.action_mailer.delivery_method = :letter_opener
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true
end
```

**Add letter_opener gem for development (Gemfile):**

```ruby
# Gemfile
group :development do
  gem 'letter_opener', '~> 1.8'
end
```

**Production Environment (`config/environments/production.rb`):**

```ruby
# config/environments/production.rb
Rails.application.configure do
  # ... other configurations

  # Devise mailer configuration
  config.action_mailer.default_url_options = { host: 'your-domain.com', protocol: 'https' }
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = false

  # SMTP settings (example with SendGrid)
  config.action_mailer.smtp_settings = {
    address: 'smtp.sendgrid.net',
    port: 587,
    domain: 'your-domain.com',
    user_name: ENV['SENDGRID_USERNAME'],
    password: ENV['SENDGRID_PASSWORD'],
    authentication: :plain,
    enable_starttls_auto: true
  }
end
```

---

### 9. Add Application Helper Methods

**Edit `app/helpers/application_helper.rb`:**

```ruby
# app/helpers/application_helper.rb
module ApplicationHelper
  def flash_class(level)
    case level.to_sym
    when :notice then "bg-blue-100 border-blue-400 text-blue-700"
    when :success then "bg-green-100 border-green-400 text-green-700"
    when :error then "bg-red-100 border-red-400 text-red-700"
    when :alert then "bg-yellow-100 border-yellow-400 text-yellow-700"
    else "bg-gray-100 border-gray-400 text-gray-700"
    end
  end

  def user_avatar(user, size: 'md')
    size_classes = {
      'sm' => 'h-8 w-8 text-sm',
      'md' => 'h-10 w-10 text-base',
      'lg' => 'h-12 w-12 text-lg',
      'xl' => 'h-16 w-16 text-xl'
    }

    content_tag :div, class: "#{size_classes[size]} rounded-full bg-indigo-600 flex items-center justify-center text-white font-semibold" do
      user.initials
    end
  end
end
```

---


### 10. Add Flash Messages Partial

**Create `app/views/shared/_flash_messages.html.erb`:**

```erb
<% flash.each do |type, message| %>
  <div class="<%= flash_class(type) %> border px-4 py-3 rounded relative mb-4" role="alert">
    <span class="block sm:inline"><%= message %></span>
    <button type="button" class="absolute top-0 bottom-0 right-0 px-4 py-3" onclick="this.parentElement.remove()">
      <svg class="fill-current h-6 w-6" role="button" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20">
        <title>Close</title>
        <path d="M14.348 14.849a1.2 1.2 0 0 1-1.697 0L10 11.819l-2.651 3.029a1.2 1.2 0 1 1-1.697-1.697l2.758-3.15-2.759-3.152a1.2 1.2 0 1 1 1.697-1.697L10 8.183l2.651-3.031a1.2 1.2 0 1 1 1.697 1.697l-2.758 3.152 2.758 3.15a1.2 1.2 0 0 1 0 1.698z"/>
      </svg>
    </button>
  </div>
<% end %>
```

**Include in layout (`app/views/layouts/application.html.erb`):**

```erb
<!DOCTYPE html>
<html>
  <head>
    <title>AEO</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body>
    <div class="container mx-auto px-4">
      <%= render 'shared/flash_messages' %>
      <%= yield %>
    </div>
  </body>
</html>
```

---

## Authentication Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     User Registration Flow                      │
└─────────────────────────────────────────────────────────────────┘

    User visits /users/sign_up
            │
            ▼
    ┌───────────────────┐
    │  Registration     │
    │  Form (Tailwind)  │
    │  - First Name     │
    │  - Last Name      │
    │  - Email          │
    │  - Password       │
    └───────────────────┘
            │
            ▼
    Users::RegistrationsController
            │
            ▼
    ┌───────────────────┐
    │  Create User      │
    │  (unconfirmed)    │
    └───────────────────┘
            │
            ▼
    ┌───────────────────┐
    │  Send             │
    │  Confirmation     │
    │  Email            │
    └───────────────────┘
            │
            ▼
    User clicks confirmation link
            │
            ▼
    Users::ConfirmationsController
            │
            ▼
    ┌───────────────────┐
    │  Confirm User     │
    │  Account          │
    └───────────────────┘
            │
            ▼
    Redirect to Sign In


┌─────────────────────────────────────────────────────────────────┐
│                      User Sign In Flow                          │
└─────────────────────────────────────────────────────────────────┘

    User visits /users/sign_in
            │
            ▼
    ┌───────────────────┐
    │  Sign In Form     │
    │  (Tailwind)       │
    │  - Email          │
    │  - Password       │
    │  - Remember Me    │
    └───────────────────┘
            │
            ▼
    Users::SessionsController
            │
            ▼
    ┌───────────────────┐
    │  Authenticate     │
    │  User             │
    └───────────────────┘
            │
            ├─── Valid ────────────────┐
            │                          │
            ▼                          ▼
    ┌───────────────────┐    ┌───────────────────┐
    │  Confirmed?       │    │  Show Error       │
    └───────────────────┘    │  Message          │
            │                └───────────────────┘
            ├─── Yes ──────────────┐
            │                      │
            ▼                      ▼
    ┌───────────────────┐    Redirect to Sign In
    │  Create Session   │
    │  Set Remember Me  │
    └───────────────────┘
            │
            ▼
    Redirect to Dashboard


┌─────────────────────────────────────────────────────────────────┐
│                   Password Reset Flow                           │
└─────────────────────────────────────────────────────────────────┘

    User clicks "Forgot Password?"
            │
            ▼
    /users/password/new
            │
            ▼
    ┌───────────────────┐
    │  Enter Email      │
    └───────────────────┘
            │
            ▼
    Users::PasswordsController
            │
            ▼
    ┌───────────────────┐
    │  Send Reset       │
    │  Instructions     │
    └───────────────────┘
            │
            ▼
    User clicks reset link
            │
            ▼
    /users/password/edit?reset_password_token=XXX
            │
            ▼
    ┌───────────────────┐
    │  Enter New        │
    │  Password         │
    └───────────────────┘
            │
            ▼
    ┌───────────────────┐
    │  Update Password  │
    └───────────────────┘
            │
            ▼
    Redirect to Sign In
```

---


## Testing Examples

### 11. Model Tests

**Create `test/models/user_test.rb`:**

```ruby
# test/models/user_test.rb
require "test_helper"

class UserTest < ActiveSupport::TestCase
  def setup
    @user = User.new(
      first_name: "John",
      last_name: "Doe",
      email: "john@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "should be valid" do
    assert @user.valid?
  end

  test "first_name should be present" do
    @user.first_name = "   "
    assert_not @user.valid?
  end

  test "last_name should be present" do
    @user.last_name = "   "
    assert_not @user.valid?
  end

  test "email should be present" do
    @user.email = "   "
    assert_not @user.valid?
  end

  test "email should be unique" do
    duplicate_user = @user.dup
    duplicate_user.email = @user.email.upcase
    @user.save
    assert_not duplicate_user.valid?
  end

  test "email should be saved as lowercase" do
    mixed_case_email = "JoHn@ExAmPlE.CoM"
    @user.email = mixed_case_email
    @user.save
    assert_equal mixed_case_email.downcase, @user.reload.email
  end

  test "password should be present and minimum length" do
    @user.password = @user.password_confirmation = "a" * 7
    assert_not @user.valid?
  end

  test "full_name should return first and last name" do
    assert_equal "John Doe", @user.full_name
  end

  test "initials should return first letters of first and last name" do
    assert_equal "JD", @user.initials
  end
end
```

---

### 12. Integration Tests

**Create `test/integration/user_authentication_test.rb`:**

```ruby
# test/integration/user_authentication_test.rb
require "test_helper"

class UserAuthenticationTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one) # Assumes you have a fixture
  end

  test "user can sign up" do
    get new_user_registration_path
    assert_response :success

    assert_difference 'User.count', 1 do
      post user_registration_path, params: {
        user: {
          first_name: "Jane",
          last_name: "Smith",
          email: "jane@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_redirected_to root_path
    follow_redirect!
    assert_match /check your email/i, response.body
  end

  test "user can sign in with valid credentials" do
    @user.confirm # Confirm the user first

    get new_user_session_path
    assert_response :success

    post user_session_path, params: {
      user: {
        email: @user.email,
        password: "password"
      }
    }

    assert_redirected_to authenticated_root_path
    follow_redirect!
    assert_match /Welcome back/i, response.body
  end

  test "user cannot sign in with invalid credentials" do
    get new_user_session_path
    assert_response :success

    post user_session_path, params: {
      user: {
        email: @user.email,
        password: "wrongpassword"
      }
    }

    assert_response :unprocessable_entity
    assert_match /Invalid/i, response.body
  end

  test "user can sign out" do
    sign_in @user
    delete destroy_user_session_path
    assert_redirected_to root_path
    follow_redirect!
    assert_match /signed out/i, response.body
  end

  test "user can request password reset" do
    get new_user_password_path
    assert_response :success

    assert_difference 'ActionMailer::Base.deliveries.size', 1 do
      post user_password_path, params: {
        user: { email: @user.email }
      }
    end

    assert_redirected_to new_user_session_path
  end
end
```

---

### 13. Fixtures

**Create `test/fixtures/users.yml`:**

```yaml
# test/fixtures/users.yml
one:
  id: <%= SecureRandom.uuid %>
  first_name: John
  last_name: Doe
  email: john@example.com
  encrypted_password: <%= Devise::Encryptor.digest(User, 'password') %>
  confirmed_at: <%= Time.now %>
  created_at: <%= Time.now %>
  updated_at: <%= Time.now %>

two:
  id: <%= SecureRandom.uuid %>
  first_name: Jane
  last_name: Smith
  email: jane@example.com
  encrypted_password: <%= Devise::Encryptor.digest(User, 'password') %>
  confirmed_at: <%= Time.now %>
  created_at: <%= Time.now %>
  updated_at: <%= Time.now %>
```

---

### 14. Test Helper

**Update `test/test_helper.rb`:**

```ruby
# test/test_helper.rb
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
```

---


## Success Criteria Checklist

- [ ] Devise gem installed and configured
- [ ] User model created with UUID primary key
- [ ] Custom fields (first_name, last_name) added to User model
- [ ] Devise modules configured:
  - [ ] :database_authenticatable
  - [ ] :registerable
  - [ ] :recoverable
  - [ ] :rememberable
  - [ ] :validatable
  - [ ] :confirmable
- [ ] Devise views generated and customized with Tailwind CSS
- [ ] Custom Devise controllers created:
  - [ ] Users::RegistrationsController
  - [ ] Users::SessionsController
  - [ ] Users::PasswordsController
  - [ ] Users::ConfirmationsController
- [ ] Routes configured with custom controllers
- [ ] Mailer settings configured for development and production
- [ ] Flash messages partial created and styled
- [ ] Application helper methods added (flash_class, user_avatar)
- [ ] User model validations implemented
- [ ] User model helper methods implemented (full_name, initials)
- [ ] Email confirmation working
- [ ] Password reset working
- [ ] Remember me functionality working
- [ ] Model tests written and passing
- [ ] Integration tests written and passing
- [ ] All authentication flows tested manually

---

## Troubleshooting

### Issue: Email confirmation not sending

**Solution:**
1. Check mailer configuration in `config/environments/development.rb`
2. Verify letter_opener gem is installed for development
3. Check logs for mailer errors: `tail -f log/development.log`
4. Ensure User model has `:confirmable` module enabled
5. Check that confirmation columns exist in users table

```bash
# Check if confirmation columns exist
rails console
User.column_names.grep(/confirm/)
```

---

### Issue: "Couldn't find User without an ID" error

**Solution:**
This usually happens when routes are not properly configured.

1. Check routes configuration:
```bash
rails routes | grep devise
```

2. Ensure Devise routes are defined before other routes in `config/routes.rb`

3. Clear routes cache:
```bash
rails routes:clear
rails restart
```

---

### Issue: Custom fields (first_name, last_name) not saving

**Solution:**
1. Verify strong parameters are configured in custom controllers
2. Check that migration was run successfully
3. Verify columns exist in database:

```bash
rails console
User.column_names
```

4. Ensure parameter sanitizer is configured:

```ruby
# In Users::RegistrationsController
def configure_sign_up_params
  devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name])
end
```

---

### Issue: Tailwind styles not applying to Devise views

**Solution:**
1. Ensure Tailwind CSS is properly installed and configured
2. Restart Rails server after generating Devise views
3. Check that `app/assets/stylesheets/application.tailwind.css` is being loaded
4. Verify `tailwind.config.js` includes Devise view paths:

```javascript
// tailwind.config.js
module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js'
  ]
}
```

5. Rebuild Tailwind CSS:
```bash
rails tailwindcss:build
```

---

### Issue: "Invalid Email or password" even with correct credentials

**Solution:**
1. Check if user is confirmed:
```ruby
rails console
user = User.find_by(email: 'user@example.com')
user.confirmed?
user.confirm # Manually confirm if needed
```

2. Verify password is correct:
```ruby
user.valid_password?('password123')
```

3. Check Devise configuration in `config/initializers/devise.rb`
4. Ensure authentication keys are set correctly

---

### Issue: Session not persisting after sign in

**Solution:**
1. Check that cookies are enabled in browser
2. Verify session store configuration in `config/initializers/session_store.rb`
3. Check that secret_key_base is set:

```bash
rails credentials:edit
```

4. Ensure CSRF protection is not blocking requests
5. Check for JavaScript errors in browser console

---

### Issue: Password reset email not received

**Solution:**
1. Check mailer configuration
2. Verify email is in database:
```ruby
User.find_by(email: 'user@example.com')
```

3. Check ActionMailer deliveries in development:
```ruby
rails console
ActionMailer::Base.deliveries.last
```

4. Ensure reset_password_token is being generated:
```ruby
user = User.find_by(email: 'user@example.com')
user.send_reset_password_instructions
```

---

## Running Tests

**Run all tests:**
```bash
rails test
```

**Run specific test file:**
```bash
rails test test/models/user_test.rb
```

**Run specific test:**
```bash
rails test test/models/user_test.rb:6
```

**Run with verbose output:**
```bash
rails test -v
```

**Run integration tests only:**
```bash
rails test:integration
```

---

## Manual Testing Checklist

### Registration Flow
- [ ] Visit `/users/sign_up`
- [ ] Fill in all fields (first_name, last_name, email, password, password_confirmation)
- [ ] Submit form
- [ ] Verify confirmation email is sent (check letter_opener in development)
- [ ] Click confirmation link in email
- [ ] Verify user is redirected to sign in page
- [ ] Verify success message is displayed

### Sign In Flow
- [ ] Visit `/users/sign_in`
- [ ] Enter valid email and password
- [ ] Check "Remember me" checkbox
- [ ] Submit form
- [ ] Verify user is redirected to dashboard
- [ ] Verify welcome message is displayed
- [ ] Close browser and reopen
- [ ] Verify user is still signed in (remember me)

### Sign Out Flow
- [ ] Click sign out link
- [ ] Verify user is redirected to home page
- [ ] Verify sign out message is displayed
- [ ] Try to access authenticated page
- [ ] Verify user is redirected to sign in page

### Password Reset Flow
- [ ] Visit `/users/sign_in`
- [ ] Click "Forgot your password?" link
- [ ] Enter email address
- [ ] Submit form
- [ ] Verify reset email is sent
- [ ] Click reset link in email
- [ ] Enter new password
- [ ] Submit form
- [ ] Verify user is redirected to sign in page
- [ ] Sign in with new password
- [ ] Verify sign in is successful

### Error Handling
- [ ] Try to sign up with invalid email
- [ ] Try to sign up with short password (< 8 characters)
- [ ] Try to sign up with mismatched password confirmation
- [ ] Try to sign up with existing email
- [ ] Try to sign in with unconfirmed account
- [ ] Try to sign in with invalid credentials
- [ ] Verify appropriate error messages are displayed

---

## Next Steps

After completing Devise authentication setup:

1. **Create Dashboard Controller**
   - Generate dashboard controller
   - Add authenticated root route
   - Create dashboard view

2. **Add User Profile Management**
   - Edit profile page
   - Update password functionality
   - Delete account functionality

3. **Implement Authorization**
   - Install Pundit or CanCanCan
   - Define user roles
   - Set up authorization policies

4. **Add OAuth Authentication** (Optional)
   - Configure OmniAuth
   - Add Google/GitHub sign in
   - Link OAuth accounts to users

5. **Enhance Security**
   - Add account lockable module
   - Implement two-factor authentication
   - Add session timeout
   - Configure CORS if needed

---

## Additional Resources

- [Devise Documentation](https://github.com/heartcombo/devise)
- [Devise Wiki](https://github.com/heartcombo/devise/wiki)
- [Tailwind CSS Documentation](https://tailwindcss.com/docs)
- [Rails Guides - Action Mailer](https://guides.rubyonrails.org/action_mailer_basics.html)
- [Testing with Devise](https://github.com/heartcombo/devise/wiki/How-To:-Test-with-Devise)

---

## Estimated Time Breakdown

| Task | Estimated Time |
|------|----------------|
| Install and configure Devise | 30 minutes |
| Generate and customize User model | 45 minutes |
| Customize Devise views with Tailwind | 1.5 hours |
| Create custom Devise controllers | 45 minutes |
| Configure mailer settings | 30 minutes |
| Add helper methods and flash messages | 30 minutes |
| Write model tests | 1 hour |
| Write integration tests | 1 hour |
| Manual testing and debugging | 30 minutes |
| **Total** | **~6 hours** |

---

**Status:** Ready for implementation
**Last Updated:** 2026-01-23
