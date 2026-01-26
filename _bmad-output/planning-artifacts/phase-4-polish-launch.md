---
document_type: Implementation Guide - Phase 4
product_name: GEO Platform
phase: Polish & Launch (Weeks 11-12)
version: 1.0
date: 2026-01-23
author: David Geismar
tech_stack: Ruby on Rails 7.x, PostgreSQL, Redis, Sidekiq, Tailwind CSS
---

# Phase 4: Polish & Launch (Weeks 11-12)

## Overview

**Goal:** Finalize the GEO platform with production-ready features, API, documentation, and deployment

**Duration:** 2 weeks

**Team:** 2-3 developers

**Deliverables:**
- REST API with authentication and documentation
- Rate limiting and API key management
- Team collaboration features
- Email notification system
- Custom reports (PDF/CSV)
- Settings and preferences
- Performance optimization
- Production deployment
- Complete testing and QA

---

## Week 11: API & Collaboration Features

### Feature 4.1: REST API Development

**Estimated Time:** 10 hours

#### Step 1: Install API Dependencies

```bash
# Add to Gemfile
bundle add active_model_serializers
bundle add rack-cors
bundle add jwt
```

```ruby
# Gemfile additions
gem 'active_model_serializers', '~> 0.10.13'
gem 'rack-cors', '~> 2.0'
gem 'jwt', '~> 2.7'
```

#### Step 2: Create API Key Model

```bash
rails generate model ApiKey \
  workspace:references \
  name:string \
  token:string \
  last_used_at:datetime \
  expires_at:datetime \
  active:boolean
```

```ruby
# db/migrate/XXXXXX_create_api_keys.rb
class CreateApiKeys < ActiveRecord::Migration[7.1]
  def change
    create_table :api_keys, id: :uuid do |t|
      t.references :workspace, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :token, null: false
      t.datetime :last_used_at
      t.datetime :expires_at
      t.boolean :active, default: true, null: false
      t.jsonb :metadata, default: {}
      t.timestamps

      t.index :token, unique: true
      t.index [:workspace_id, :active]
    end
  end
end
```

```ruby
# app/models/api_key.rb
class ApiKey < ApplicationRecord
  belongs_to :workspace

  validates :name, presence: true
  validates :token, presence: true, uniqueness: true

  before_validation :generate_token, on: :create

  scope :active, -> { where(active: true) }
  scope :not_expired, -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }

  def self.authenticate(token)
    active.not_expired.find_by(token: token)
  end

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end
end
```

#### Step 3: Create API Base Controller

```ruby
# app/controllers/api/v1/base_controller.rb
module Api
  module V1
    class BaseController < ActionController::API
      include Pagy::Backend

      before_action :authenticate_api_key!
      before_action :set_default_format

      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
      rescue_from ActionController::ParameterMissing, with: :bad_request

      private

      def authenticate_api_key!
        token = request.headers['Authorization']&.split(' ')&.last
        
        unless token
          render json: { error: 'Missing API key' }, status: :unauthorized
          return
        end

        @api_key = ApiKey.authenticate(token)
        
        unless @api_key
          render json: { error: 'Invalid or expired API key' }, status: :unauthorized
          return
        end

        @api_key.touch_last_used!
        @current_workspace = @api_key.workspace
      end

      def current_workspace
        @current_workspace
      end

      def set_default_format
        request.format = :json
      end

      def not_found(exception)
        render json: { error: exception.message }, status: :not_found
      end

      def unprocessable_entity(exception)
        render json: { 
          error: 'Validation failed', 
          details: exception.record.errors.full_messages 
        }, status: :unprocessable_entity
      end

      def bad_request(exception)
        render json: { error: exception.message }, status: :bad_request
      end
    end
  end
end
```

#### Step 4: Create API Controllers

```ruby
# app/controllers/api/v1/brands_controller.rb
module Api
  module V1
    class BrandsController < BaseController
      def index
        @pagy, @brands = pagy(current_workspace.brands.includes(:category))

        render json: @brands,
               meta: pagy_metadata(@pagy),
               each_serializer: BrandSerializer
      end

      def show
        @brand = current_workspace.brands.find(params[:id])
        render json: @brand, serializer: BrandSerializer
      end

      def create
        @brand = current_workspace.brands.build(brand_params)

        if @brand.save
          render json: @brand, serializer: BrandSerializer, status: :created
        else
          render json: { errors: @brand.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        @brand = current_workspace.brands.find(params[:id])

        if @brand.update(brand_params)
          render json: @brand, serializer: BrandSerializer
        else
          render json: { errors: @brand.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @brand = current_workspace.brands.find(params[:id])
        @brand.destroy
        head :no_content
      end

      private

      def brand_params
        params.require(:brand).permit(:name, :category_id, :description, :website_url)
      end
    end
  end
end
```

```ruby
# app/controllers/api/v1/mentions_controller.rb
module Api
  module V1
    class MentionsController < BaseController
      def index
        @mentions = current_workspace.mentions
                                    .includes(:brand, :source)
                                    .order(published_at: :desc)

        # Apply filters
        @mentions = @mentions.where(brand_id: params[:brand_id]) if params[:brand_id]
        @mentions = @mentions.where(source_id: params[:source_id]) if params[:source_id]
        @mentions = @mentions.where('published_at >= ?', params[:start_date]) if params[:start_date]
        @mentions = @mentions.where('published_at <= ?', params[:end_date]) if params[:end_date]
        @mentions = @mentions.where(sentiment: params[:sentiment]) if params[:sentiment]

        @pagy, @mentions = pagy(@mentions)

        render json: @mentions,
               meta: pagy_metadata(@pagy),
               each_serializer: MentionSerializer
      end

      def show
        @mention = current_workspace.mentions.find(params[:id])
        render json: @mention, serializer: MentionSerializer
      end

      def stats
        stats = {
          total_mentions: current_workspace.mentions.count,
          by_sentiment: current_workspace.mentions.group(:sentiment).count,
          by_source: current_workspace.mentions.joins(:source).group('sources.name').count,
          recent_count: current_workspace.mentions.where('published_at >= ?', 7.days.ago).count
        }

        render json: stats
      end

      private

      def mention_params
        params.require(:mention).permit(:brand_id, :source_id, :content, :url, :published_at)
      end
    end
  end
end
```

```ruby
# app/controllers/api/v1/visibility_scores_controller.rb
module Api
  module V1
    class VisibilityScoresController < BaseController
      def index
        @scores = current_workspace.visibility_scores
                                  .includes(:brand)
                                  .order(date: :desc)

        @scores = @scores.where(brand_id: params[:brand_id]) if params[:brand_id]
        @scores = @scores.where('date >= ?', params[:start_date]) if params[:start_date]
        @scores = @scores.where('date <= ?', params[:end_date]) if params[:end_date]

        @pagy, @scores = pagy(@scores)

        render json: @scores,
               meta: pagy_metadata(@pagy),
               each_serializer: VisibilityScoreSerializer
      end

      def show
        @score = current_workspace.visibility_scores.find(params[:id])
        render json: @score, serializer: VisibilityScoreSerializer
      end

      def trends
        brand = current_workspace.brands.find(params[:brand_id])
        scores = brand.visibility_scores
                     .where('date >= ?', 30.days.ago)
                     .order(:date)
                     .pluck(:date, :score)

        render json: {
          brand_id: brand.id,
          brand_name: brand.name,
          period: '30_days',
          data: scores.map { |date, score| { date: date, score: score } }
        }
      end
    end
  end
end
```

#### Step 5: Create API Serializers

```ruby
# app/serializers/brand_serializer.rb
class BrandSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :website_url, :created_at, :updated_at

  belongs_to :category
  has_many :mentions, if: -> { instance_options[:include_mentions] }

  attribute :mention_count do
    object.mentions.count
  end

  attribute :latest_score do
    object.visibility_scores.order(date: :desc).first&.score
  end
end
```

```ruby
# app/serializers/mention_serializer.rb
class MentionSerializer < ActiveModel::Serializer
  attributes :id, :content, :url, :published_at, :sentiment, :sentiment_score, :created_at

  belongs_to :brand
  belongs_to :source

  attribute :excerpt do
    object.content&.truncate(200)
  end
end
```

```ruby
# app/serializers/visibility_score_serializer.rb
class VisibilityScoreSerializer < ActiveModel::Serializer
  attributes :id, :date, :score, :mention_count, :sentiment_average, :created_at

  belongs_to :brand

  attribute :trend do
    previous_score = object.brand.visibility_scores
                          .where('date < ?', object.date)
                          .order(date: :desc)
                          .first&.score

    if previous_score
      ((object.score - previous_score) / previous_score * 100).round(2)
    else
      nil
    end
  end
end
```

#### Step 6: Configure API Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # API routes
  namespace :api do
    namespace :v1 do
      resources :brands do
        resources :mentions, only: [:index]
        resources :visibility_scores, only: [:index] do
          get :trends, on: :collection
        end
      end

      resources :mentions, only: [:index, :show] do
        get :stats, on: :collection
      end

      resources :visibility_scores, only: [:index, :show] do
        get :trends, on: :collection
      end
    end
  end

  # ... existing routes
end
```

#### Step 7: Configure CORS

```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch('CORS_ORIGINS', 'localhost:3000').split(',')

    resource '/api/*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true,
      max_age: 86400
  end
end
```

#### Step 8: Add Pagy Helper for API

```ruby
# app/controllers/api/v1/base_controller.rb (add this method)
def pagy_metadata(pagy)
  {
    current_page: pagy.page,
    next_page: pagy.next,
    prev_page: pagy.prev,
    total_pages: pagy.pages,
    total_count: pagy.count,
    per_page: pagy.items
  }
end
```

#### Step 9: Create API Tests

```ruby
# spec/requests/api/v1/brands_spec.rb
require 'rails_helper'

RSpec.describe 'Api::V1::Brands', type: :request do
  let(:workspace) { create(:workspace) }
  let(:api_key) { create(:api_key, workspace: workspace) }
  let(:headers) { { 'Authorization' => "Bearer #{api_key.token}" } }

  describe 'GET /api/v1/brands' do
    let!(:brands) { create_list(:brand, 3, workspace: workspace) }

    it 'returns all brands' do
      get '/api/v1/brands', headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.size).to eq(3)
    end

    it 'includes pagination metadata' do
      get '/api/v1/brands', headers: headers

      json = JSON.parse(response.body)
      expect(json['meta']).to include('current_page', 'total_pages', 'total_count')
    end
  end

  describe 'GET /api/v1/brands/:id' do
    let(:brand) { create(:brand, workspace: workspace) }

    it 'returns a specific brand' do
      get "/api/v1/brands/#{brand.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(brand.id)
      expect(json['name']).to eq(brand.name)
    end
  end

  describe 'POST /api/v1/brands' do
    let(:valid_params) do
      {
        brand: {
          name: 'New Brand',
          description: 'A new brand',
          website_url: 'https://example.com'
        }
      }
    end

    it 'creates a new brand' do
      expect {
        post '/api/v1/brands', params: valid_params, headers: headers
      }.to change(Brand, :count).by(1)

      expect(response).to have_http_status(:created)
    end
  end

  describe 'without authentication' do
    it 'returns unauthorized' do
      get '/api/v1/brands'
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
```

---

### Feature 4.2: API Documentation

**Estimated Time:** 4 hours

#### Step 1: Install rswag Gem

```ruby
# Gemfile
gem 'rswag', '~> 2.11'
```

```bash
bundle install
rails g rswag:install
```

#### Step 2: Configure Swagger

```ruby
# config/initializers/rswag_api.rb
Rswag::Api.configure do |c|
  c.swagger_root = Rails.root.join('swagger').to_s
  c.swagger_filter = lambda { |swagger, env| swagger }
end
```

```ruby
# config/initializers/rswag_ui.rb
Rswag::Ui.configure do |c|
  c.swagger_endpoint '/api-docs/v1/swagger.yaml', 'API V1 Docs'
  c.config_object = {
    deepLinking: true,
    displayRequestDuration: true,
    docExpansion: 'none',
    filter: true,
    showExtensions: true,
    showCommonExtensions: true
  }
end
```

#### Step 3: Create API Documentation Spec

```ruby
# spec/requests/api/v1/brands_swagger_spec.rb
require 'swagger_helper'

RSpec.describe 'Brands API', type: :request do
  path '/api/v1/brands' do
    get 'Retrieves all brands' do
      tags 'Brands'
      produces 'application/json'
      security [{ bearer_auth: [] }]

      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :items, in: :query, type: :integer, required: false, description: 'Items per page'

      response '200', 'brands found' do
        schema type: :array,
          items: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              name: { type: :string },
              description: { type: :string },
              website_url: { type: :string },
              mention_count: { type: :integer },
              latest_score: { type: :number, nullable: true },
              created_at: { type: :string, format: :datetime },
              updated_at: { type: :string, format: :datetime }
            },
            required: ['id', 'name']
          }

        let(:workspace) { create(:workspace) }
        let(:api_key) { create(:api_key, workspace: workspace) }
        let(:Authorization) { "Bearer #{api_key.token}" }

        run_test!
      end

      response '401', 'unauthorized' do
        run_test!
      end
    end

    post 'Creates a brand' do
      tags 'Brands'
      consumes 'application/json'
      produces 'application/json'
      security [{ bearer_auth: [] }]

      parameter name: :brand, in: :body, schema: {
        type: :object,
        properties: {
          brand: {
            type: :object,
            properties: {
              name: { type: :string },
              description: { type: :string },
              website_url: { type: :string },
              category_id: { type: :string, format: :uuid }
            },
            required: ['name']
          }
        }
      }

      response '201', 'brand created' do
        let(:workspace) { create(:workspace) }
        let(:api_key) { create(:api_key, workspace: workspace) }
        let(:Authorization) { "Bearer #{api_key.token}" }
        let(:brand) { { brand: { name: 'Test Brand' } } }

        run_test!
      end
    end
  end

  path '/api/v1/brands/{id}' do
    parameter name: :id, in: :path, type: :string, format: :uuid

    get 'Retrieves a brand' do
      tags 'Brands'
      produces 'application/json'
      security [{ bearer_auth: [] }]

      response '200', 'brand found' do
        schema type: :object,
          properties: {
            id: { type: :string, format: :uuid },
            name: { type: :string },
            description: { type: :string },
            website_url: { type: :string }
          }

        let(:workspace) { create(:workspace) }
        let(:api_key) { create(:api_key, workspace: workspace) }
        let(:Authorization) { "Bearer #{api_key.token}" }
        let(:id) { create(:brand, workspace: workspace).id }

        run_test!
      end

      response '404', 'brand not found' do
        let(:workspace) { create(:workspace) }
        let(:api_key) { create(:api_key, workspace: workspace) }
        let(:Authorization) { "Bearer #{api_key.token}" }
        let(:id) { 'invalid' }

        run_test!
      end
    end
  end
end
```

#### Step 4: Create Swagger Helper

```ruby
# spec/swagger_helper.rb
require 'rails_helper'

RSpec.configure do |config|
  config.swagger_root = Rails.root.join('swagger').to_s

  config.swagger_docs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'GEO Platform API V1',
        version: 'v1',
        description: 'API for accessing GEO Platform data',
        contact: {
          name: 'API Support',
          email: 'support@geoplatform.com'
        }
      },
      paths: {},
      servers: [
        {
          url: 'http://localhost:3000',
          description: 'Development server'
        },
        {
          url: 'https://api.geoplatform.com',
          description: 'Production server'
        }
      ],
      components: {
        securitySchemes: {
          bearer_auth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: 'JWT'
          }
        }
      }
    }
  }

  config.swagger_format = :yaml
end
```

#### Step 5: Generate Documentation

```bash
# Generate Swagger documentation
SWAGGER_DRY_RUN=0 rails rswag:specs:swaggerize

# Start server and visit http://localhost:3000/api-docs
rails server
```

#### Step 6: Mount Swagger UI in Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'

  # ... rest of routes
end
```

---

### Feature 4.3: Rate Limiting

**Estimated Time:** 4 hours

#### Step 1: Create Rate Limiter Service

```ruby
# app/services/rate_limiter.rb
class RateLimiter
  RATE_LIMIT = 1000 # requests per hour
  RATE_LIMIT_WINDOW = 3600 # 1 hour in seconds

  def initialize(api_key)
    @api_key = api_key
    @redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
  end

  def check_limit!
    key = "rate_limit:#{@api_key.id}"
    current_count = @redis.get(key).to_i

    if current_count >= rate_limit
      raise RateLimitExceeded, "Rate limit exceeded. Limit: #{rate_limit} requests per hour"
    end

    # Increment counter
    @redis.multi do |multi|
      multi.incr(key)
      multi.expire(key, RATE_LIMIT_WINDOW) if current_count == 0
    end

    {
      limit: rate_limit,
      remaining: rate_limit - current_count - 1,
      reset_at: Time.current + RATE_LIMIT_WINDOW
    }
  end

  def current_usage
    key = "rate_limit:#{@api_key.id}"
    current_count = @redis.get(key).to_i
    ttl = @redis.ttl(key)

    {
      limit: rate_limit,
      used: current_count,
      remaining: rate_limit - current_count,
      reset_at: ttl > 0 ? Time.current + ttl : Time.current + RATE_LIMIT_WINDOW
    }
  end

  private

  def rate_limit
    @api_key.metadata.dig('rate_limit') || RATE_LIMIT
  end

  class RateLimitExceeded < StandardError; end
end
```

#### Step 2: Create Rate Limiting Middleware

```ruby
# app/middleware/api_rate_limiter.rb
class ApiRateLimiter
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)

    # Only apply to API routes
    if request.path.start_with?('/api/')
      api_key = extract_api_key(request)

      if api_key
        rate_limiter = RateLimiter.new(api_key)

        begin
          rate_info = rate_limiter.check_limit!

          # Add rate limit headers
          status, headers, response = @app.call(env)
          headers['X-RateLimit-Limit'] = rate_info[:limit].to_s
          headers['X-RateLimit-Remaining'] = rate_info[:remaining].to_s
          headers['X-RateLimit-Reset'] = rate_info[:reset_at].to_i.to_s

          [status, headers, response]
        rescue RateLimiter::RateLimitExceeded => e
          [
            429,
            {
              'Content-Type' => 'application/json',
              'Retry-After' => '3600'
            },
            [{ error: e.message }.to_json]
          ]
        end
      else
        @app.call(env)
      end
    else
      @app.call(env)
    end
  end

  private

  def extract_api_key(request)
    token = request.headers['Authorization']&.split(' ')&.last
    ApiKey.authenticate(token) if token
  end
end
```

#### Step 3: Register Middleware

```ruby
# config/application.rb
module GeoPlatform
  class Application < Rails::Application
    # ... existing config

    # Add rate limiting middleware
    config.middleware.use ApiRateLimiter
  end
end
```

#### Step 4: Add Rate Limit Info Endpoint

```ruby
# app/controllers/api/v1/rate_limit_controller.rb
module Api
  module V1
    class RateLimitController < BaseController
      def show
        rate_limiter = RateLimiter.new(@api_key)
        usage = rate_limiter.current_usage

        render json: {
          limit: usage[:limit],
          used: usage[:used],
          remaining: usage[:remaining],
          reset_at: usage[:reset_at].iso8601
        }
      end
    end
  end
end
```

```ruby
# config/routes.rb (add to api/v1 namespace)
namespace :api do
  namespace :v1 do
    resource :rate_limit, only: [:show]
    # ... other routes
  end
end
```

#### Step 5: Create Rate Limiter Tests

```ruby
# spec/services/rate_limiter_spec.rb
require 'rails_helper'

RSpec.describe RateLimiter do
  let(:api_key) { create(:api_key) }
  let(:rate_limiter) { described_class.new(api_key) }

  before do
    # Clear Redis before each test
    Redis.new.flushdb
  end

  describe '#check_limit!' do
    it 'allows requests within limit' do
      expect { rate_limiter.check_limit! }.not_to raise_error
    end

    it 'raises error when limit exceeded' do
      # Make requests up to limit
      1000.times { rate_limiter.check_limit! }

      # Next request should fail
      expect { rate_limiter.check_limit! }.to raise_error(RateLimiter::RateLimitExceeded)
    end

    it 'returns rate limit info' do
      info = rate_limiter.check_limit!

      expect(info[:limit]).to eq(1000)
      expect(info[:remaining]).to eq(999)
      expect(info[:reset_at]).to be_a(Time)
    end
  end

  describe '#current_usage' do
    it 'returns current usage stats' do
      5.times { rate_limiter.check_limit! }

      usage = rate_limiter.current_usage

      expect(usage[:used]).to eq(5)
      expect(usage[:remaining]).to eq(995)
    end
  end
end
```

---

### Feature 4.4: Team Collaboration

**Estimated Time:** 6 hours

#### Step 1: Create Team Member Model

```bash
rails generate model TeamMember \
  workspace:references \
  user:references \
  role:string \
  invited_by:references \
  invited_at:datetime \
  joined_at:datetime
```

```ruby
# db/migrate/XXXXXX_create_team_members.rb
class CreateTeamMembers < ActiveRecord::Migration[7.1]
  def change
    create_table :team_members, id: :uuid do |t|
      t.references :workspace, null: false, foreign_key: true, type: :uuid
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :invited_by, foreign_key: { to_table: :users }, type: :uuid
      t.string :role, null: false, default: 'viewer'
      t.datetime :invited_at
      t.datetime :joined_at
      t.timestamps

      t.index [:workspace_id, :user_id], unique: true
    end
  end
end
```

```ruby
# app/models/team_member.rb
class TeamMember < ApplicationRecord
  belongs_to :workspace
  belongs_to :user
  belongs_to :invited_by, class_name: 'User', optional: true

  ROLES = %w[admin editor viewer].freeze

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :workspace_id }

  scope :active, -> { where.not(joined_at: nil) }
  scope :pending, -> { where(joined_at: nil) }
  scope :admins, -> { where(role: 'admin') }

  def admin?
    role == 'admin'
  end

  def editor?
    role == 'editor'
  end

  def viewer?
    role == 'viewer'
  end

  def can_edit?
    admin? || editor?
  end

  def can_manage_team?
    admin?
  end
end
```

#### Step 2: Update Workspace Model

```ruby
# app/models/workspace.rb (add these associations)
class Workspace < ApplicationRecord
  has_many :team_members, dependent: :destroy
  has_many :users, through: :team_members
  has_many :active_team_members, -> { active }, class_name: 'TeamMember'
  has_many :pending_team_members, -> { pending }, class_name: 'TeamMember'

  def add_member(user, role: 'viewer', invited_by: nil)
    team_members.create!(
      user: user,
      role: role,
      invited_by: invited_by,
      invited_at: Time.current,
      joined_at: Time.current
    )
  end

  def remove_member(user)
    team_members.find_by(user: user)&.destroy
  end

  def member?(user)
    team_members.exists?(user: user)
  end

  def member_role(user)
    team_members.find_by(user: user)&.role
  end
end
```

#### Step 3: Create Team Members Controller

```ruby
# app/controllers/team_members_controller.rb
class TeamMembersController < ApplicationController
  before_action :require_authentication
  before_action :set_workspace
  before_action :require_admin, except: [:index]
  before_action :set_team_member, only: [:update, :destroy]

  def index
    @team_members = @workspace.team_members
                              .includes(:user, :invited_by)
                              .order(created_at: :desc)
    @pending_invitations = @workspace.pending_team_members
  end

  def create
    user = User.find_by(email: team_member_params[:email])

    if user.nil?
      # Send invitation email to new user
      user = User.create!(
        email: team_member_params[:email],
        password: SecureRandom.hex(16),
        first_name: team_member_params[:first_name],
        last_name: team_member_params[:last_name]
      )

      UserMailer.team_invitation(user, @workspace, current_user).deliver_later
    end

    @team_member = @workspace.team_members.build(
      user: user,
      role: team_member_params[:role],
      invited_by: current_user,
      invited_at: Time.current
    )

    if @team_member.save
      UserMailer.team_member_added(@team_member).deliver_later unless user.new_record?
      redirect_to workspace_team_members_path(@workspace), notice: 'Team member invited successfully.'
    else
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @team_member.update(role: team_member_params[:role])
      redirect_to workspace_team_members_path(@workspace), notice: 'Role updated successfully.'
    else
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    # Prevent removing the last admin
    if @team_member.admin? && @workspace.team_members.admins.count == 1
      redirect_to workspace_team_members_path(@workspace),
                  alert: 'Cannot remove the last admin.'
      return
    end

    @team_member.destroy
    redirect_to workspace_team_members_path(@workspace), notice: 'Team member removed.'
  end

  private

  def set_workspace
    @workspace = current_user.workspaces.find(params[:workspace_id])
  end

  def set_team_member
    @team_member = @workspace.team_members.find(params[:id])
  end

  def require_admin
    team_member = @workspace.team_members.find_by(user: current_user)

    unless team_member&.admin?
      redirect_to workspace_path(@workspace), alert: 'You must be an admin to perform this action.'
    end
  end

  def team_member_params
    params.require(:team_member).permit(:email, :first_name, :last_name, :role)
  end
end
```

#### Step 4: Create Team Members View

```erb
<!-- app/views/team_members/index.html.erb -->
<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
  <div class="md:flex md:items-center md:justify-between mb-8">
    <div class="flex-1 min-w-0">
      <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:text-3xl sm:truncate">
        Team Members
      </h2>
    </div>
    <div class="mt-4 flex md:mt-0 md:ml-4">
      <button type="button"
              onclick="document.getElementById('invite-modal').classList.remove('hidden')"
              class="ml-3 inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700">
        Invite Member
      </button>
    </div>
  </div>

  <!-- Active Members -->
  <div class="bg-white shadow overflow-hidden sm:rounded-md mb-8">
    <ul role="list" class="divide-y divide-gray-200">
      <% @team_members.active.each do |team_member| %>
        <li>
          <div class="px-4 py-4 flex items-center sm:px-6">
            <div class="min-w-0 flex-1 sm:flex sm:items-center sm:justify-between">
              <div class="truncate">
                <div class="flex text-sm">
                  <p class="font-medium text-indigo-600 truncate">
                    <%= team_member.user.full_name %>
                  </p>
                  <p class="ml-1 flex-shrink-0 font-normal text-gray-500">
                    <%= team_member.user.email %>
                  </p>
                </div>
                <div class="mt-2 flex">
                  <div class="flex items-center text-sm text-gray-500">
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-<%= role_color(team_member.role) %>-100 text-<%= role_color(team_member.role) %>-800">
                      <%= team_member.role.titleize %>
                    </span>
                  </div>
                </div>
              </div>
              <div class="mt-4 flex-shrink-0 sm:mt-0 sm:ml-5">
                <% if current_user_admin? %>
                  <%= form_with model: team_member,
                                url: workspace_team_member_path(@workspace, team_member),
                                method: :patch,
                                class: "inline-block mr-2" do |f| %>
                    <%= f.select :role,
                                TeamMember::ROLES,
                                {},
                                class: "rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm",
                                onchange: "this.form.submit()" %>
                  <% end %>

                  <%= button_to "Remove",
                                workspace_team_member_path(@workspace, team_member),
                                method: :delete,
                                data: { confirm: "Are you sure?" },
                                class: "inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50" %>
                <% end %>
              </div>
            </div>
          </div>
        </li>
      <% end %>
    </ul>
  </div>

  <!-- Pending Invitations -->
  <% if @pending_invitations.any? %>
    <h3 class="text-lg font-medium text-gray-900 mb-4">Pending Invitations</h3>
    <div class="bg-white shadow overflow-hidden sm:rounded-md">
      <ul role="list" class="divide-y divide-gray-200">
        <% @pending_invitations.each do |team_member| %>
          <li class="px-4 py-4 sm:px-6">
            <div class="flex items-center justify-between">
              <p class="text-sm font-medium text-gray-900">
                <%= team_member.user.email %>
              </p>
              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                Pending
              </span>
            </div>
          </li>
        <% end %>
      </ul>
    </div>
  <% end %>
</div>

<!-- Invite Modal -->
<div id="invite-modal" class="hidden fixed z-10 inset-0 overflow-y-auto">
  <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
    <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"></div>

    <div class="inline-block align-bottom bg-white rounded-lg px-4 pt-5 pb-4 text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full sm:p-6">
      <%= form_with model: TeamMember.new,
                    url: workspace_team_members_path(@workspace),
                    class: "space-y-4" do |f| %>
        <h3 class="text-lg font-medium text-gray-900 mb-4">Invite Team Member</h3>

        <div>
          <%= f.label :email, class: "block text-sm font-medium text-gray-700" %>
          <%= f.email_field :email,
                           required: true,
                           class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" %>
        </div>

        <div>
          <%= f.label :role, class: "block text-sm font-medium text-gray-700" %>
          <%= f.select :role,
                      TeamMember::ROLES.map { |r| [r.titleize, r] },
                      {},
                      class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" %>
        </div>

        <div class="mt-5 sm:mt-6 sm:grid sm:grid-cols-2 sm:gap-3 sm:grid-flow-row-dense">
          <%= f.submit "Send Invitation",
                      class: "w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-indigo-600 text-base font-medium text-white hover:bg-indigo-700 sm:col-start-2 sm:text-sm" %>
          <button type="button"
                  onclick="document.getElementById('invite-modal').classList.add('hidden')"
                  class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 sm:mt-0 sm:col-start-1 sm:text-sm">
            Cancel
          </button>
        </div>
      <% end %>
    </div>
  </div>
</div>

<% content_for :helpers do %>
  <% def role_color(role)
    case role
    when 'admin' then 'purple'
    when 'editor' then 'blue'
    when 'viewer' then 'gray'
    end
  end %>

  <% def current_user_admin?
    @workspace.team_members.find_by(user: current_user)&.admin?
  end %>
<% end %>
```

#### Step 5: Add Routes

```ruby
# config/routes.rb
resources :workspaces do
  resources :team_members, only: [:index, :create, :update, :destroy]
end
```

#### Step 6: Create Team Member Tests

```ruby
# spec/requests/team_members_spec.rb
require 'rails_helper'

RSpec.describe 'TeamMembers', type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace) }
  let!(:admin_member) { create(:team_member, workspace: workspace, user: user, role: 'admin') }

  before { sign_in user }

  describe 'GET /workspaces/:workspace_id/team_members' do
    it 'displays team members' do
      get workspace_team_members_path(workspace)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /workspaces/:workspace_id/team_members' do
    let(:new_user) { create(:user) }
    let(:valid_params) do
      {
        team_member: {
          email: new_user.email,
          role: 'editor'
        }
      }
    end

    it 'adds a new team member' do
      expect {
        post workspace_team_members_path(workspace), params: valid_params
      }.to change(TeamMember, :count).by(1)
    end

    it 'sends invitation email' do
      expect {
        post workspace_team_members_path(workspace), params: valid_params
      }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
    end
  end

  describe 'DELETE /workspaces/:workspace_id/team_members/:id' do
    let(:member_to_remove) { create(:team_member, workspace: workspace, role: 'viewer') }

    it 'removes team member' do
      expect {
        delete workspace_team_member_path(workspace, member_to_remove)
      }.to change(TeamMember, :count).by(-1)
    end

    it 'prevents removing last admin' do
      delete workspace_team_member_path(workspace, admin_member)
      expect(response).to redirect_to(workspace_team_members_path(workspace))
      expect(flash[:alert]).to include('last admin')
    end
  end
end
```

---

### Feature 4.5: Email Notifications

**Estimated Time:** 6 hours

#### Step 1: Configure Action Mailer

```ruby
# config/environments/development.rb
config.action_mailer.delivery_method = :letter_opener
config.action_mailer.perform_deliveries = true
config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
```

```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :smtp
config.action_mailer.perform_deliveries = true
config.action_mailer.default_url_options = { host: ENV['APP_HOST'] }

config.action_mailer.smtp_settings = {
  address: 'smtp.sendgrid.net',
  port: 587,
  domain: ENV['APP_HOST'],
  user_name: 'apikey',
  password: ENV['SENDGRID_API_KEY'],
  authentication: :plain,
  enable_starttls_auto: true
}
```

#### Step 2: Create User Mailer

```ruby
# app/mailers/user_mailer.rb
class UserMailer < ApplicationMailer
  default from: 'noreply@geoplatform.com'

  def confirmation_email(user)
    @user = user
    @confirmation_url = confirm_email_url(token: user.confirmation_token)

    mail(
      to: @user.email,
      subject: 'Confirm your GEO Platform account'
    )
  end

  def password_reset(user)
    @user = user
    @reset_url = reset_password_url(token: user.reset_password_token)

    mail(
      to: @user.email,
      subject: 'Reset your password'
    )
  end

  def team_invitation(user, workspace, invited_by)
    @user = user
    @workspace = workspace
    @invited_by = invited_by
    @accept_url = accept_invitation_url(token: user.confirmation_token, workspace_id: workspace.id)

    mail(
      to: @user.email,
      subject: "#{invited_by.full_name} invited you to join #{workspace.name}"
    )
  end

  def team_member_added(team_member)
    @team_member = team_member
    @workspace = team_member.workspace
    @workspace_url = workspace_url(@workspace)

    mail(
      to: @team_member.user.email,
      subject: "You've been added to #{@workspace.name}"
    )
  end
end
```

#### Step 3: Create Alert Mailer

```ruby
# app/mailers/alert_mailer.rb
class AlertMailer < ApplicationMailer
  default from: 'alerts@geoplatform.com'

  def negative_sentiment_alert(workspace, brand, mentions)
    @workspace = workspace
    @brand = brand
    @mentions = mentions
    @dashboard_url = workspace_brand_url(@workspace, @brand)

    # Send to all admin and editor team members
    recipients = @workspace.team_members
                          .where(role: ['admin', 'editor'])
                          .includes(:user)
                          .map { |tm| tm.user.email }

    mail(
      to: recipients,
      subject: "Alert: Negative sentiment spike for #{@brand.name}"
    )
  end

  def mention_volume_alert(workspace, brand, count, period)
    @workspace = workspace
    @brand = brand
    @count = count
    @period = period
    @dashboard_url = workspace_brand_url(@workspace, @brand)

    recipients = @workspace.team_members
                          .where(role: ['admin', 'editor'])
                          .includes(:user)
                          .map { |tm| tm.user.email }

    mail(
      to: recipients,
      subject: "Alert: High mention volume for #{@brand.name}"
    )
  end

  def weekly_summary(workspace, user)
    @workspace = workspace
    @user = user
    @start_date = 1.week.ago
    @end_date = Time.current

    # Gather weekly stats
    @total_mentions = @workspace.mentions.where('created_at >= ?', @start_date).count
    @top_brands = @workspace.brands
                           .joins(:mentions)
                           .where('mentions.created_at >= ?', @start_date)
                           .group('brands.id')
                           .order('COUNT(mentions.id) DESC')
                           .limit(5)

    mail(
      to: @user.email,
      subject: "Your weekly GEO Platform summary"
    )
  end
end
```

#### Step 4: Create Email Templates

```erb
<!-- app/views/user_mailer/confirmation_email.html.erb -->
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .button {
      display: inline-block;
      padding: 12px 24px;
      background-color: #4F46E5;
      color: white;
      text-decoration: none;
      border-radius: 6px;
      margin: 20px 0;
    }
    .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #e5e7eb; color: #6b7280; font-size: 14px; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Welcome to GEO Platform!</h1>

    <p>Hi <%= @user.first_name || 'there' %>,</p>

    <p>Thanks for signing up! Please confirm your email address to get started.</p>

    <a href="<%= @confirmation_url %>" class="button">Confirm Email Address</a>

    <p>Or copy and paste this URL into your browser:</p>
    <p><%= @confirmation_url %></p>

    <div class="footer">
      <p>If you didn't create an account, you can safely ignore this email.</p>
      <p>&copy; <%= Time.current.year %> GEO Platform. All rights reserved.</p>
    </div>
  </div>
</body>
</html>
```

```erb
<!-- app/views/alert_mailer/negative_sentiment_alert.html.erb -->
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .alert-box { background-color: #FEF2F2; border-left: 4px solid #EF4444; padding: 16px; margin: 20px 0; }
    .mention { background-color: #F9FAFB; padding: 12px; margin: 10px 0; border-radius: 6px; }
    .button {
      display: inline-block;
      padding: 12px 24px;
      background-color: #4F46E5;
      color: white;
      text-decoration: none;
      border-radius: 6px;
      margin: 20px 0;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>⚠️ Negative Sentiment Alert</h1>

    <div class="alert-box">
      <strong>Brand:</strong> <%= @brand.name %><br>
      <strong>Negative mentions:</strong> <%= @mentions.count %>
    </div>

    <p>We've detected a spike in negative sentiment for <%= @brand.name %>. Here are the recent mentions:</p>

    <% @mentions.first(5).each do |mention| %>
      <div class="mention">
        <strong><%= mention.source.name %></strong> - <%= mention.published_at.strftime('%B %d, %Y') %><br>
        <%= truncate(mention.content, length: 200) %>
      </div>
    <% end %>

    <a href="<%= @dashboard_url %>" class="button">View Full Details</a>
  </div>
</body>
</html>
```

#### Step 5: Create Alert Job

```ruby
# app/jobs/sentiment_alert_job.rb
class SentimentAlertJob < ApplicationJob
  queue_as :monitoring

  def perform(brand_id)
    brand = Brand.find(brand_id)
    workspace = brand.workspace

    # Check for negative sentiment spike in last 24 hours
    recent_mentions = brand.mentions
                          .where('published_at >= ?', 24.hours.ago)
                          .where(sentiment: 'negative')

    # Alert if more than 5 negative mentions
    if recent_mentions.count >= 5
      AlertMailer.negative_sentiment_alert(workspace, brand, recent_mentions).deliver_now
    end
  end
end
```

#### Step 6: Create Mailer Tests

```ruby
# spec/mailers/user_mailer_spec.rb
require 'rails_helper'

RSpec.describe UserMailer, type: :mailer do
  describe 'confirmation_email' do
    let(:user) { create(:user, confirmation_token: 'abc123') }
    let(:mail) { UserMailer.confirmation_email(user) }

    it 'renders the headers' do
      expect(mail.subject).to eq('Confirm your GEO Platform account')
      expect(mail.to).to eq([user.email])
      expect(mail.from).to eq(['noreply@geoplatform.com'])
    end

    it 'includes confirmation link' do
      expect(mail.body.encoded).to include('Confirm Email Address')
      expect(mail.body.encoded).to include(user.confirmation_token)
    end
  end

  describe 'password_reset' do
    let(:user) { create(:user, reset_password_token: 'reset123') }
    let(:mail) { UserMailer.password_reset(user) }

    it 'renders the headers' do
      expect(mail.subject).to eq('Reset your password')
      expect(mail.to).to eq([user.email])
    end

    it 'includes reset link' do
      expect(mail.body.encoded).to include(user.reset_password_token)
    end
  end
end
```

---

## Week 12: Reports, Settings & Deployment

### Feature 4.6: Custom Reports

**Estimated Time:** 8 hours

#### Step 1: Install Report Dependencies

```ruby
# Gemfile
gem 'prawn', '~> 2.4'
gem 'prawn-table', '~> 0.2'
gem 'grover', '~> 1.1' # HTML to PDF using Puppeteer
```

```bash
bundle install
```

#### Step 2: Create Report Model

```bash
rails generate model Report \
  workspace:references \
  user:references \
  name:string \
  report_type:string \
  parameters:jsonb \
  scheduled:boolean \
  schedule_frequency:string \
  last_generated_at:datetime
```

```ruby
# db/migrate/XXXXXX_create_reports.rb
class CreateReports < ActiveRecord::Migration[7.1]
  def change
    create_table :reports, id: :uuid do |t|
      t.references :workspace, null: false, foreign_key: true, type: :uuid
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :report_type, null: false
      t.jsonb :parameters, default: {}
      t.boolean :scheduled, default: false
      t.string :schedule_frequency
      t.datetime :last_generated_at
      t.timestamps

      t.index :report_type
      t.index :scheduled
    end
  end
end
```

```ruby
# app/models/report.rb
class Report < ApplicationRecord
  belongs_to :workspace
  belongs_to :user

  REPORT_TYPES = %w[brand_performance sentiment_analysis mention_summary visibility_trends].freeze
  FREQUENCIES = %w[daily weekly monthly].freeze

  validates :name, presence: true
  validates :report_type, presence: true, inclusion: { in: REPORT_TYPES }
  validates :schedule_frequency, inclusion: { in: FREQUENCIES }, if: :scheduled?

  scope :scheduled, -> { where(scheduled: true) }

  def generate_pdf
    case report_type
    when 'brand_performance'
      BrandPerformanceReportGenerator.new(self).generate_pdf
    when 'sentiment_analysis'
      SentimentAnalysisReportGenerator.new(self).generate_pdf
    when 'mention_summary'
      MentionSummaryReportGenerator.new(self).generate_pdf
    when 'visibility_trends'
      VisibilityTrendsReportGenerator.new(self).generate_pdf
    end
  end

  def generate_csv
    case report_type
    when 'brand_performance'
      BrandPerformanceReportGenerator.new(self).generate_csv
    when 'mention_summary'
      MentionSummaryReportGenerator.new(self).generate_csv
    end
  end
end
```

#### Step 3: Create Report Generator Service

```ruby
# app/services/brand_performance_report_generator.rb
class BrandPerformanceReportGenerator
  def initialize(report)
    @report = report
    @workspace = report.workspace
    @start_date = report.parameters['start_date']&.to_date || 30.days.ago
    @end_date = report.parameters['end_date']&.to_date || Date.current
  end

  def generate_pdf
    Prawn::Document.new do |pdf|
      # Header
      pdf.text "Brand Performance Report", size: 24, style: :bold
      pdf.text @workspace.name, size: 16
      pdf.text "Period: #{@start_date.strftime('%B %d, %Y')} - #{@end_date.strftime('%B %d, %Y')}", size: 12
      pdf.move_down 20

      # Summary
      pdf.text "Summary", size: 18, style: :bold
      pdf.move_down 10

      summary_data = [
        ["Total Brands", @workspace.brands.count],
        ["Total Mentions", mentions.count],
        ["Average Sentiment", average_sentiment],
        ["Top Brand", top_brand&.name || 'N/A']
      ]

      pdf.table(summary_data, width: pdf.bounds.width) do
        row(0..3).font_style = :bold
        cells.padding = 12
        cells.borders = [:bottom]
      end

      pdf.move_down 20

      # Brand Details
      pdf.text "Brand Performance", size: 18, style: :bold
      pdf.move_down 10

      @workspace.brands.each do |brand|
        brand_mentions = brand.mentions.where(published_at: @start_date..@end_date)

        pdf.text brand.name, size: 14, style: :bold
        pdf.move_down 5

        brand_data = [
          ["Mentions", brand_mentions.count],
          ["Positive", brand_mentions.where(sentiment: 'positive').count],
          ["Neutral", brand_mentions.where(sentiment: 'neutral').count],
          ["Negative", brand_mentions.where(sentiment: 'negative').count],
          ["Avg Score", brand_mentions.average(:sentiment_score)&.round(2) || 'N/A']
        ]

        pdf.table(brand_data, width: pdf.bounds.width / 2)
        pdf.move_down 15
      end

      # Footer
      pdf.number_pages "Page <page> of <total>", at: [pdf.bounds.right - 150, 0]
    end.render
  end

  def generate_csv
    require 'csv'

    CSV.generate(headers: true) do |csv|
      csv << ['Brand', 'Total Mentions', 'Positive', 'Neutral', 'Negative', 'Avg Sentiment Score']

      @workspace.brands.each do |brand|
        brand_mentions = brand.mentions.where(published_at: @start_date..@end_date)

        csv << [
          brand.name,
          brand_mentions.count,
          brand_mentions.where(sentiment: 'positive').count,
          brand_mentions.where(sentiment: 'neutral').count,
          brand_mentions.where(sentiment: 'negative').count,
          brand_mentions.average(:sentiment_score)&.round(2)
        ]
      end
    end
  end

  private

  def mentions
    @mentions ||= @workspace.mentions.where(published_at: @start_date..@end_date)
  end

  def average_sentiment
    mentions.average(:sentiment_score)&.round(2) || 0
  end

  def top_brand
    @workspace.brands
              .joins(:mentions)
              .where('mentions.published_at >= ? AND mentions.published_at <= ?', @start_date, @end_date)
              .group('brands.id')
              .order('COUNT(mentions.id) DESC')
              .first
  end
end
```

#### Step 4: Create Reports Controller

```ruby
# app/controllers/reports_controller.rb
class ReportsController < ApplicationController
  before_action :require_authentication
  before_action :set_workspace
  before_action :set_report, only: [:show, :edit, :update, :destroy, :download]

  def index
    @reports = @workspace.reports.order(created_at: :desc)
  end

  def new
    @report = @workspace.reports.build
  end

  def create
    @report = @workspace.reports.build(report_params)
    @report.user = current_user

    if @report.save
      redirect_to workspace_reports_path(@workspace), notice: 'Report created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    # Preview report
  end

  def download
    format = params[:format] || 'pdf'

    case format
    when 'pdf'
      pdf = @report.generate_pdf
      send_data pdf,
                filename: "#{@report.name.parameterize}-#{Date.current}.pdf",
                type: 'application/pdf',
                disposition: 'attachment'
    when 'csv'
      csv = @report.generate_csv
      send_data csv,
                filename: "#{@report.name.parameterize}-#{Date.current}.csv",
                type: 'text/csv',
                disposition: 'attachment'
    end

    @report.update(last_generated_at: Time.current)
  end

  def destroy
    @report.destroy
    redirect_to workspace_reports_path(@workspace), notice: 'Report deleted.'
  end

  private

  def set_workspace
    @workspace = current_user.workspaces.find(params[:workspace_id])
  end

  def set_report
    @report = @workspace.reports.find(params[:id])
  end

  def report_params
    params.require(:report).permit(
      :name,
      :report_type,
      :scheduled,
      :schedule_frequency,
      parameters: [:start_date, :end_date, :brand_ids]
    )
  end
end
```

#### Step 5: Create Scheduled Report Job

```ruby
# app/jobs/generate_scheduled_reports_job.rb
class GenerateScheduledReportsJob < ApplicationJob
  queue_as :default

  def perform
    Report.scheduled.find_each do |report|
      next unless should_generate?(report)

      # Generate and email report
      pdf = report.generate_pdf

      ReportMailer.scheduled_report(
        report.user,
        report,
        pdf
      ).deliver_now

      report.update(last_generated_at: Time.current)
    end
  end

  private

  def should_generate?(report)
    return true if report.last_generated_at.nil?

    case report.schedule_frequency
    when 'daily'
      report.last_generated_at < 1.day.ago
    when 'weekly'
      report.last_generated_at < 1.week.ago
    when 'monthly'
      report.last_generated_at < 1.month.ago
    end
  end
end
```

```ruby
# config/schedule.rb (using whenever gem or similar)
every 1.day, at: '6:00 am' do
  runner "GenerateScheduledReportsJob.perform_later"
end
```

---

### Feature 4.7: Settings & Preferences

**Estimated Time:** 4 hours

#### Step 1: Create Settings Controller

```ruby
# app/controllers/settings_controller.rb
class SettingsController < ApplicationController
  before_action :require_authentication
  before_action :set_workspace

  def show
    @workspace_settings = @workspace
    @user_preferences = current_user.preferences || {}
  end

  def update_workspace
    if @workspace.update(workspace_params)
      redirect_to workspace_settings_path(@workspace), notice: 'Workspace settings updated.'
    else
      render :show, status: :unprocessable_entity
    end
  end

  def update_preferences
    current_user.update(preferences: user_preference_params)
    redirect_to workspace_settings_path(@workspace), notice: 'Preferences updated.'
  end

  private

  def set_workspace
    @workspace = current_user.workspaces.find(params[:workspace_id])
  end

  def workspace_params
    params.require(:workspace).permit(
      :name,
      :timezone,
      :notification_email,
      settings: [
        :enable_email_alerts,
        :alert_threshold,
        :weekly_summary,
        :mention_notifications
      ]
    )
  end

  def user_preference_params
    params.require(:preferences).permit(
      :theme,
      :items_per_page,
      :default_date_range,
      :email_frequency
    )
  end
end
```

#### Step 2: Add Settings to Workspace Model

```ruby
# db/migrate/XXXXXX_add_settings_to_workspaces.rb
class AddSettingsToWorkspaces < ActiveRecord::Migration[7.1]
  def change
    add_column :workspaces, :timezone, :string, default: 'UTC'
    add_column :workspaces, :notification_email, :string
    add_column :workspaces, :settings, :jsonb, default: {}

    add_index :workspaces, :settings, using: :gin
  end
end
```

```ruby
# db/migrate/XXXXXX_add_preferences_to_users.rb
class AddPreferencesToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :preferences, :jsonb, default: {}

    add_index :users, :preferences, using: :gin
  end
end
```

#### Step 3: Create Settings View

```erb
<!-- app/views/settings/show.html.erb -->
<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
  <h1 class="text-3xl font-bold text-gray-900 mb-8">Settings</h1>

  <!-- Workspace Settings -->
  <div class="bg-white shadow sm:rounded-lg mb-8">
    <div class="px-4 py-5 sm:p-6">
      <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
        Workspace Settings
      </h3>

      <%= form_with model: @workspace,
                    url: update_workspace_workspace_settings_path(@workspace),
                    method: :patch,
                    class: "space-y-6" do |f| %>

        <div>
          <%= f.label :name, "Workspace Name", class: "block text-sm font-medium text-gray-700" %>
          <%= f.text_field :name,
                          class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" %>
        </div>

        <div>
          <%= f.label :timezone, class: "block text-sm font-medium text-gray-700" %>
          <%= f.select :timezone,
                      ActiveSupport::TimeZone.all.map { |tz| [tz.name, tz.name] },
                      {},
                      class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" %>
        </div>

        <div>
          <%= f.label :notification_email, "Notification Email", class: "block text-sm font-medium text-gray-700" %>
          <%= f.email_field :notification_email,
                           class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" %>
          <p class="mt-2 text-sm text-gray-500">Leave blank to use your account email</p>
        </div>

        <div class="border-t border-gray-200 pt-6">
          <h4 class="text-base font-medium text-gray-900 mb-4">Notification Settings</h4>

          <div class="space-y-4">
            <%= f.fields_for :settings do |settings_form| %>
              <div class="flex items-start">
                <div class="flex items-center h-5">
                  <%= settings_form.check_box :enable_email_alerts,
                                             class: "focus:ring-indigo-500 h-4 w-4 text-indigo-600 border-gray-300 rounded" %>
                </div>
                <div class="ml-3 text-sm">
                  <%= settings_form.label :enable_email_alerts, "Enable email alerts", class: "font-medium text-gray-700" %>
                  <p class="text-gray-500">Receive email notifications for important events</p>
                </div>
              </div>

              <div class="flex items-start">
                <div class="flex items-center h-5">
                  <%= settings_form.check_box :weekly_summary,
                                             class: "focus:ring-indigo-500 h-4 w-4 text-indigo-600 border-gray-300 rounded" %>
                </div>
                <div class="ml-3 text-sm">
                  <%= settings_form.label :weekly_summary, "Weekly summary email", class: "font-medium text-gray-700" %>
                  <p class="text-gray-500">Receive a weekly summary of your workspace activity</p>
                </div>
              </div>

              <div class="flex items-start">
                <div class="flex items-center h-5">
                  <%= settings_form.check_box :mention_notifications,
                                             class: "focus:ring-indigo-500 h-4 w-4 text-indigo-600 border-gray-300 rounded" %>
                </div>
                <div class="ml-3 text-sm">
                  <%= settings_form.label :mention_notifications, "New mention notifications", class: "font-medium text-gray-700" %>
                  <p class="text-gray-500">Get notified when new mentions are detected</p>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <div class="flex justify-end">
          <%= f.submit "Save Workspace Settings",
                      class: "inline-flex justify-center py-2 px-4 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500" %>
        </div>
      <% end %>
    </div>
  </div>

  <!-- User Preferences -->
  <div class="bg-white shadow sm:rounded-lg">
    <div class="px-4 py-5 sm:p-6">
      <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
        Your Preferences
      </h3>

      <%= form_with url: update_preferences_workspace_settings_path(@workspace),
                    method: :patch,
                    class: "space-y-6" do |f| %>

        <%= f.fields_for :preferences do |pref_form| %>
          <div>
            <%= pref_form.label :theme, class: "block text-sm font-medium text-gray-700" %>
            <%= pref_form.select :theme,
                                [['Light', 'light'], ['Dark', 'dark'], ['Auto', 'auto']],
                                { selected: @user_preferences['theme'] || 'light' },
                                class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" %>
          </div>

          <div>
            <%= pref_form.label :items_per_page, "Items per page", class: "block text-sm font-medium text-gray-700" %>
            <%= pref_form.select :items_per_page,
                                [10, 25, 50, 100],
                                { selected: @user_preferences['items_per_page'] || 25 },
                                class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" %>
          </div>

          <div>
            <%= pref_form.label :default_date_range, class: "block text-sm font-medium text-gray-700" %>
            <%= pref_form.select :default_date_range,
                                [['Last 7 days', '7'], ['Last 30 days', '30'], ['Last 90 days', '90']],
                                { selected: @user_preferences['default_date_range'] || '30' },
                                class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" %>
          </div>
        <% end %>

        <div class="flex justify-end">
          <%= f.submit "Save Preferences",
                      class: "inline-flex justify-center py-2 px-4 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500" %>
        </div>
      <% end %>
    </div>
  </div>
</div>
```

#### Step 4: Add Routes

```ruby
# config/routes.rb
resources :workspaces do
  resource :settings, only: [:show] do
    patch :update_workspace
    patch :update_preferences
  end
end
```

---

### Feature 4.8: Performance Optimization

**Estimated Time:** 6 hours

#### Step 1: Database Query Optimization

```ruby
# db/migrate/XXXXXX_add_performance_indexes.rb
class AddPerformanceIndexes < ActiveRecord::Migration[7.1]
  def change
    # Mentions indexes
    add_index :mentions, [:workspace_id, :published_at]
    add_index :mentions, [:brand_id, :published_at]
    add_index :mentions, [:workspace_id, :sentiment]
    add_index :mentions, [:workspace_id, :created_at]

    # Visibility scores indexes
    add_index :visibility_scores, [:brand_id, :date]
    add_index :visibility_scores, [:workspace_id, :date]

    # Brands indexes
    add_index :brands, [:workspace_id, :created_at]
    add_index :brands, [:workspace_id, :category_id]

    # Sources indexes
    add_index :sources, [:workspace_id, :source_type]

    # Composite indexes for common queries
    add_index :mentions, [:workspace_id, :brand_id, :published_at],
              name: 'index_mentions_on_workspace_brand_date'
    add_index :mentions, [:workspace_id, :sentiment, :published_at],
              name: 'index_mentions_on_workspace_sentiment_date'
  end
end
```

#### Step 2: Add Database Constraints

```ruby
# db/migrate/XXXXXX_add_database_constraints.rb
class AddDatabaseConstraints < ActiveRecord::Migration[7.1]
  def change
    # Add check constraints
    add_check_constraint :mentions,
                        "sentiment_score >= -1 AND sentiment_score <= 1",
                        name: "sentiment_score_range"

    add_check_constraint :visibility_scores,
                        "score >= 0 AND score <= 100",
                        name: "visibility_score_range"

    # Add foreign key constraints if missing
    add_foreign_key :mentions, :workspaces, on_delete: :cascade
    add_foreign_key :brands, :workspaces, on_delete: :cascade
    add_foreign_key :visibility_scores, :workspaces, on_delete: :cascade
  end
end
```

#### Step 3: Implement Fragment Caching

```ruby
# app/views/dashboard/index.html.erb (add caching)
<% cache(['dashboard', @workspace, @workspace.updated_at]) do %>
  <!-- Dashboard content -->
<% end %>

<% cache(['recent_mentions', @workspace, @workspace.mentions.maximum(:updated_at)]) do %>
  <!-- Recent mentions list -->
<% end %>
```

```ruby
# app/views/brands/show.html.erb
<% cache(['brand_show', @brand, @brand.updated_at]) do %>
  <!-- Brand details -->
<% end %>

<% cache(['brand_mentions', @brand, @brand.mentions.maximum(:updated_at)]) do %>
  <!-- Brand mentions -->
<% end %>

<% cache(['brand_chart', @brand, @date_range]) do %>
  <!-- Visibility chart -->
<% end %>
```

#### Step 4: Implement Russian Doll Caching

```ruby
# app/views/brands/index.html.erb
<% cache(['brands_index', @workspace, @workspace.brands.maximum(:updated_at)]) do %>
  <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
    <% @brands.each do |brand| %>
      <% cache(['brand_card', brand]) do %>
        <%= render 'brand_card', brand: brand %>
      <% end %>
    <% end %>
  </div>
<% end %>
```

```ruby
# app/models/brand.rb (add touch: true to associations)
class Brand < ApplicationRecord
  belongs_to :workspace, touch: true
  has_many :mentions, dependent: :destroy, touch: true
  has_many :visibility_scores, dependent: :destroy, touch: true
end
```

#### Step 5: Optimize N+1 Queries

```ruby
# app/controllers/brands_controller.rb
def index
  @brands = @workspace.brands
                     .includes(:category, :latest_visibility_score)
                     .with_mention_counts
                     .order(created_at: :desc)
end

def show
  @brand = @workspace.brands
                    .includes(:category, visibility_scores: :workspace)
                    .find(params[:id])

  @recent_mentions = @brand.mentions
                           .includes(:source)
                           .order(published_at: :desc)
                           .limit(10)
end
```

```ruby
# app/models/brand.rb (add scopes)
class Brand < ApplicationRecord
  scope :with_mention_counts, -> {
    left_joins(:mentions)
      .select('brands.*, COUNT(mentions.id) as mentions_count')
      .group('brands.id')
  }

  scope :with_latest_score, -> {
    joins("LEFT JOIN LATERAL (
      SELECT score
      FROM visibility_scores
      WHERE visibility_scores.brand_id = brands.id
      ORDER BY date DESC
      LIMIT 1
    ) latest_score ON true")
      .select('brands.*, latest_score.score as latest_score')
  }
end
```

#### Step 6: Configure Bullet Gem

```ruby
# config/environments/development.rb
config.after_initialize do
  Bullet.enable = true
  Bullet.alert = true
  Bullet.bullet_logger = true
  Bullet.console = true
  Bullet.rails_logger = true
  Bullet.add_footer = true
end
```

#### Step 7: Add Database Connection Pooling

```ruby
# config/database.yml
production:
  <<: *default
  url: <%= ENV['DATABASE_URL'] %>
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 25 } %>
  prepared_statements: true
  advisory_locks: true

  # Connection pooling with PgBouncer
  # If using PgBouncer, set prepared_statements to false
  # prepared_statements: false
```

#### Step 8: Implement Low-Level Caching

```ruby
# app/models/workspace.rb
class Workspace < ApplicationRecord
  def mention_stats(date_range = 30.days)
    Rails.cache.fetch("workspace_#{id}_mention_stats_#{date_range}", expires_in: 1.hour) do
      {
        total: mentions.where('published_at >= ?', date_range.ago).count,
        by_sentiment: mentions.where('published_at >= ?', date_range.ago).group(:sentiment).count,
        by_day: mentions.where('published_at >= ?', date_range.ago)
                       .group_by_day(:published_at)
                       .count
      }
    end
  end

  def top_brands(limit = 5)
    Rails.cache.fetch("workspace_#{id}_top_brands_#{limit}", expires_in: 30.minutes) do
      brands.joins(:mentions)
            .where('mentions.published_at >= ?', 30.days.ago)
            .group('brands.id')
            .order('COUNT(mentions.id) DESC')
            .limit(limit)
            .pluck(:name, 'COUNT(mentions.id)')
    end
  end
end
```

#### Step 9: Background Job Optimization

```ruby
# config/sidekiq.yml
:concurrency: 10

:queues:
  - [critical, 10]
  - [default, 5]
  - [monitoring, 3]
  - [analysis, 2]
  - [low, 1]

production:
  :concurrency: 25

# Enable job batching
:batch_size: 100
```

```ruby
# app/jobs/bulk_mention_analysis_job.rb
class BulkMentionAnalysisJob < ApplicationJob
  queue_as :analysis

  def perform(mention_ids)
    # Process in batches to avoid memory issues
    Mention.where(id: mention_ids).find_in_batches(batch_size: 100) do |batch|
      batch.each do |mention|
        AnalyzeMentionSentimentJob.perform_later(mention.id)
      end
    end
  end
end
```

---

### Feature 4.9: Production Deployment

**Estimated Time:** 8 hours

#### Step 1: Prepare for Deployment

```ruby
# config/environments/production.rb
Rails.application.configure do
  config.cache_classes = true
  config.eager_load = true
  config.consider_all_requests_local = false
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?

  # Asset compilation
  config.assets.compile = false
  config.assets.digest = true

  # Logging
  config.log_level = :info
  config.log_tags = [:request_id]

  # Force SSL
  config.force_ssl = true
  config.ssl_options = { redirect: { exclude: -> request { request.path =~ /health/ } } }

  # Active Storage
  config.active_storage.service = :amazon

  # Action Mailer
  config.action_mailer.perform_caching = false
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.default_url_options = { host: ENV['APP_HOST'], protocol: 'https' }

  # Active Job
  config.active_job.queue_adapter = :sidekiq

  # Cache store
  config.cache_store = :redis_cache_store, {
    url: ENV['REDIS_URL'],
    expires_in: 90.minutes,
    namespace: 'geo_platform',
    pool_size: 5,
    pool_timeout: 5
  }

  # Session store
  config.session_store :redis_store, {
    servers: ENV['REDIS_URL'],
    expire_after: 90.minutes,
    key: '_geo_platform_session',
    threadsafe: true,
    secure: true,
    httponly: true,
    same_site: :lax
  }
end
```

#### Step 2: Configure Heroku

```bash
# Create Heroku app
heroku create geo-platform-production

# Add PostgreSQL
heroku addons:create heroku-postgresql:standard-0

# Add Redis
heroku addons:create heroku-redis:premium-0

# Set environment variables
heroku config:set RAILS_ENV=production
heroku config:set RACK_ENV=production
heroku config:set RAILS_SERVE_STATIC_FILES=true
heroku config:set RAILS_LOG_TO_STDOUT=true
heroku config:set SECRET_KEY_BASE=$(rails secret)
heroku config:set APP_HOST=geo-platform-production.herokuapp.com

# API Keys
heroku config:set OPENAI_API_KEY=your_key_here
heroku config:set ANTHROPIC_API_KEY=your_key_here
heroku config:set SENDGRID_API_KEY=your_key_here

# CORS origins
heroku config:set CORS_ORIGINS=https://geo-platform-production.herokuapp.com
```

#### Step 3: Create Procfile

```ruby
# Procfile
web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq -C config/sidekiq.yml
release: bundle exec rails db:migrate
```

#### Step 4: Configure Puma for Production

```ruby
# config/puma.rb
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

worker_timeout 3600 if ENV.fetch("RAILS_ENV", "development") == "development"

port ENV.fetch("PORT") { 3000 }
environment ENV.fetch("RAILS_ENV") { "development" }
pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

workers ENV.fetch("WEB_CONCURRENCY") { 2 }
preload_app!

plugin :tmp_restart

on_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end

before_fork do
  ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord)
end
```

#### Step 5: Database Migration Strategy

```ruby
# lib/tasks/deployment.rake
namespace :deployment do
  desc "Run pre-deployment tasks"
  task pre_deploy: :environment do
    puts "Running pre-deployment checks..."

    # Check database connectivity
    ActiveRecord::Base.connection.execute("SELECT 1")
    puts "✓ Database connection successful"

    # Check Redis connectivity
    Redis.new(url: ENV['REDIS_URL']).ping
    puts "✓ Redis connection successful"

    # Verify environment variables
    required_vars = %w[SECRET_KEY_BASE DATABASE_URL REDIS_URL]
    missing_vars = required_vars.reject { |var| ENV[var].present? }

    if missing_vars.any?
      puts "✗ Missing environment variables: #{missing_vars.join(', ')}"
      exit 1
    end

    puts "✓ All environment variables present"
    puts "Pre-deployment checks passed!"
  end

  desc "Run post-deployment tasks"
  task post_deploy: :environment do
    puts "Running post-deployment tasks..."

    # Warm up cache
    Rake::Task['cache:warmup'].invoke

    # Send deployment notification
    # DeploymentMailer.deployment_complete.deliver_now

    puts "Post-deployment tasks completed!"
  end
end

namespace :cache do
  desc "Warm up application cache"
  task warmup: :environment do
    puts "Warming up cache..."

    Workspace.find_each do |workspace|
      workspace.mention_stats
      workspace.top_brands
    end

    puts "Cache warmed up!"
  end
end
```

#### Step 6: Health Check Endpoint

```ruby
# app/controllers/health_controller.rb
class HealthController < ApplicationController
  skip_before_action :require_authentication

  def index
    health_status = {
      status: 'ok',
      timestamp: Time.current.iso8601,
      version: ENV['APP_VERSION'] || 'unknown',
      checks: {}
    }

    # Database check
    begin
      ActiveRecord::Base.connection.execute("SELECT 1")
      health_status[:checks][:database] = { status: 'ok' }
    rescue => e
      health_status[:status] = 'error'
      health_status[:checks][:database] = { status: 'error', message: e.message }
    end

    # Redis check
    begin
      Redis.new(url: ENV['REDIS_URL']).ping
      health_status[:checks][:redis] = { status: 'ok' }
    rescue => e
      health_status[:status] = 'error'
      health_status[:checks][:redis] = { status: 'error', message: e.message }
    end

    # Sidekiq check
    begin
      stats = Sidekiq::Stats.new
      health_status[:checks][:sidekiq] = {
        status: 'ok',
        processed: stats.processed,
        failed: stats.failed,
        enqueued: stats.enqueued
      }
    rescue => e
      health_status[:checks][:sidekiq] = { status: 'error', message: e.message }
    end

    status_code = health_status[:status] == 'ok' ? :ok : :service_unavailable
    render json: health_status, status: status_code
  end
end
```

```ruby
# config/routes.rb
get '/health', to: 'health#index'
get '/health/ready', to: 'health#index'
get '/health/live', to: 'health#index'
```

#### Step 7: Security Headers

```ruby
# config/initializers/security_headers.rb
Rails.application.config.action_dispatch.default_headers = {
  'X-Frame-Options' => 'SAMEORIGIN',
  'X-XSS-Protection' => '1; mode=block',
  'X-Content-Type-Options' => 'nosniff',
  'X-Download-Options' => 'noopen',
  'X-Permitted-Cross-Domain-Policies' => 'none',
  'Referrer-Policy' => 'strict-origin-when-cross-origin'
}

# Content Security Policy
Rails.application.config.content_security_policy do |policy|
  policy.default_src :self, :https
  policy.font_src    :self, :https, :data
  policy.img_src     :self, :https, :data
  policy.object_src  :none
  policy.script_src  :self, :https
  policy.style_src   :self, :https, :unsafe_inline

  # Specify URI for violation reports
  # policy.report_uri "/csp-violation-report-endpoint"
end

Rails.application.config.content_security_policy_nonce_generator =
  ->(request) { SecureRandom.base64(16) }

Rails.application.config.content_security_policy_nonce_directives = %w[script-src]
```

#### Step 8: Monitoring Setup (Sentry)

```ruby
# Gemfile
gem 'sentry-ruby'
gem 'sentry-rails'
gem 'sentry-sidekiq'
```

```ruby
# config/initializers/sentry.rb
Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  # Set traces_sample_rate to 1.0 to capture 100% of transactions for performance monitoring.
  # We recommend adjusting this value in production.
  config.traces_sample_rate = ENV.fetch('SENTRY_TRACES_SAMPLE_RATE', 0.1).to_f

  config.environment = Rails.env
  config.enabled_environments = %w[production staging]

  # Filter sensitive data
  config.before_send = lambda do |event, hint|
    # Filter out sensitive parameters
    if event.request
      event.request.data = event.request.data.except('password', 'password_confirmation', 'api_key')
    end
    event
  end
end
```

#### Step 9: New Relic Setup

```ruby
# Gemfile
gem 'newrelic_rpm'
```

```yaml
# config/newrelic.yml
common: &default_settings
  license_key: <%= ENV['NEW_RELIC_LICENSE_KEY'] %>
  app_name: GEO Platform

  distributed_tracing:
    enabled: true

  transaction_tracer:
    enabled: true
    transaction_threshold: apdex_f
    record_sql: obfuscated
    stack_trace_threshold: 0.5

  error_collector:
    enabled: true
    ignore_errors: "ActionController::RoutingError,ActionController::InvalidAuthenticityToken"

production:
  <<: *default_settings
  monitor_mode: true
  log_level: info

development:
  <<: *default_settings
  monitor_mode: false

test:
  <<: *default_settings
  monitor_mode: false
```

#### Step 10: Deployment Checklist

```markdown
# Pre-Deployment Checklist

## Code Quality
- [ ] All tests passing
- [ ] Code reviewed and approved
- [ ] No security vulnerabilities (run `bundle audit`)
- [ ] No N+1 queries (check with Bullet)
- [ ] Database migrations tested
- [ ] Rollback plan documented

## Configuration
- [ ] Environment variables set in production
- [ ] Database connection pool configured
- [ ] Redis configured and tested
- [ ] Sidekiq workers configured
- [ ] SSL certificates valid
- [ ] CORS origins configured
- [ ] Email delivery configured (SendGrid)
- [ ] Error tracking configured (Sentry)
- [ ] Performance monitoring configured (New Relic)

## Database
- [ ] Migrations reviewed
- [ ] Indexes added for performance
- [ ] Backup strategy in place
- [ ] Connection pooling configured
- [ ] Query timeouts set

## Security
- [ ] Secret keys rotated
- [ ] API keys secured
- [ ] Security headers configured
- [ ] CSP policy defined
- [ ] Rate limiting enabled
- [ ] SQL injection prevention verified
- [ ] XSS prevention verified

## Performance
- [ ] Asset precompilation tested
- [ ] CDN configured (if applicable)
- [ ] Caching strategy implemented
- [ ] Database queries optimized
- [ ] Background jobs configured
- [ ] Memory usage profiled

## Monitoring
- [ ] Health check endpoint working
- [ ] Error tracking active
- [ ] Performance monitoring active
- [ ] Log aggregation configured
- [ ] Uptime monitoring configured
- [ ] Alert notifications configured

## Documentation
- [ ] API documentation updated
- [ ] README updated
- [ ] Deployment guide updated
- [ ] Runbook created
- [ ] Team notified of deployment
```

#### Step 11: Deploy to Heroku

```bash
# Deploy application
git push heroku main

# Run migrations
heroku run rails db:migrate

# Scale workers
heroku ps:scale web=2 worker=1

# Check logs
heroku logs --tail

# Open application
heroku open

# Monitor performance
heroku ps
heroku pg:info
heroku redis:info
```

---

### Feature 4.10: Final Testing & QA

**Estimated Time:** 8 hours

#### Step 1: End-to-End Testing with Capybara

```ruby
# Gemfile (test group)
group :test do
  gem 'capybara', '~> 3.39'
  gem 'selenium-webdriver', '~> 4.10'
  gem 'webdrivers', '~> 5.2'
end
```

```ruby
# spec/rails_helper.rb
require 'capybara/rails'
require 'capybara/rspec'

Capybara.register_driver :selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--window-size=1400,900')

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.javascript_driver = :selenium_chrome_headless
Capybara.default_max_wait_time = 5
```

```ruby
# spec/system/user_workflow_spec.rb
require 'rails_helper'

RSpec.describe 'User Workflow', type: :system do
  before do
    driven_by(:selenium_chrome_headless)
  end

  it 'allows user to sign up, create workspace, and add brand' do
    # Sign up
    visit root_path
    click_link 'Sign Up'

    fill_in 'Email', with: 'test@example.com'
    fill_in 'Password', with: 'password123'
    fill_in 'First name', with: 'John'
    fill_in 'Last name', with: 'Doe'
    click_button 'Create Account'

    expect(page).to have_content('Welcome')

    # Create workspace
    click_link 'Create Workspace'
    fill_in 'Name', with: 'My Workspace'
    click_button 'Create Workspace'

    expect(page).to have_content('My Workspace')

    # Add brand
    click_link 'Add Brand'
    fill_in 'Name', with: 'Test Brand'
    fill_in 'Website URL', with: 'https://example.com'
    click_button 'Create Brand'

    expect(page).to have_content('Test Brand')
    expect(page).to have_content('Brand created successfully')
  end

  it 'displays dashboard with analytics' do
    user = create(:user)
    workspace = create(:workspace)
    workspace.add_member(user, role: 'admin')
    brand = create(:brand, workspace: workspace)
    create_list(:mention, 10, brand: brand, workspace: workspace)

    sign_in user
    visit workspace_path(workspace)

    expect(page).to have_content('Dashboard')
    expect(page).to have_content('Total Mentions')
    expect(page).to have_content(brand.name)
  end

  it 'allows filtering mentions by sentiment' do
    user = create(:user)
    workspace = create(:workspace)
    workspace.add_member(user, role: 'admin')
    brand = create(:brand, workspace: workspace)

    create(:mention, brand: brand, workspace: workspace, sentiment: 'positive')
    create(:mention, brand: brand, workspace: workspace, sentiment: 'negative')

    sign_in user
    visit workspace_brand_path(workspace, brand)

    select 'Positive', from: 'Sentiment'
    click_button 'Filter'

    expect(page).to have_css('.mention-card', count: 1)
  end
end
```

#### Step 2: Security Audit Checklist

```markdown
# Security Audit Checklist

## Authentication & Authorization
- [ ] Password requirements enforced (minimum length, complexity)
- [ ] Passwords hashed with bcrypt
- [ ] Session tokens secure and httponly
- [ ] CSRF protection enabled
- [ ] API authentication working (Bearer tokens)
- [ ] Rate limiting implemented
- [ ] Account lockout after failed attempts
- [ ] Password reset tokens expire
- [ ] Email confirmation required

## Data Protection
- [ ] SQL injection prevention (parameterized queries)
- [ ] XSS prevention (escaped output)
- [ ] CSRF tokens on all forms
- [ ] Secure headers configured
- [ ] SSL/TLS enforced in production
- [ ] Sensitive data encrypted at rest
- [ ] API keys stored securely
- [ ] No secrets in version control

## Access Control
- [ ] Multi-tenancy isolation (workspace scoping)
- [ ] Role-based permissions working
- [ ] Users can only access their workspaces
- [ ] Admin-only actions protected
- [ ] API endpoints require authentication
- [ ] File upload restrictions in place

## API Security
- [ ] Rate limiting per API key
- [ ] API versioning implemented
- [ ] Input validation on all endpoints
- [ ] Error messages don't leak sensitive info
- [ ] CORS configured correctly
- [ ] API documentation doesn't expose internals

## Infrastructure
- [ ] Database credentials secured
- [ ] Redis password protected
- [ ] Environment variables not committed
- [ ] Logs don't contain sensitive data
- [ ] Error tracking configured
- [ ] Backup strategy in place

## Dependencies
- [ ] All gems up to date
- [ ] No known vulnerabilities (`bundle audit`)
- [ ] Dependabot enabled
- [ ] Regular security updates scheduled
```

#### Step 3: Performance Testing

```ruby
# spec/performance/dashboard_performance_spec.rb
require 'rails_helper'

RSpec.describe 'Dashboard Performance', type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace) }
  let!(:brands) { create_list(:brand, 10, workspace: workspace) }

  before do
    workspace.add_member(user, role: 'admin')
    sign_in user

    # Create test data
    brands.each do |brand|
      create_list(:mention, 50, brand: brand, workspace: workspace)
      create_list(:visibility_score, 30, brand: brand, workspace: workspace)
    end
  end

  it 'loads dashboard within acceptable time' do
    start_time = Time.current

    get workspace_path(workspace)

    elapsed_time = Time.current - start_time

    expect(response).to have_http_status(:ok)
    expect(elapsed_time).to be < 1.0 # Should load in under 1 second
  end

  it 'executes minimal database queries' do
    queries = []

    ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      queries << event.payload[:sql] unless event.payload[:name] == 'SCHEMA'
    end

    get workspace_path(workspace)

    # Should use eager loading to minimize queries
    expect(queries.count).to be < 20
  end
end
```

```ruby
# spec/performance/api_performance_spec.rb
require 'rails_helper'

RSpec.describe 'API Performance', type: :request do
  let(:workspace) { create(:workspace) }
  let(:api_key) { create(:api_key, workspace: workspace) }
  let(:headers) { { 'Authorization' => "Bearer #{api_key.token}" } }

  before do
    create_list(:brand, 100, workspace: workspace)
  end

  it 'handles pagination efficiently' do
    start_time = Time.current

    get '/api/v1/brands', params: { page: 1, items: 25 }, headers: headers

    elapsed_time = Time.current - start_time

    expect(response).to have_http_status(:ok)
    expect(elapsed_time).to be < 0.5
  end

  it 'respects rate limits' do
    # Make requests up to limit
    1000.times do
      get '/api/v1/brands', headers: headers
    end

    # Next request should be rate limited
    get '/api/v1/brands', headers: headers
    expect(response).to have_http_status(:too_many_requests)
  end
end
```

#### Step 4: Browser Compatibility Testing

```markdown
# Browser Compatibility Checklist

## Desktop Browsers
- [ ] Chrome (latest)
- [ ] Firefox (latest)
- [ ] Safari (latest)
- [ ] Edge (latest)

## Mobile Browsers
- [ ] Safari iOS (latest)
- [ ] Chrome Android (latest)
- [ ] Samsung Internet

## Test Cases
- [ ] Login/signup flow
- [ ] Dashboard rendering
- [ ] Charts and visualizations
- [ ] Forms and validation
- [ ] Modal dialogs
- [ ] Dropdown menus
- [ ] Responsive layouts
- [ ] Touch interactions (mobile)
```

#### Step 5: Mobile Responsiveness Testing

```ruby
# spec/system/mobile_responsiveness_spec.rb
require 'rails_helper'

RSpec.describe 'Mobile Responsiveness', type: :system do
  before do
    driven_by(:selenium_chrome_headless)
  end

  it 'displays mobile navigation' do
    page.driver.browser.manage.window.resize_to(375, 667) # iPhone size

    user = create(:user)
    sign_in user

    visit root_path

    expect(page).to have_css('.mobile-menu-button')

    find('.mobile-menu-button').click
    expect(page).to have_css('.mobile-menu')
  end

  it 'renders dashboard on mobile' do
    page.driver.browser.manage.window.resize_to(375, 667)

    user = create(:user)
    workspace = create(:workspace)
    workspace.add_member(user, role: 'admin')

    sign_in user
    visit workspace_path(workspace)

    expect(page).to have_content('Dashboard')
    # Charts should stack vertically on mobile
    expect(page).to have_css('.chart-container')
  end
end
```

#### Step 6: Accessibility Testing

```ruby
# Gemfile (test group)
gem 'axe-core-rspec', '~> 4.7'
```

```ruby
# spec/system/accessibility_spec.rb
require 'rails_helper'
require 'axe/rspec'

RSpec.describe 'Accessibility', type: :system do
  before do
    driven_by(:selenium_chrome_headless)
  end

  it 'has no accessibility violations on homepage' do
    visit root_path
    expect(page).to be_axe_clean
  end

  it 'has no accessibility violations on dashboard' do
    user = create(:user)
    workspace = create(:workspace)
    workspace.add_member(user, role: 'admin')

    sign_in user
    visit workspace_path(workspace)

    expect(page).to be_axe_clean
  end

  it 'has proper ARIA labels' do
    visit root_path

    expect(page).to have_css('[aria-label]')
    expect(page).to have_css('button[aria-label]')
  end

  it 'supports keyboard navigation' do
    visit root_path

    # Tab through interactive elements
    page.driver.browser.action.send_keys(:tab).perform

    # Should focus on first interactive element
    expect(page).to have_css(':focus')
  end
end
```

```markdown
# WCAG 2.1 Accessibility Checklist

## Perceivable
- [ ] All images have alt text
- [ ] Color is not the only means of conveying information
- [ ] Text has sufficient contrast ratio (4.5:1 minimum)
- [ ] Content is structured with proper headings
- [ ] Forms have associated labels

## Operable
- [ ] All functionality available via keyboard
- [ ] No keyboard traps
- [ ] Skip navigation link present
- [ ] Focus indicators visible
- [ ] Sufficient time for interactions

## Understandable
- [ ] Language of page specified
- [ ] Navigation is consistent
- [ ] Error messages are clear
- [ ] Labels and instructions provided
- [ ] Help text available where needed

## Robust
- [ ] Valid HTML
- [ ] ARIA attributes used correctly
- [ ] Compatible with assistive technologies
- [ ] No console errors
```

#### Step 7: Final QA Checklist

```markdown
# Final QA Checklist

## Functionality
- [ ] User registration and login
- [ ] Email confirmation
- [ ] Password reset
- [ ] Workspace creation
- [ ] Brand management (CRUD)
- [ ] Source management (CRUD)
- [ ] Mention monitoring
- [ ] Sentiment analysis
- [ ] Visibility scoring
- [ ] Dashboard analytics
- [ ] Charts and visualizations
- [ ] Filtering and search
- [ ] Team collaboration
- [ ] API endpoints
- [ ] Report generation (PDF/CSV)
- [ ] Email notifications
- [ ] Settings and preferences

## User Experience
- [ ] Intuitive navigation
- [ ] Clear error messages
- [ ] Loading states
- [ ] Success confirmations
- [ ] Responsive design
- [ ] Fast page loads
- [ ] Smooth animations
- [ ] Consistent styling

## Data Integrity
- [ ] Data validation working
- [ ] No data loss on errors
- [ ] Proper error handling
- [ ] Transaction rollbacks working
- [ ] Background jobs processing
- [ ] Scheduled tasks running

## Performance
- [ ] Page load times < 2 seconds
- [ ] API response times < 500ms
- [ ] No N+1 queries
- [ ] Caching working
- [ ] Database indexes in place
- [ ] Background jobs not blocking

## Security
- [ ] Authentication required
- [ ] Authorization enforced
- [ ] CSRF protection
- [ ] XSS prevention
- [ ] SQL injection prevention
- [ ] Rate limiting
- [ ] Secure headers

## Monitoring
- [ ] Error tracking active
- [ ] Performance monitoring
- [ ] Log aggregation
- [ ] Health checks
- [ ] Uptime monitoring
```

---

## Launch Checklist

### Pre-Launch (1 week before)

- [ ] **Code freeze** - No new features, bug fixes only
- [ ] **Final testing** - Complete all QA checklists
- [ ] **Performance testing** - Load testing completed
- [ ] **Security audit** - All vulnerabilities addressed
- [ ] **Documentation** - User guides and API docs complete
- [ ] **Backup strategy** - Database backups configured
- [ ] **Monitoring** - All monitoring tools configured
- [ ] **Support plan** - Support channels ready

### Launch Day

- [ ] **Deploy to production** - Follow deployment checklist
- [ ] **Run migrations** - Database migrations successful
- [ ] **Verify health checks** - All systems operational
- [ ] **Test critical paths** - Login, signup, core features
- [ ] **Monitor errors** - Check Sentry for issues
- [ ] **Monitor performance** - Check New Relic metrics
- [ ] **Announce launch** - Notify stakeholders
- [ ] **Monitor user feedback** - Support channels active

### Post-Launch (First week)

- [ ] **Daily monitoring** - Check metrics and errors
- [ ] **User feedback** - Collect and prioritize feedback
- [ ] **Bug fixes** - Address critical issues immediately
- [ ] **Performance tuning** - Optimize based on real usage
- [ ] **Documentation updates** - Update based on user questions
- [ ] **Team retrospective** - Review launch process

---

## Success Metrics

### Technical Metrics
- **Uptime:** 99.9%
- **Page load time:** < 2 seconds
- **API response time:** < 500ms
- **Error rate:** < 0.1%
- **Test coverage:** > 80%

### User Metrics
- **User signups:** Track daily/weekly
- **Active workspaces:** Monitor growth
- **API usage:** Track API calls
- **Feature adoption:** Monitor feature usage
- **User retention:** Track weekly/monthly retention

### Business Metrics
- **Customer satisfaction:** NPS score
- **Support tickets:** Volume and resolution time
- **Feature requests:** Track and prioritize
- **Revenue:** If applicable

---

## Post-Launch Roadmap

### Phase 5: Growth & Optimization (Weeks 13-16)
- Advanced analytics and insights
- Machine learning for trend prediction
- Competitor analysis features
- White-label options
- Mobile app (iOS/Android)
- Advanced integrations (Slack, Teams, etc.)
- Custom dashboards
- Advanced reporting

### Phase 6: Scale & Enterprise (Weeks 17-20)
- Enterprise features (SSO, SAML)
- Advanced permissions and roles
- Audit logs
- Data export/import
- API webhooks
- Custom branding
- Dedicated support
- SLA guarantees

---

## Conclusion

Phase 4 completes the GEO Platform with production-ready features including:

✅ **REST API** with authentication, documentation, and rate limiting
✅ **Team Collaboration** with role-based permissions
✅ **Email Notifications** for alerts and summaries
✅ **Custom Reports** in PDF and CSV formats
✅ **Settings & Preferences** for customization
✅ **Performance Optimization** with caching and query optimization
✅ **Production Deployment** on Heroku with monitoring
✅ **Comprehensive Testing** including E2E, security, and accessibility

The platform is now ready for launch with:
- Robust security measures
- Scalable architecture
- Comprehensive monitoring
- Complete documentation
- Production-grade infrastructure

**Next Steps:**
1. Complete final QA testing
2. Deploy to production
3. Monitor launch metrics
4. Gather user feedback
5. Plan Phase 5 features

**Estimated Total Time for Phase 4:** 64 hours (2 weeks with 2-3 developers)

---

## Additional Resources

### Documentation
- [API Documentation](http://localhost:3000/api-docs)
- [User Guide](docs/user-guide.md)
- [Admin Guide](docs/admin-guide.md)
- [Deployment Guide](docs/deployment.md)

### Monitoring Dashboards
- [Heroku Dashboard](https://dashboard.heroku.com)
- [Sentry Error Tracking](https://sentry.io)
- [New Relic Performance](https://newrelic.com)

### Support
- Email: support@geoplatform.com
- Slack: #geo-platform-support
- Documentation: https://docs.geoplatform.com

---

**Document Version:** 1.0
**Last Updated:** 2026-01-23
**Status:** Ready for Implementation
