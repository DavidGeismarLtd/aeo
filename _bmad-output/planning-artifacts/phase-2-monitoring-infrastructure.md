---
document_type: Implementation Guide - Phase 2
product_name: GEO Platform
phase: Monitoring Infrastructure (Weeks 3-6)
version: 1.0
date: 2026-01-23
author: David Geismar
tech_stack: Ruby on Rails 7.x, PostgreSQL, Redis, Sidekiq, Tailwind CSS
---

# Phase 2: Monitoring Infrastructure (Weeks 3-6)

## Overview

**Goal:** Build the core AI platform monitoring system with real-time mention detection and tracking

**Duration:** 4 weeks

**Team:** 2-3 developers

**Deliverables:**
- AI Platform models and configurations
- Mention and Citation tracking with TimescaleDB
- Base monitoring service architecture
- ChatGPT and Claude monitor implementations
- Mention detection service
- Background job infrastructure for monitoring
- Monitoring dashboard with real-time updates
- Brand monitoring setup interface

---

## Week 3: Data Models & Base Services

### Feature 2.1: AI Platform Models & Configuration

**Estimated Time:** 6 hours

#### Step 1: Create AiPlatform Model

```bash
rails generate model AiPlatform \
  name:string \
  slug:string \
  api_endpoint:string \
  rate_limit_per_minute:integer \
  active:boolean \
  metadata:jsonb
```

```ruby
# db/migrate/XXXXXX_create_ai_platforms.rb
class CreateAiPlatforms < ActiveRecord::Migration[7.1]
  def change
    create_table :ai_platforms, id: :uuid do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :api_endpoint
      t.integer :rate_limit_per_minute, default: 60
      t.boolean :active, default: true
      t.jsonb :metadata, default: {}
      t.timestamps

      t.index :slug, unique: true
      t.index :active
    end
  end
end
```

```ruby
# app/models/ai_platform.rb
class AiPlatform < ApplicationRecord
  # Associations
  has_many :ai_platform_configs, dependent: :destroy
  has_many :mentions, dependent: :nullify
  has_many :visibility_scores, dependent: :nullify

  # Validations
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :slug, format: { with: /\A[a-z0-9_]+\z/, message: "only lowercase letters, numbers, and underscores" }
  validates :rate_limit_per_minute, numericality: { greater_than: 0 }, allow_nil: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  # Constants for supported platforms
  SUPPORTED_PLATFORMS = %w[chatgpt claude perplexity gemini].freeze

  def monitor_class
    "AiPlatforms::#{slug.camelize}Monitor".constantize
  rescue NameError
    AiPlatforms::BaseMonitor
  end

  def rate_limit_delay
    return 0 unless rate_limit_per_minute.present? && rate_limit_per_minute > 0
    
    60.0 / rate_limit_per_minute
  end
end
```

#### Step 2: Create AiPlatformConfig Model

```bash
rails generate model AiPlatformConfig \
  workspace:references \
  ai_platform:references \
  enabled:boolean \
  api_key_encrypted:string \
  monitoring_frequency:string \
  settings:jsonb
```

```ruby
# db/migrate/XXXXXX_create_ai_platform_configs.rb
class CreateAiPlatformConfigs < ActiveRecord::Migration[7.1]
  def change
    create_table :ai_platform_configs, id: :uuid do |t|
      t.references :workspace, type: :uuid, null: false, foreign_key: true
      t.references :ai_platform, type: :uuid, null: false, foreign_key: true
      t.boolean :enabled, default: true
      t.string :api_key_encrypted
      t.string :monitoring_frequency, default: 'daily' # hourly, daily, weekly
      t.jsonb :settings, default: {}
      t.datetime :last_monitored_at
      t.timestamps

      t.index [:workspace_id, :ai_platform_id], unique: true, name: 'index_ai_platform_configs_on_workspace_and_platform'
      t.index :enabled
      t.index :last_monitored_at
    end
  end
end
```

```ruby
# app/models/ai_platform_config.rb
class AiPlatformConfig < ApplicationRecord
  belongs_to :workspace
  belongs_to :ai_platform

  # Validations
  validates :monitoring_frequency, inclusion: { in: %w[hourly daily weekly] }
  validates :ai_platform_id, uniqueness: { scope: :workspace_id }

  # Encrypt API keys
  encrypts :api_key_encrypted, deterministic: false

  # Scopes
  scope :enabled, -> { where(enabled: true) }
  scope :disabled, -> { where(enabled: false) }
  scope :due_for_monitoring, -> {
    enabled.where(
      'last_monitored_at IS NULL OR last_monitored_at < ?',
      1.hour.ago
    )
  }

  # Frequency checks
  def hourly?
    monitoring_frequency == 'hourly'
  end

  def daily?
    monitoring_frequency == 'daily'
  end

  def weekly?
    monitoring_frequency == 'weekly'
  end

  def due_for_monitoring?
    return true if last_monitored_at.nil?

    case monitoring_frequency
    when 'hourly'
      last_monitored_at < 1.hour.ago
    when 'daily'
      last_monitored_at < 1.day.ago
    when 'weekly'
      last_monitored_at < 1.week.ago
    else
      false
    end
  end

  def update_last_monitored!
    update!(last_monitored_at: Time.current)
  end

  def api_key
    api_key_encrypted
  end

  def api_key=(value)
    self.api_key_encrypted = value
  end
end
```

#### Step 3: Create Seed Data for AI Platforms

```ruby
# db/seeds.rb (add to existing file)

# Create AI Platforms
platforms = [
  {
    name: 'ChatGPT',
    slug: 'chatgpt',
    api_endpoint: 'https://api.openai.com/v1',
    rate_limit_per_minute: 60,
    metadata: {
      model: 'gpt-4',
      description: 'OpenAI ChatGPT',
      requires_api_key: true
    }
  },
  {
    name: 'Claude',
    slug: 'claude',
    api_endpoint: 'https://api.anthropic.com/v1',
    rate_limit_per_minute: 50,
    metadata: {
      model: 'claude-3-opus-20240229',
      description: 'Anthropic Claude',
      requires_api_key: true
    }
  },
  {
    name: 'Perplexity',
    slug: 'perplexity',
    api_endpoint: 'https://api.perplexity.ai',
    rate_limit_per_minute: 20,
    metadata: {
      model: 'pplx-70b-online',
      description: 'Perplexity AI',
      requires_api_key: true
    }
  },
  {
    name: 'Gemini',
    slug: 'gemini',
    api_endpoint: 'https://generativelanguage.googleapis.com/v1',
    rate_limit_per_minute: 60,
    metadata: {
      model: 'gemini-pro',
      description: 'Google Gemini',
      requires_api_key: true
    }
  }
]

platforms.each do |platform_data|
  AiPlatform.find_or_create_by!(slug: platform_data[:slug]) do |platform|
    platform.assign_attributes(platform_data)
  end
end

puts "Created #{AiPlatform.count} AI platforms"
```

#### Step 4: Run Migrations and Seeds

```bash
rails db:migrate
rails db:seed
```

#### Step 5: Create Factories

```ruby
# spec/factories/ai_platforms.rb
FactoryBot.define do
  factory :ai_platform do
    name { 'ChatGPT' }
    slug { 'chatgpt' }
    api_endpoint { 'https://api.openai.com/v1' }
    rate_limit_per_minute { 60 }
    active { true }
    metadata { { model: 'gpt-4' } }

    trait :claude do
      name { 'Claude' }
      slug { 'claude' }
      api_endpoint { 'https://api.anthropic.com/v1' }
      metadata { { model: 'claude-3-opus-20240229' } }
    end

    trait :inactive do
      active { false }
    end
  end
end

# spec/factories/ai_platform_configs.rb
FactoryBot.define do
  factory :ai_platform_config do
    workspace
    ai_platform
    enabled { true }
    api_key_encrypted { 'test_api_key_123' }
    monitoring_frequency { 'daily' }
    settings { {} }

    trait :hourly do
      monitoring_frequency { 'hourly' }
    end

    trait :weekly do
      monitoring_frequency { 'weekly' }
    end

    trait :disabled do
      enabled { false }
    end

    trait :due_for_monitoring do
      last_monitored_at { 2.days.ago }
    end
  end
end
```

#### Step 6: Model Tests

```ruby
# spec/models/ai_platform_spec.rb
require 'rails_helper'

RSpec.describe AiPlatform, type: :model do
  describe 'associations' do
    it { should have_many(:ai_platform_configs).dependent(:destroy) }
    it { should have_many(:mentions).dependent(:nullify) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:slug) }
    it { should validate_uniqueness_of(:slug) }
  end

  describe 'scopes' do
    let!(:active_platform) { create(:ai_platform, active: true) }
    let!(:inactive_platform) { create(:ai_platform, :inactive) }

    it 'returns active platforms' do
      expect(AiPlatform.active).to include(active_platform)
      expect(AiPlatform.active).not_to include(inactive_platform)
    end
  end

  describe '#rate_limit_delay' do
    it 'calculates delay based on rate limit' do
      platform = create(:ai_platform, rate_limit_per_minute: 60)
      expect(platform.rate_limit_delay).to eq(1.0)
    end

    it 'returns 0 when rate limit is not set' do
      platform = create(:ai_platform, rate_limit_per_minute: nil)
      expect(platform.rate_limit_delay).to eq(0)
    end
  end
end

# spec/models/ai_platform_config_spec.rb
require 'rails_helper'

RSpec.describe AiPlatformConfig, type: :model do
  describe 'associations' do
    it { should belong_to(:workspace) }
    it { should belong_to(:ai_platform) }
  end

  describe 'validations' do
    it { should validate_inclusion_of(:monitoring_frequency).in_array(%w[hourly daily weekly]) }
  end

  describe '#due_for_monitoring?' do
    let(:config) { create(:ai_platform_config, monitoring_frequency: 'daily') }

    it 'returns true when never monitored' do
      config.update!(last_monitored_at: nil)
      expect(config.due_for_monitoring?).to be true
    end

    it 'returns true when last monitored beyond frequency' do
      config.update!(last_monitored_at: 2.days.ago)
      expect(config.due_for_monitoring?).to be true
    end

    it 'returns false when recently monitored' do
      config.update!(last_monitored_at: 1.hour.ago)
      expect(config.due_for_monitoring?).to be false
    end
  end
end
```

---

### Feature 2.2: Mentions & Citations Models

**Estimated Time:** 6 hours

#### Step 1: Install TimescaleDB Extension

```bash
# Install TimescaleDB (macOS)
brew install timescaledb

# Or follow instructions at: https://docs.timescale.com/install/latest/
```

```ruby
# db/migrate/XXXXXX_enable_timescaledb.rb
class EnableTimescaledb < ActiveRecord::Migration[7.1]
  def up
    enable_extension 'timescaledb'
  end

  def down
    disable_extension 'timescaledb'
  end
end
```

#### Step 2: Create Mention Model with Hypertable

```bash
rails generate model Mention \
  brand:references \
  ai_platform:references \
  query_text:text \
  response_text:text \
  position:integer \
  context:text \
  sentiment:string \
  detected_at:datetime \
  metadata:jsonb
```

```ruby
# db/migrate/XXXXXX_create_mentions.rb
class CreateMentions < ActiveRecord::Migration[7.1]
  def change
    create_table :mentions, id: :uuid do |t|
      t.references :brand, type: :uuid, null: false, foreign_key: true
      t.references :ai_platform, type: :uuid, null: true, foreign_key: true
      t.text :query_text, null: false
      t.text :response_text
      t.integer :position # Position in response (1-10, etc.)
      t.text :context # Surrounding text
      t.string :sentiment # positive, neutral, negative
      t.datetime :detected_at, null: false
      t.jsonb :metadata, default: {}
      t.timestamps

      t.index :detected_at
      t.index [:brand_id, :detected_at]
      t.index [:ai_platform_id, :detected_at]
      t.index :sentiment
      t.index :position
    end

    # Convert to TimescaleDB hypertable
    # This optimizes time-series queries
    execute <<-SQL
      SELECT create_hypertable('mentions', 'detected_at',
        chunk_time_interval => INTERVAL '1 week',
        if_not_exists => TRUE
      );
    SQL

    # Create continuous aggregate for daily mention counts
    execute <<-SQL
      CREATE MATERIALIZED VIEW IF NOT EXISTS mentions_daily
      WITH (timescaledb.continuous) AS
      SELECT
        brand_id,
        ai_platform_id,
        time_bucket('1 day', detected_at) AS day,
        COUNT(*) as mention_count,
        AVG(position) as avg_position
      FROM mentions
      GROUP BY brand_id, ai_platform_id, day
      WITH NO DATA;
    SQL

    # Add refresh policy
    execute <<-SQL
      SELECT add_continuous_aggregate_policy('mentions_daily',
        start_offset => INTERVAL '3 days',
        end_offset => INTERVAL '1 hour',
        schedule_interval => INTERVAL '1 hour',
        if_not_exists => TRUE
      );
    SQL
  end

  def down
    execute "DROP MATERIALIZED VIEW IF EXISTS mentions_daily CASCADE;"
    drop_table :mentions
  end
end
```

```ruby
# app/models/mention.rb
class Mention < ApplicationRecord
  belongs_to :brand, counter_cache: true
  belongs_to :ai_platform, optional: true
  has_many :citations, dependent: :destroy

  # Validations
  validates :query_text, presence: true
  validates :detected_at, presence: true
  validates :sentiment, inclusion: { in: %w[positive neutral negative] }, allow_nil: true
  validates :position, numericality: { greater_than: 0 }, allow_nil: true

  # Scopes
  scope :recent, -> { order(detected_at: :desc) }
  scope :for_platform, ->(platform) { where(ai_platform: platform) }
  scope :positive, -> { where(sentiment: 'positive') }
  scope :neutral, -> { where(sentiment: 'neutral') }
  scope :negative, -> { where(sentiment: 'negative') }
  scope :in_date_range, ->(start_date, end_date) {
    where(detected_at: start_date..end_date)
  }
  scope :last_30_days, -> { where('detected_at >= ?', 30.days.ago) }
  scope :last_7_days, -> { where('detected_at >= ?', 7.days.ago) }

  # TimescaleDB specific queries
  def self.daily_counts(start_date: 30.days.ago, end_date: Time.current)
    select(
      "time_bucket('1 day', detected_at) AS day",
      "COUNT(*) as count"
    )
    .where(detected_at: start_date..end_date)
    .group("day")
    .order("day DESC")
  end

  def self.platform_breakdown
    joins(:ai_platform)
    .group('ai_platforms.name')
    .count
  end

  def self.average_position
    where.not(position: nil).average(:position)&.round(2) || 0
  end

  # Sentiment analysis (placeholder - integrate with actual sentiment analysis later)
  def analyze_sentiment!
    return if context.blank?

    # Simple keyword-based sentiment (replace with ML model later)
    positive_words = %w[best great excellent recommended top amazing]
    negative_words = %w[worst bad poor avoid terrible]

    text = context.downcase
    positive_count = positive_words.count { |word| text.include?(word) }
    negative_count = negative_words.count { |word| text.include?(word) }

    self.sentiment = if positive_count > negative_count
      'positive'
    elsif negative_count > positive_count
      'negative'
    else
      'neutral'
    end

    save
  end
end
```

#### Step 3: Create Citation Model

```bash
rails generate model Citation \
  mention:references \
  url:string \
  title:string \
  snippet:text \
  position:integer \
  metadata:jsonb
```

```ruby
# db/migrate/XXXXXX_create_citations.rb
class CreateCitations < ActiveRecord::Migration[7.1]
  def change
    create_table :citations, id: :uuid do |t|
      t.references :mention, type: :uuid, null: false, foreign_key: true
      t.string :url
      t.string :title
      t.text :snippet
      t.integer :position
      t.jsonb :metadata, default: {}
      t.timestamps

      t.index :url
      t.index [:mention_id, :position]
    end
  end
end
```

```ruby
# app/models/citation.rb
class Citation < ApplicationRecord
  belongs_to :mention

  # Validations
  validates :url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }, allow_blank: true
  validates :position, numericality: { greater_than: 0 }, allow_nil: true

  # Scopes
  scope :ordered, -> { order(position: :asc) }

  def domain
    return nil if url.blank?

    URI.parse(url).host
  rescue URI::InvalidURIError
    nil
  end
end
```

#### Step 4: Update Brand Model

```ruby
# app/models/brand.rb (add to existing model)
class Brand < ApplicationRecord
  # ... existing code ...

  has_many :mentions, dependent: :destroy

  # Add method to get mention trends
  def mention_trend(days: 30)
    mentions
      .where('detected_at >= ?', days.days.ago)
      .group_by_day(:detected_at)
      .count
  end

  def mentions_by_platform
    mentions
      .joins(:ai_platform)
      .group('ai_platforms.name')
      .count
  end

  def average_mention_position
    mentions.average_position
  end
end
```

#### Step 5: Run Migrations

```bash
rails db:migrate
```

#### Step 6: Create Factories

```ruby
# spec/factories/mentions.rb
FactoryBot.define do
  factory :mention do
    brand
    ai_platform
    query_text { "What are the best #{Faker::Commerce.product_name} tools?" }
    response_text { Faker::Lorem.paragraph(sentence_count: 5) }
    position { rand(1..10) }
    context { Faker::Lorem.sentence }
    sentiment { %w[positive neutral negative].sample }
    detected_at { Time.current }
    metadata { {} }

    trait :positive do
      sentiment { 'positive' }
      context { 'This is a great tool that I highly recommend' }
    end

    trait :negative do
      sentiment { 'negative' }
      context { 'This tool has poor performance and bad support' }
    end

    trait :recent do
      detected_at { 1.day.ago }
    end

    trait :old do
      detected_at { 60.days.ago }
    end
  end
end

# spec/factories/citations.rb
FactoryBot.define do
  factory :citation do
    mention
    url { Faker::Internet.url }
    title { Faker::Lorem.sentence }
    snippet { Faker::Lorem.paragraph }
    position { rand(1..5) }
    metadata { {} }
  end
end
```

#### Step 7: Model Tests

```ruby
# spec/models/mention_spec.rb
require 'rails_helper'

RSpec.describe Mention, type: :model do
  describe 'associations' do
    it { should belong_to(:brand) }
    it { should belong_to(:ai_platform).optional }
    it { should have_many(:citations).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:query_text) }
    it { should validate_presence_of(:detected_at) }
    it { should validate_inclusion_of(:sentiment).in_array(%w[positive neutral negative]).allow_nil }
  end

  describe 'scopes' do
    let!(:recent_mention) { create(:mention, detected_at: 1.day.ago) }
    let!(:old_mention) { create(:mention, detected_at: 60.days.ago) }

    it 'returns last 30 days mentions' do
      expect(Mention.last_30_days).to include(recent_mention)
      expect(Mention.last_30_days).not_to include(old_mention)
    end
  end

  describe '#analyze_sentiment!' do
    it 'detects positive sentiment' do
      mention = create(:mention, context: 'This is the best tool ever', sentiment: nil)
      mention.analyze_sentiment!
      expect(mention.sentiment).to eq('positive')
    end

    it 'detects negative sentiment' do
      mention = create(:mention, context: 'This is the worst tool ever', sentiment: nil)
      mention.analyze_sentiment!
      expect(mention.sentiment).to eq('negative')
    end
  end
end

# spec/models/citation_spec.rb
require 'rails_helper'

RSpec.describe Citation, type: :model do
  describe 'associations' do
    it { should belong_to(:mention) }
  end

  describe '#domain' do
    it 'extracts domain from URL' do
      citation = build(:citation, url: 'https://example.com/page')
      expect(citation.domain).to eq('example.com')
    end

    it 'returns nil for invalid URL' do
      citation = build(:citation, url: 'not-a-url')
      expect(citation.domain).to be_nil
    end
  end
end
```

---

### Feature 2.3: Base Monitor Service

**Estimated Time:** 8 hours

#### Step 1: Create Base Monitor Service

```ruby
# app/services/ai_platforms/base_monitor.rb
module AiPlatforms
  class BaseMonitor
    attr_reader :workspace, :brand, :ai_platform_config, :errors

    def initialize(workspace:, brand:, ai_platform_config:)
      @workspace = workspace
      @brand = brand
      @ai_platform_config = ai_platform_config
      @errors = []
    end

    def execute
      return failure('AI platform config is disabled') unless ai_platform_config.enabled?
      return failure('No API key configured') unless api_key.present?

      queries = generate_queries
      results = []

      queries.each_with_index do |query, index|
        # Rate limiting
        sleep(rate_limit_delay) if index > 0

        begin
          response = query_platform(query)
          mentions = detect_mentions(query, response)
          results.concat(mentions)
        rescue StandardError => e
          log_error(e, query)
        end
      end

      ai_platform_config.update_last_monitored!
      success(results)
    rescue StandardError => e
      failure("Monitoring failed: #{e.message}")
    end

    protected

    # Override in subclasses
    def query_platform(query)
      raise NotImplementedError, 'Subclasses must implement query_platform'
    end

    # Override in subclasses for platform-specific queries
    def generate_queries
      [
        "What are the best #{brand.metadata['product_category']} tools?",
        "Top #{brand.metadata['product_category']} solutions for businesses",
        "#{brand.metadata['product_category']} software recommendations"
      ]
    end

    def detect_mentions(query, response)
      detector = MentionDetector.new(
        brand: brand,
        query_text: query,
        response_text: response,
        ai_platform: ai_platform_config.ai_platform
      )

      detector.execute
    end

    def api_key
      ai_platform_config.api_key
    end

    def rate_limit_delay
      ai_platform_config.ai_platform.rate_limit_delay
    end

    def log_error(error, query)
      @errors << { error: error.message, query: query, timestamp: Time.current }
      Rails.logger.error("[#{self.class.name}] #{error.message} - Query: #{query}")
    end

    def success(data)
      OpenStruct.new(success?: true, data: data, errors: @errors)
    end

    def failure(message)
      @errors << { error: message, timestamp: Time.current }
      OpenStruct.new(success?: false, data: [], errors: @errors)
    end
  end
end
```

#### Step 2: Create Service Tests

```ruby
# spec/services/ai_platforms/base_monitor_spec.rb
require 'rails_helper'

RSpec.describe AiPlatforms::BaseMonitor do
  let(:workspace) { create(:workspace) }
  let(:brand) { create(:brand, workspace: workspace, metadata: { product_category: 'CRM' }) }
  let(:ai_platform) { create(:ai_platform) }
  let(:config) { create(:ai_platform_config, workspace: workspace, ai_platform: ai_platform) }
  let(:monitor) { described_class.new(workspace: workspace, brand: brand, ai_platform_config: config) }

  describe '#execute' do
    it 'fails when config is disabled' do
      config.update!(enabled: false)
      result = monitor.execute

      expect(result.success?).to be false
      expect(result.errors.first[:error]).to include('disabled')
    end

    it 'fails when no API key is configured' do
      config.update!(api_key_encrypted: nil)
      result = monitor.execute

      expect(result.success?).to be false
      expect(result.errors.first[:error]).to include('No API key')
    end
  end

  describe '#generate_queries' do
    it 'generates default queries based on brand metadata' do
      queries = monitor.send(:generate_queries)

      expect(queries).to be_an(Array)
      expect(queries.first).to include('CRM')
    end
  end

  describe '#rate_limit_delay' do
    it 'returns the platform rate limit delay' do
      expect(monitor.send(:rate_limit_delay)).to eq(ai_platform.rate_limit_delay)
    end
  end
end
```

---

## Week 4: Platform Monitors & Detection

### Feature 2.4: ChatGPT Monitor

**Estimated Time:** 6 hours

#### Step 1: Add ruby-openai Gem

```ruby
# Gemfile (already added in Phase 1, but verify)
gem "ruby-openai", "~> 6.0"
```

```bash
bundle install
```

#### Step 2: Create ChatGPT Monitor Service

```ruby
# app/services/ai_platforms/chatgpt_monitor.rb
module AiPlatforms
  class ChatgptMonitor < BaseMonitor
    def initialize(workspace:, brand:, ai_platform_config:)
      super
      @client = OpenAI::Client.new(access_token: api_key)
    end

    protected

    def query_platform(query)
      response = @client.chat(
        parameters: {
          model: model_name,
          messages: [
            { role: 'system', content: system_prompt },
            { role: 'user', content: query }
          ],
          temperature: 0.7,
          max_tokens: 1000
        }
      )

      extract_response_text(response)
    rescue Faraday::Error => e
      log_error(e, query)
      ''
    end

    def generate_queries
      category = brand.metadata['product_category'] || 'software'
      industry = brand.metadata['industry'] || 'business'

      [
        "What are the best #{category} tools for #{industry}?",
        "Can you recommend top #{category} solutions?",
        "I'm looking for #{category} software. What do you suggest?",
        "Compare the leading #{category} platforms",
        "What #{category} tool would you recommend for a growing company?"
      ]
    end

    private

    def model_name
      ai_platform_config.settings['model'] || 'gpt-4'
    end

    def system_prompt
      "You are a helpful assistant that provides recommendations for business software and tools. "\
      "Provide specific product names and brief explanations when making recommendations."
    end

    def extract_response_text(response)
      response.dig('choices', 0, 'message', 'content') || ''
    end
  end
end
```

#### Step 3: Configure OpenAI Initializer

```ruby
# config/initializers/openai.rb
OpenAI.configure do |config|
  config.access_token = ENV.fetch('OPENAI_API_KEY', nil)
  config.request_timeout = 30 # seconds
end
```

#### Step 4: Create VCR Configuration for Testing

```ruby
# spec/support/vcr.rb
require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.allow_http_connections_when_no_cassette = false

  # Filter sensitive data
  config.filter_sensitive_data('<OPENAI_API_KEY>') { ENV['OPENAI_API_KEY'] }
  config.filter_sensitive_data('<ANTHROPIC_API_KEY>') { ENV['ANTHROPIC_API_KEY'] }

  # Ignore localhost
  config.ignore_localhost = true
end
```

#### Step 5: Create Service Tests with VCR

```ruby
# spec/services/ai_platforms/chatgpt_monitor_spec.rb
require 'rails_helper'

RSpec.describe AiPlatforms::ChatgptMonitor do
  let(:workspace) { create(:workspace) }
  let(:brand) { create(:brand, workspace: workspace, name: 'TestBrand', metadata: { product_category: 'CRM' }) }
  let(:ai_platform) { create(:ai_platform, slug: 'chatgpt') }
  let(:config) do
    create(:ai_platform_config,
      workspace: workspace,
      ai_platform: ai_platform,
      api_key_encrypted: ENV['OPENAI_API_KEY'] || 'test_key'
    )
  end
  let(:monitor) { described_class.new(workspace: workspace, brand: brand, ai_platform_config: config) }

  describe '#execute', vcr: { cassette_name: 'chatgpt_monitor/execute' } do
    it 'queries ChatGPT and detects mentions' do
      result = monitor.execute

      expect(result.success?).to be true
      expect(result.data).to be_an(Array)
    end

    it 'updates last_monitored_at timestamp' do
      expect {
        monitor.execute
      }.to change { config.reload.last_monitored_at }
    end
  end

  describe '#generate_queries' do
    it 'generates ChatGPT-specific queries' do
      queries = monitor.send(:generate_queries)

      expect(queries).to be_an(Array)
      expect(queries.length).to be >= 3
      expect(queries.first).to include('CRM')
    end
  end

  describe '#query_platform', vcr: { cassette_name: 'chatgpt_monitor/query_platform' } do
    it 'returns response text from ChatGPT' do
      query = 'What are the best CRM tools?'
      response = monitor.send(:query_platform, query)

      expect(response).to be_a(String)
      expect(response.length).to be > 0
    end

    it 'handles API errors gracefully' do
      allow(monitor.instance_variable_get(:@client)).to receive(:chat).and_raise(Faraday::Error.new('API Error'))

      query = 'Test query'
      response = monitor.send(:query_platform, query)

      expect(response).to eq('')
      expect(monitor.errors).not_to be_empty
    end
  end
end
```

---

### Feature 2.5: Claude Monitor

**Estimated Time:** 6 hours

#### Step 1: Add Anthropic Gem

```ruby
# Gemfile
gem "anthropic", "~> 0.1"
```

```bash
bundle install
```

#### Step 2: Create Claude Monitor Service

```ruby
# app/services/ai_platforms/claude_monitor.rb
module AiPlatforms
  class ClaudeMonitor < BaseMonitor
    def initialize(workspace:, brand:, ai_platform_config:)
      super
      @client = Anthropic::Client.new(api_key: api_key)
    end

    protected

    def query_platform(query)
      response = @client.messages(
        model: model_name,
        max_tokens: 1000,
        messages: [
          { role: 'user', content: query }
        ]
      )

      extract_response_text(response)
    rescue Faraday::Error => e
      log_error(e, query)
      ''
    end

    def generate_queries
      category = brand.metadata['product_category'] || 'software'
      industry = brand.metadata['industry'] || 'business'

      [
        "What are the top #{category} tools you'd recommend for #{industry}?",
        "I need a #{category} solution. What are my best options?",
        "Can you compare the leading #{category} platforms?",
        "What #{category} software do you think is best for startups?",
        "Which #{category} tools are most popular right now?"
      ]
    end

    private

    def model_name
      ai_platform_config.settings['model'] || 'claude-3-opus-20240229'
    end

    def extract_response_text(response)
      response.dig('content', 0, 'text') || ''
    end
  end
end
```

#### Step 3: Configure Anthropic Initializer

```ruby
# config/initializers/anthropic.rb
Anthropic.configure do |config|
  config.api_key = ENV.fetch('ANTHROPIC_API_KEY', nil)
end
```

#### Step 4: Create Service Tests

```ruby
# spec/services/ai_platforms/claude_monitor_spec.rb
require 'rails_helper'

RSpec.describe AiPlatforms::ClaudeMonitor do
  let(:workspace) { create(:workspace) }
  let(:brand) { create(:brand, workspace: workspace, name: 'TestBrand', metadata: { product_category: 'CRM' }) }
  let(:ai_platform) { create(:ai_platform, :claude) }
  let(:config) do
    create(:ai_platform_config,
      workspace: workspace,
      ai_platform: ai_platform,
      api_key_encrypted: ENV['ANTHROPIC_API_KEY'] || 'test_key'
    )
  end
  let(:monitor) { described_class.new(workspace: workspace, brand: brand, ai_platform_config: config) }

  describe '#execute', vcr: { cassette_name: 'claude_monitor/execute' } do
    it 'queries Claude and detects mentions' do
      result = monitor.execute

      expect(result.success?).to be true
      expect(result.data).to be_an(Array)
    end
  end

  describe '#generate_queries' do
    it 'generates Claude-specific queries' do
      queries = monitor.send(:generate_queries)

      expect(queries).to be_an(Array)
      expect(queries.length).to be >= 3
      expect(queries.first).to include('CRM')
    end
  end

  describe '#query_platform', vcr: { cassette_name: 'claude_monitor/query_platform' } do
    it 'returns response text from Claude' do
      query = 'What are the best CRM tools?'
      response = monitor.send(:query_platform, query)

      expect(response).to be_a(String)
      expect(response.length).to be > 0
    end

    it 'handles API errors gracefully' do
      allow(monitor.instance_variable_get(:@client)).to receive(:messages).and_raise(Faraday::Error.new('API Error'))

      query = 'Test query'
      response = monitor.send(:query_platform, query)

      expect(response).to eq('')
      expect(monitor.errors).not_to be_empty
    end
  end
end
```

---

### Feature 2.6: Mention Detector Service

**Estimated Time:** 8 hours

#### Step 1: Create Mention Detector Service

```ruby
# app/services/mention_detector.rb
class MentionDetector
  attr_reader :brand, :query_text, :response_text, :ai_platform, :mentions

  def initialize(brand:, query_text:, response_text:, ai_platform:)
    @brand = brand
    @query_text = query_text
    @response_text = response_text
    @ai_platform = ai_platform
    @mentions = []
  end

  def execute
    return [] if response_text.blank?

    detect_brand_mentions
    @mentions
  end

  private

  def detect_brand_mentions
    # Get all brand name variations
    brand_names = [brand.name] + brand.brand_variations.pluck(:name)

    brand_names.each do |name|
      detect_exact_matches(name)
      detect_fuzzy_matches(name) if should_use_fuzzy_matching?
    end
  end

  def detect_exact_matches(brand_name)
    # Case-insensitive exact match
    pattern = /\b#{Regexp.escape(brand_name)}\b/i

    response_text.scan(pattern).each_with_index do |match, index|
      position = calculate_position(match, index)
      context = extract_context(match)

      create_mention(
        position: position,
        context: context,
        match_type: 'exact'
      )
    end
  end

  def detect_fuzzy_matches(brand_name)
    # Use PostgreSQL trigram similarity for fuzzy matching
    # This is a simplified version - in production, use pg_trgm
    words = response_text.split(/\W+/)

    words.each_with_index do |word, index|
      similarity = calculate_similarity(word.downcase, brand_name.downcase)

      if similarity > 0.7 # 70% similarity threshold
        position = index + 1
        context = extract_context_at_position(index)

        create_mention(
          position: position,
          context: context,
          match_type: 'fuzzy',
          similarity: similarity
        )
      end
    end
  end

  def calculate_position(match, occurrence_index)
    # Calculate position in the response (1-based)
    # This is simplified - in production, parse structured responses
    sentences = response_text.split(/[.!?]+/)

    sentences.each_with_index do |sentence, index|
      return index + 1 if sentence.include?(match)
    end

    occurrence_index + 1
  end

  def extract_context(match)
    # Extract surrounding text (100 characters before and after)
    match_index = response_text.index(match)
    return match if match_index.nil?

    start_pos = [match_index - 100, 0].max
    end_pos = [match_index + match.length + 100, response_text.length].min

    response_text[start_pos...end_pos].strip
  end

  def extract_context_at_position(word_index)
    words = response_text.split(/\W+/)
    start_idx = [word_index - 10, 0].max
    end_idx = [word_index + 10, words.length - 1].min

    words[start_idx..end_idx].join(' ')
  end

  def create_mention(position:, context:, match_type:, similarity: nil)
    mention = Mention.create!(
      brand: brand,
      ai_platform: ai_platform,
      query_text: query_text,
      response_text: response_text,
      position: position,
      context: context,
      detected_at: Time.current,
      metadata: {
        match_type: match_type,
        similarity: similarity
      }.compact
    )

    # Analyze sentiment
    mention.analyze_sentiment!

    @mentions << mention
  end

  def should_use_fuzzy_matching?
    # Enable fuzzy matching for brands with common misspellings
    brand.metadata['enable_fuzzy_matching'] == true
  end

  def calculate_similarity(str1, str2)
    # Levenshtein distance-based similarity
    # This is a simple implementation - consider using a gem like 'fuzzy_match'
    longer = [str1.length, str2.length].max
    return 1.0 if longer.zero?

    distance = levenshtein_distance(str1, str2)
    (longer - distance).to_f / longer
  end

  def levenshtein_distance(str1, str2)
    matrix = Array.new(str1.length + 1) { Array.new(str2.length + 1) }

    (0..str1.length).each { |i| matrix[i][0] = i }
    (0..str2.length).each { |j| matrix[0][j] = j }

    (1..str1.length).each do |i|
      (1..str2.length).each do |j|
        cost = str1[i - 1] == str2[j - 1] ? 0 : 1
        matrix[i][j] = [
          matrix[i - 1][j] + 1,      # deletion
          matrix[i][j - 1] + 1,      # insertion
          matrix[i - 1][j - 1] + cost # substitution
        ].min
      end
    end

    matrix[str1.length][str2.length]
  end
end
```

#### Step 2: Create Brand Variations Model

```bash
rails generate model BrandVariation \
  brand:references \
  name:string \
  variation_type:string
```

```ruby
# db/migrate/XXXXXX_create_brand_variations.rb
class CreateBrandVariations < ActiveRecord::Migration[7.1]
  def change
    create_table :brand_variations, id: :uuid do |t|
      t.references :brand, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.string :variation_type # misspelling, abbreviation, alternate_name
      t.timestamps

      t.index [:brand_id, :name], unique: true
    end
  end
end
```

```ruby
# app/models/brand_variation.rb
class BrandVariation < ApplicationRecord
  belongs_to :brand

  validates :name, presence: true
  validates :name, uniqueness: { scope: :brand_id }
  validates :variation_type, inclusion: { in: %w[misspelling abbreviation alternate_name] }, allow_nil: true
end
```

```ruby
# Update app/models/brand.rb
class Brand < ApplicationRecord
  # ... existing code ...
  has_many :brand_variations, dependent: :destroy
end
```

```bash
rails db:migrate
```

#### Step 3: Create Service Tests

```ruby
# spec/services/mention_detector_spec.rb
require 'rails_helper'

RSpec.describe MentionDetector do
  let(:brand) { create(:brand, name: 'Salesforce') }
  let(:ai_platform) { create(:ai_platform) }
  let(:query_text) { 'What are the best CRM tools?' }

  describe '#execute' do
    context 'with exact brand mention' do
      let(:response_text) do
        'I recommend Salesforce as the top CRM solution. '\
        'Salesforce offers comprehensive features for sales teams.'
      end
      let(:detector) do
        described_class.new(
          brand: brand,
          query_text: query_text,
          response_text: response_text,
          ai_platform: ai_platform
        )
      end

      it 'detects exact brand mentions' do
        mentions = detector.execute

        expect(mentions.length).to eq(2)
        expect(mentions.first.brand).to eq(brand)
        expect(mentions.first.query_text).to eq(query_text)
      end

      it 'extracts context around mention' do
        mentions = detector.execute

        expect(mentions.first.context).to include('Salesforce')
        expect(mentions.first.context.length).to be > 0
      end

      it 'calculates position' do
        mentions = detector.execute

        expect(mentions.first.position).to be > 0
      end

      it 'analyzes sentiment' do
        mentions = detector.execute

        expect(mentions.first.sentiment).to be_in(%w[positive neutral negative])
      end
    end

    context 'with brand variations' do
      let!(:variation) { create(:brand_variation, brand: brand, name: 'SFDC') }
      let(:response_text) { 'SFDC is a great CRM platform.' }
      let(:detector) do
        described_class.new(
          brand: brand,
          query_text: query_text,
          response_text: response_text,
          ai_platform: ai_platform
        )
      end

      it 'detects brand variation mentions' do
        mentions = detector.execute

        expect(mentions.length).to eq(1)
        expect(mentions.first.context).to include('SFDC')
      end
    end

    context 'with no mentions' do
      let(:response_text) { 'HubSpot and Zoho are good CRM options.' }
      let(:detector) do
        described_class.new(
          brand: brand,
          query_text: query_text,
          response_text: response_text,
          ai_platform: ai_platform
        )
      end

      it 'returns empty array' do
        mentions = detector.execute

        expect(mentions).to be_empty
      end
    end

    context 'with blank response' do
      let(:response_text) { '' }
      let(:detector) do
        described_class.new(
          brand: brand,
          query_text: query_text,
          response_text: response_text,
          ai_platform: ai_platform
        )
      end

      it 'returns empty array' do
        mentions = detector.execute

        expect(mentions).to be_empty
      end
    end
  end
end
```

```ruby
# spec/factories/brand_variations.rb
FactoryBot.define do
  factory :brand_variation do
    brand
    name { Faker::Company.name }
    variation_type { 'alternate_name' }

    trait :misspelling do
      variation_type { 'misspelling' }
    end

    trait :abbreviation do
      variation_type { 'abbreviation' }
    end
  end
end
```

---

## Week 5: Background Jobs & Monitoring

### Feature 2.7: Monitoring Jobs

**Estimated Time:** 8 hours

#### Step 1: Create Platform Monitoring Job

```ruby
# app/jobs/monitoring/platform_monitoring_job.rb
module Monitoring
  class PlatformMonitoringJob < ApplicationJob
    queue_as :monitoring

    retry_on StandardError, wait: :exponentially_longer, attempts: 3

    def perform(workspace_id, brand_id, ai_platform_config_id)
      workspace = Workspace.find(workspace_id)
      brand = Brand.find(brand_id)
      config = AiPlatformConfig.find(ai_platform_config_id)

      # Skip if config is disabled or not due for monitoring
      return unless config.enabled? && config.due_for_monitoring?

      # Get the appropriate monitor class
      monitor_class = config.ai_platform.monitor_class
      monitor = monitor_class.new(
        workspace: workspace,
        brand: brand,
        ai_platform_config: config
      )

      # Execute monitoring
      result = monitor.execute

      # Log results
      log_monitoring_result(workspace, brand, config, result)

      # Broadcast updates via Turbo Stream
      broadcast_monitoring_update(workspace, brand, result)
    rescue StandardError => e
      Rails.logger.error("[PlatformMonitoringJob] Error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise
    end

    private

    def log_monitoring_result(workspace, brand, config, result)
      if result.success?
        Rails.logger.info(
          "[PlatformMonitoringJob] Success - Workspace: #{workspace.slug}, "\
          "Brand: #{brand.name}, Platform: #{config.ai_platform.name}, "\
          "Mentions: #{result.data.length}"
        )
      else
        Rails.logger.error(
          "[PlatformMonitoringJob] Failed - Workspace: #{workspace.slug}, "\
          "Brand: #{brand.name}, Platform: #{config.ai_platform.name}, "\
          "Errors: #{result.errors.inspect}"
        )
      end
    end

    def broadcast_monitoring_update(workspace, brand, result)
      # Broadcast to workspace monitoring dashboard
      Turbo::StreamsChannel.broadcast_replace_to(
        "workspace_#{workspace.id}_monitoring",
        target: "brand_#{brand.id}_status",
        partial: 'monitoring/brand_status',
        locals: { brand: brand, result: result }
      )
    end
  end
end
```

#### Step 2: Create Batch Monitoring Job

```ruby
# app/jobs/monitoring/batch_monitoring_job.rb
module Monitoring
  class BatchMonitoringJob < ApplicationJob
    queue_as :monitoring

    def perform(workspace_id = nil)
      if workspace_id
        # Monitor specific workspace
        monitor_workspace(Workspace.find(workspace_id))
      else
        # Monitor all workspaces
        Workspace.find_each do |workspace|
          monitor_workspace(workspace)
        end
      end
    end

    private

    def monitor_workspace(workspace)
      # Get all enabled AI platform configs that are due for monitoring
      configs = workspace.ai_platform_configs.due_for_monitoring

      workspace.brands.active.each do |brand|
        configs.each do |config|
          # Enqueue individual monitoring job
          PlatformMonitoringJob.perform_later(
            workspace.id,
            brand.id,
            config.id
          )
        end
      end

      Rails.logger.info(
        "[BatchMonitoringJob] Enqueued #{workspace.brands.active.count * configs.count} "\
        "monitoring jobs for workspace: #{workspace.slug}"
      )
    end
  end
end
```

#### Step 3: Configure Sidekiq Queues

```yaml
# config/sidekiq.yml (update existing file)
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

# Scheduled jobs
:schedule:
  batch_monitoring_hourly:
    cron: '0 * * * *'  # Every hour
    class: Monitoring::BatchMonitoringJob
    queue: monitoring
```

#### Step 4: Install and Configure Sidekiq-Cron

```ruby
# Gemfile
gem "sidekiq-cron", "~> 1.10"
```

```bash
bundle install
```

```ruby
# config/initializers/sidekiq.rb (update existing file)
require 'sidekiq/cron/web'

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }

  # Load schedule from sidekiq.yml
  schedule_file = 'config/sidekiq.yml'

  if File.exist?(schedule_file)
    schedule = YAML.load_file(schedule_file)

    if schedule[:schedule]
      Sidekiq::Cron::Job.load_from_hash(schedule[:schedule])
    end
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end
```

#### Step 5: Create Job Tests

```ruby
# spec/jobs/monitoring/platform_monitoring_job_spec.rb
require 'rails_helper'

RSpec.describe Monitoring::PlatformMonitoringJob, type: :job do
  let(:workspace) { create(:workspace) }
  let(:brand) { create(:brand, workspace: workspace) }
  let(:ai_platform) { create(:ai_platform) }
  let(:config) { create(:ai_platform_config, workspace: workspace, ai_platform: ai_platform) }

  describe '#perform' do
    it 'executes monitoring for the brand' do
      monitor_double = instance_double(AiPlatforms::BaseMonitor)
      allow(AiPlatforms::BaseMonitor).to receive(:new).and_return(monitor_double)
      allow(monitor_double).to receive(:execute).and_return(
        OpenStruct.new(success?: true, data: [], errors: [])
      )

      described_class.perform_now(workspace.id, brand.id, config.id)

      expect(monitor_double).to have_received(:execute)
    end

    it 'skips disabled configs' do
      config.update!(enabled: false)

      monitor_double = instance_double(AiPlatforms::BaseMonitor)
      allow(AiPlatforms::BaseMonitor).to receive(:new).and_return(monitor_double)

      described_class.perform_now(workspace.id, brand.id, config.id)

      expect(monitor_double).not_to have_received(:execute)
    end

    it 'skips configs not due for monitoring' do
      config.update!(last_monitored_at: 10.minutes.ago, monitoring_frequency: 'daily')

      monitor_double = instance_double(AiPlatforms::BaseMonitor)
      allow(AiPlatforms::BaseMonitor).to receive(:new).and_return(monitor_double)

      described_class.perform_now(workspace.id, brand.id, config.id)

      expect(monitor_double).not_to have_received(:execute)
    end
  end
end

# spec/jobs/monitoring/batch_monitoring_job_spec.rb
require 'rails_helper'

RSpec.describe Monitoring::BatchMonitoringJob, type: :job do
  let!(:workspace) { create(:workspace) }
  let!(:brand) { create(:brand, workspace: workspace) }
  let!(:ai_platform) { create(:ai_platform) }
  let!(:config) { create(:ai_platform_config, :due_for_monitoring, workspace: workspace, ai_platform: ai_platform) }

  describe '#perform' do
    it 'enqueues monitoring jobs for all brands and configs' do
      expect {
        described_class.perform_now(workspace.id)
      }.to have_enqueued_job(Monitoring::PlatformMonitoringJob).at_least(1).times
    end

    it 'processes all workspaces when no workspace_id provided' do
      workspace2 = create(:workspace)
      brand2 = create(:brand, workspace: workspace2)
      config2 = create(:ai_platform_config, :due_for_monitoring, workspace: workspace2, ai_platform: ai_platform)

      expect {
        described_class.perform_now
      }.to have_enqueued_job(Monitoring::PlatformMonitoringJob).at_least(2).times
    end
  end
end
```

---

## Week 5-6: Monitoring Dashboard

### Feature 2.8: Monitoring Dashboard

**Estimated Time:** 10 hours

#### Step 1: Create Monitoring Controllers

```ruby
# app/controllers/monitoring_jobs_controller.rb
class MonitoringJobsController < ApplicationController
  def index
    @ai_platform_configs = current_workspace.ai_platform_configs.includes(:ai_platform)
    @recent_jobs = recent_monitoring_jobs
  end

  def trigger
    brand = current_workspace.brands.find(params[:brand_id])
    config = current_workspace.ai_platform_configs.find(params[:config_id])

    Monitoring::PlatformMonitoringJob.perform_later(
      current_workspace.id,
      brand.id,
      config.id
    )

    respond_to do |format|
      format.html { redirect_to workspace_monitoring_jobs_path(current_workspace), notice: 'Monitoring job started' }
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "brand_#{brand.id}_status",
          partial: 'monitoring_jobs/brand_status',
          locals: { brand: brand, status: 'running' }
        )
      end
    end
  end

  def trigger_all
    Monitoring::BatchMonitoringJob.perform_later(current_workspace.id)

    redirect_to workspace_monitoring_jobs_path(current_workspace),
                notice: 'Batch monitoring started for all brands'
  end

  private

  def recent_monitoring_jobs
    # Get recent Sidekiq jobs for this workspace
    # This is a simplified version - in production, store job history in DB
    []
  end
end
```

```ruby
# app/controllers/mentions_controller.rb
class MentionsController < ApplicationController
  before_action :set_brand, only: [:index]

  def index
    @mentions = @brand.mentions
                      .includes(:ai_platform, :citations)
                      .recent
                      .page(params[:page])
                      .per(20)

    @mention_stats = calculate_mention_stats

    respond_to do |format|
      format.html
      format.json { render json: @mentions }
    end
  end

  def show
    @mention = Mention.find(params[:id])
    @brand = @mention.brand
  end

  private

  def set_brand
    @brand = current_workspace.brands.find(params[:brand_id])
  end

  def calculate_mention_stats
    {
      total: @brand.mentions.count,
      last_7_days: @brand.mentions.last_7_days.count,
      last_30_days: @brand.mentions.last_30_days.count,
      by_platform: @brand.mentions_by_platform,
      by_sentiment: @brand.mentions.group(:sentiment).count,
      avg_position: @brand.average_mention_position
    }
  end
end
```

#### Step 2: Update Routes

```ruby
# config/routes.rb (update workspace-scoped routes)
scope ':workspace_slug', as: :workspace do
  get '/', to: 'dashboard#index', as: :dashboard

  resources :brands do
    resources :mentions, only: [:index, :show]
    resources :visibility_scores, only: [:index]
  end

  # Monitoring routes
  resources :monitoring_jobs, only: [:index] do
    collection do
      post :trigger_all
    end
    member do
      post :trigger
    end
  end

  resources :settings, only: [:index, :update]
  resources :team_members, only: [:index, :create, :destroy]
end
```

#### Step 3: Create Monitoring Dashboard View

```erb
<!-- app/views/monitoring_jobs/index.html.erb -->
<div class="space-y-6" data-controller="monitoring-dashboard">
  <div class="flex justify-between items-center">
    <h1 class="text-2xl font-bold text-gray-900">Monitoring Dashboard</h1>
    <%= button_to "Run All Monitors",
        trigger_all_workspace_monitoring_jobs_path(current_workspace),
        method: :post,
        class: "inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700",
        data: { turbo: false } %>
  </div>

  <!-- AI Platform Configs -->
  <div class="bg-white shadow overflow-hidden sm:rounded-lg">
    <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
      <h3 class="text-lg leading-6 font-medium text-gray-900">AI Platform Configurations</h3>
      <p class="mt-1 text-sm text-gray-500">Manage your AI platform monitoring settings</p>
    </div>

    <div class="px-4 py-5 sm:p-6">
      <div class="space-y-4">
        <% @ai_platform_configs.each do |config| %>
          <div class="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
            <div class="flex items-center space-x-4">
              <div class="flex-shrink-0">
                <% if config.enabled? %>
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                    Active
                  </span>
                <% else %>
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                    Inactive
                  </span>
                <% end %>
              </div>
              <div>
                <h4 class="text-sm font-medium text-gray-900"><%= config.ai_platform.name %></h4>
                <p class="text-sm text-gray-500">
                  Frequency: <%= config.monitoring_frequency.titleize %>
                  <% if config.last_monitored_at %>
                    | Last monitored: <%= time_ago_in_words(config.last_monitored_at) %> ago
                  <% else %>
                    | Never monitored
                  <% end %>
                </p>
              </div>
            </div>
            <div class="flex items-center space-x-2">
              <% if config.due_for_monitoring? %>
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                  Due for monitoring
                </span>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
  </div>

  <!-- Brands Monitoring Status -->
  <div class="bg-white shadow overflow-hidden sm:rounded-lg">
    <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
      <h3 class="text-lg leading-6 font-medium text-gray-900">Brand Monitoring Status</h3>
    </div>

    <div class="divide-y divide-gray-200">
      <% current_workspace.brands.active.each do |brand| %>
        <%= turbo_frame_tag "brand_#{brand.id}_status" do %>
          <%= render 'monitoring_jobs/brand_status', brand: brand %>
        <% end %>
      <% end %>
    </div>
  </div>

  <!-- Recent Mentions Chart -->
  <div class="bg-white shadow overflow-hidden sm:rounded-lg">
    <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
      <h3 class="text-lg leading-6 font-medium text-gray-900">Mention Trends (Last 30 Days)</h3>
    </div>
    <div class="px-4 py-5 sm:p-6">
      <%= render 'monitoring_jobs/mention_chart' %>
    </div>
  </div>
</div>
```

#### Step 4: Create Brand Status Partial

```erb
<!-- app/views/monitoring_jobs/_brand_status.html.erb -->
<div class="px-4 py-4 sm:px-6">
  <div class="flex items-center justify-between">
    <div class="flex-1">
      <h4 class="text-sm font-medium text-gray-900"><%= brand.name %></h4>
      <div class="mt-2 flex items-center space-x-4 text-sm text-gray-500">
        <span>
          <strong><%= brand.mentions.last_7_days.count %></strong> mentions (7d)
        </span>
        <span>
          <strong><%= brand.mentions.last_30_days.count %></strong> mentions (30d)
        </span>
        <span>
          Avg Position: <strong><%= brand.average_mention_position %></strong>
        </span>
      </div>
    </div>
    <div class="flex items-center space-x-2">
      <% current_workspace.ai_platform_configs.enabled.each do |config| %>
        <%= button_to trigger_workspace_monitoring_job_path(current_workspace, brand_id: brand.id, config_id: config.id),
            method: :post,
            class: "inline-flex items-center px-3 py-1.5 border border-gray-300 shadow-sm text-xs font-medium rounded text-gray-700 bg-white hover:bg-gray-50",
            data: { turbo_frame: "brand_#{brand.id}_status" } do %>
          Monitor on <%= config.ai_platform.name %>
        <% end %>
      <% end %>
      <%= link_to "View Mentions",
          workspace_brand_mentions_path(current_workspace, brand),
          class: "inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-medium rounded text-indigo-700 bg-indigo-100 hover:bg-indigo-200" %>
    </div>
  </div>
</div>
```

#### Step 5: Create Mention Chart Partial (with Chartkick)

```ruby
# Gemfile
gem "chartkick", "~> 5.0"
gem "groupdate", "~> 6.0"
```

```bash
bundle install
```

```javascript
// app/javascript/application.js (add)
import "chartkick"
import "Chart.bundle"
```

```erb
<!-- app/views/monitoring_jobs/_mention_chart.html.erb -->
<%= line_chart current_workspace.brands.active.map { |brand|
  {
    name: brand.name,
    data: brand.mentions.last_30_days.group_by_day(:detected_at).count
  }
},
  height: "300px",
  colors: ["#4F46E5", "#10B981", "#F59E0B", "#EF4444"],
  library: {
    scales: {
      y: {
        beginAtZero: true
      }
    }
  }
%>
```

#### Step 6: Create Mentions Index View

```erb
<!-- app/views/mentions/index.html.erb -->
<div class="space-y-6">
  <div class="flex justify-between items-center">
    <div>
      <h1 class="text-2xl font-bold text-gray-900"><%= @brand.name %> - Mentions</h1>
      <p class="mt-1 text-sm text-gray-500">Track all AI platform mentions for this brand</p>
    </div>
    <%= link_to "Back to Dashboard",
        workspace_dashboard_path(current_workspace),
        class: "inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50" %>
  </div>

  <!-- Stats Cards -->
  <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
    <div class="bg-white overflow-hidden shadow rounded-lg">
      <div class="p-5">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z"/>
            </svg>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Total Mentions</dt>
              <dd class="text-3xl font-semibold text-gray-900"><%= @mention_stats[:total] %></dd>
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
              <dt class="text-sm font-medium text-gray-500 truncate">Last 7 Days</dt>
              <dd class="text-3xl font-semibold text-gray-900"><%= @mention_stats[:last_7_days] %></dd>
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
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 10h4.764a2 2 0 011.789 2.894l-3.5 7A2 2 0 0115.263 21h-4.017c-.163 0-.326-.02-.485-.06L7 20m7-10V5a2 2 0 00-2-2h-.095c-.5 0-.905.405-.905.905 0 .714-.211 1.412-.608 2.006L7 11v9m7-10h-2M7 20H5a2 2 0 01-2-2v-6a2 2 0 012-2h2.5"/>
            </svg>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Positive Sentiment</dt>
              <dd class="text-3xl font-semibold text-gray-900"><%= @mention_stats[:by_sentiment]['positive'] || 0 %></dd>
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
              <dt class="text-sm font-medium text-gray-500 truncate">Avg Position</dt>
              <dd class="text-3xl font-semibold text-gray-900"><%= @mention_stats[:avg_position] %></dd>
            </dl>
          </div>
        </div>
      </div>
    </div>
  </div>

  <!-- Platform Breakdown -->
  <div class="bg-white shadow overflow-hidden sm:rounded-lg">
    <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
      <h3 class="text-lg leading-6 font-medium text-gray-900">Mentions by Platform</h3>
    </div>
    <div class="px-4 py-5 sm:p-6">
      <%= column_chart @mention_stats[:by_platform], height: "200px" %>
    </div>
  </div>

  <!-- Mentions List -->
  <div class="bg-white shadow overflow-hidden sm:rounded-lg">
    <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
      <h3 class="text-lg leading-6 font-medium text-gray-900">Recent Mentions</h3>
    </div>

    <ul class="divide-y divide-gray-200">
      <% @mentions.each do |mention| %>
        <li class="px-4 py-4 sm:px-6 hover:bg-gray-50">
          <div class="flex items-start justify-between">
            <div class="flex-1">
              <div class="flex items-center space-x-2 mb-2">
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                  <%= mention.ai_platform&.name || 'Unknown' %>
                </span>
                <% if mention.sentiment %>
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium <%= sentiment_badge_class(mention.sentiment) %>">
                    <%= mention.sentiment.titleize %>
                  </span>
                <% end %>
                <% if mention.position %>
                  <span class="text-xs text-gray-500">Position: #<%= mention.position %></span>
                <% end %>
                <span class="text-xs text-gray-500"><%= time_ago_in_words(mention.detected_at) %> ago</span>
              </div>
              <p class="text-sm font-medium text-gray-900 mb-1">Query: <%= mention.query_text %></p>
              <p class="text-sm text-gray-600"><%= truncate(mention.context, length: 200) %></p>
            </div>
            <div class="ml-4">
              <%= link_to "View Details",
                  workspace_brand_mention_path(current_workspace, @brand, mention),
                  class: "inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-medium rounded text-indigo-700 bg-indigo-100 hover:bg-indigo-200" %>
            </div>
          </div>
        </li>
      <% end %>
    </ul>

    <% if @mentions.any? %>
      <div class="px-4 py-3 border-t border-gray-200 sm:px-6">
        <%== pagy_nav(@pagy) if defined?(@pagy) %>
      </div>
    <% else %>
      <div class="text-center py-12">
        <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-5l-5 5v-5z"/>
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">No mentions yet</h3>
        <p class="mt-1 text-sm text-gray-500">Start monitoring to detect brand mentions.</p>
      </div>
    <% end %>
  </div>
</div>
```

#### Step 7: Create Helper Methods

```ruby
# app/helpers/mentions_helper.rb
module MentionsHelper
  def sentiment_badge_class(sentiment)
    case sentiment
    when 'positive'
      'bg-green-100 text-green-800'
    when 'negative'
      'bg-red-100 text-red-800'
    when 'neutral'
      'bg-gray-100 text-gray-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end
end
```

---

## Week 6: Brand Monitoring Setup

### Feature 2.9: Brand Monitoring Setup

**Estimated Time:** 6 hours

#### Step 1: Create Settings Controller

```ruby
# app/controllers/settings_controller.rb
class SettingsController < ApplicationController
  before_action :authorize_workspace_admin!

  def index
    @workspace = current_workspace
    @ai_platforms = AiPlatform.active
    @ai_platform_configs = current_workspace.ai_platform_configs.includes(:ai_platform)
  end

  def update
    @workspace = current_workspace

    if @workspace.update(workspace_params)
      redirect_to workspace_settings_path(current_workspace), notice: 'Settings updated successfully'
    else
      render :index, status: :unprocessable_entity
    end
  end

  def update_platform_config
    config = current_workspace.ai_platform_configs.find_or_initialize_by(
      ai_platform_id: params[:ai_platform_id]
    )

    if config.update(platform_config_params)
      redirect_to workspace_settings_path(current_workspace), notice: 'Platform configuration updated'
    else
      redirect_to workspace_settings_path(current_workspace), alert: 'Failed to update configuration'
    end
  end

  private

  def workspace_params
    params.require(:workspace).permit(:name, settings: {})
  end

  def platform_config_params
    params.require(:ai_platform_config).permit(
      :enabled,
      :api_key_encrypted,
      :monitoring_frequency,
      settings: {}
    )
  end
end
```

#### Step 2: Update Routes

```ruby
# config/routes.rb (update workspace-scoped routes)
scope ':workspace_slug', as: :workspace do
  # ... existing routes ...

  resources :settings, only: [:index, :update] do
    collection do
      post :update_platform_config
    end
  end
end
```

#### Step 3: Create Settings View

```erb
<!-- app/views/settings/index.html.erb -->
<div class="space-y-6">
  <div>
    <h1 class="text-2xl font-bold text-gray-900">Workspace Settings</h1>
    <p class="mt-1 text-sm text-gray-500">Manage your workspace and AI platform configurations</p>
  </div>

  <!-- Workspace Settings -->
  <div class="bg-white shadow overflow-hidden sm:rounded-lg">
    <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
      <h3 class="text-lg leading-6 font-medium text-gray-900">Workspace Information</h3>
    </div>
    <div class="px-4 py-5 sm:p-6">
      <%= form_with model: @workspace, url: workspace_settings_path(current_workspace), method: :patch, class: "space-y-6" do |f| %>
        <div>
          <%= f.label :name, class: "block text-sm font-medium text-gray-700" %>
          <%= f.text_field :name,
              class: "mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm" %>
        </div>

        <div>
          <%= f.submit "Save Changes",
              class: "inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700" %>
        </div>
      <% end %>
    </div>
  </div>

  <!-- AI Platform Configurations -->
  <div class="bg-white shadow overflow-hidden sm:rounded-lg">
    <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
      <h3 class="text-lg leading-6 font-medium text-gray-900">AI Platform Configurations</h3>
      <p class="mt-1 text-sm text-gray-500">Configure API keys and monitoring settings for each AI platform</p>
    </div>
    <div class="px-4 py-5 sm:p-6">
      <div class="space-y-6">
        <% @ai_platforms.each do |platform| %>
          <% config = @ai_platform_configs.find { |c| c.ai_platform_id == platform.id } || current_workspace.ai_platform_configs.build(ai_platform: platform) %>

          <%= form_with model: config,
              url: update_platform_config_workspace_settings_path(current_workspace, ai_platform_id: platform.id),
              method: :post,
              class: "border border-gray-200 rounded-lg p-6" do |f| %>

            <div class="flex items-center justify-between mb-4">
              <div>
                <h4 class="text-base font-medium text-gray-900"><%= platform.name %></h4>
                <p class="text-sm text-gray-500"><%= platform.metadata['description'] %></p>
              </div>
              <div class="flex items-center">
                <%= f.label :enabled, class: "mr-2 text-sm font-medium text-gray-700" do %>
                  Enabled
                <% end %>
                <%= f.check_box :enabled,
                    class: "h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded" %>
              </div>
            </div>

            <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
              <div>
                <%= f.label :api_key_encrypted, "API Key", class: "block text-sm font-medium text-gray-700" %>
                <%= f.password_field :api_key_encrypted,
                    placeholder: config.persisted? ? "••••••••••••" : "Enter API key",
                    class: "mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm" %>
                <p class="mt-1 text-xs text-gray-500">
                  Get your API key from <%= link_to "#{platform.name} dashboard", platform.metadata['api_docs_url'], target: '_blank', class: 'text-indigo-600 hover:text-indigo-500' if platform.metadata['api_docs_url'] %>
                </p>
              </div>

              <div>
                <%= f.label :monitoring_frequency, class: "block text-sm font-medium text-gray-700" %>
                <%= f.select :monitoring_frequency,
                    [['Hourly', 'hourly'], ['Daily', 'daily'], ['Weekly', 'weekly']],
                    {},
                    class: "mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm" %>
              </div>
            </div>

            <% if config.last_monitored_at %>
              <div class="mt-4 text-sm text-gray-500">
                Last monitored: <%= time_ago_in_words(config.last_monitored_at) %> ago
              </div>
            <% end %>

            <div class="mt-6">
              <%= f.submit "Save #{platform.name} Configuration",
                  class: "inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700" %>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
  </div>

  <!-- Brand Variations -->
  <div class="bg-white shadow overflow-hidden sm:rounded-lg">
    <div class="px-4 py-5 sm:px-6 border-b border-gray-200">
      <h3 class="text-lg leading-6 font-medium text-gray-900">Brand Name Variations</h3>
      <p class="mt-1 text-sm text-gray-500">Add alternate names, abbreviations, and common misspellings for better detection</p>
    </div>
    <div class="px-4 py-5 sm:p-6">
      <% current_workspace.brands.each do |brand| %>
        <div class="mb-6 pb-6 border-b border-gray-200 last:border-b-0">
          <h4 class="text-sm font-medium text-gray-900 mb-3"><%= brand.name %></h4>

          <div class="space-y-2">
            <% brand.brand_variations.each do |variation| %>
              <div class="flex items-center justify-between py-2 px-3 bg-gray-50 rounded">
                <div>
                  <span class="text-sm text-gray-900"><%= variation.name %></span>
                  <span class="ml-2 inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-200 text-gray-800">
                    <%= variation.variation_type&.titleize || 'Variation' %>
                  </span>
                </div>
                <%= button_to "Remove",
                    workspace_brand_variation_path(current_workspace, brand, variation),
                    method: :delete,
                    class: "text-sm text-red-600 hover:text-red-800",
                    data: { confirm: 'Are you sure?' } %>
              </div>
            <% end %>
          </div>

          <%= link_to "Add Variation",
              new_workspace_brand_variation_path(current_workspace, brand),
              class: "mt-3 inline-flex items-center px-3 py-1.5 border border-gray-300 shadow-sm text-xs font-medium rounded text-gray-700 bg-white hover:bg-gray-50" %>
        </div>
      <% end %>
    </div>
  </div>
</div>
```

#### Step 4: Create Stimulus Controller for Real-time Updates

```javascript
// app/javascript/controllers/monitoring_dashboard_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("Monitoring dashboard connected")

    // Subscribe to Turbo Stream updates
    this.subscription = this.createSubscription()
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  createSubscription() {
    const workspaceId = this.element.dataset.workspaceId

    if (!workspaceId) return null

    // This would connect to ActionCable for real-time updates
    // For now, we'll use polling as a simpler alternative
    this.startPolling()
  }

  startPolling() {
    // Poll for updates every 30 seconds
    this.pollingInterval = setInterval(() => {
      this.refreshStatus()
    }, 30000)
  }

  refreshStatus() {
    // Trigger a Turbo Frame refresh
    const frames = this.element.querySelectorAll('turbo-frame[id^="brand_"]')
    frames.forEach(frame => {
      frame.reload()
    })
  }

  stopPolling() {
    if (this.pollingInterval) {
      clearInterval(this.pollingInterval)
    }
  }
}
```

#### Step 5: Create Controller Tests

```ruby
# spec/controllers/monitoring_jobs_controller_spec.rb
require 'rails_helper'

RSpec.describe MonitoringJobsController, type: :controller do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace) }
  let!(:membership) { create(:workspace_membership, user: user, workspace: workspace, role: 'owner') }
  let(:brand) { create(:brand, workspace: workspace) }
  let(:ai_platform) { create(:ai_platform) }
  let(:config) { create(:ai_platform_config, workspace: workspace, ai_platform: ai_platform) }

  before do
    sign_in(user)
    allow(controller).to receive(:current_workspace).and_return(workspace)
  end

  describe 'GET #index' do
    it 'returns success' do
      get :index, params: { workspace_slug: workspace.slug }
      expect(response).to be_successful
    end
  end

  describe 'POST #trigger' do
    it 'enqueues monitoring job' do
      expect {
        post :trigger, params: {
          workspace_slug: workspace.slug,
          brand_id: brand.id,
          config_id: config.id
        }
      }.to have_enqueued_job(Monitoring::PlatformMonitoringJob)
    end
  end

  describe 'POST #trigger_all' do
    it 'enqueues batch monitoring job' do
      expect {
        post :trigger_all, params: { workspace_slug: workspace.slug }
      }.to have_enqueued_job(Monitoring::BatchMonitoringJob)
    end
  end
end

# spec/controllers/settings_controller_spec.rb
require 'rails_helper'

RSpec.describe SettingsController, type: :controller do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace) }
  let!(:membership) { create(:workspace_membership, user: user, workspace: workspace, role: 'owner') }

  before do
    sign_in(user)
    allow(controller).to receive(:current_workspace).and_return(workspace)
  end

  describe 'GET #index' do
    it 'returns success' do
      get :index, params: { workspace_slug: workspace.slug }
      expect(response).to be_successful
    end
  end

  describe 'PATCH #update' do
    it 'updates workspace settings' do
      patch :update, params: {
        workspace_slug: workspace.slug,
        workspace: { name: 'New Name' }
      }

      expect(workspace.reload.name).to eq('New Name')
      expect(response).to redirect_to(workspace_settings_path(workspace))
    end
  end

  describe 'POST #update_platform_config' do
    let(:ai_platform) { create(:ai_platform) }

    it 'creates or updates platform config' do
      expect {
        post :update_platform_config, params: {
          workspace_slug: workspace.slug,
          ai_platform_id: ai_platform.id,
          ai_platform_config: {
            enabled: true,
            api_key_encrypted: 'test_key',
            monitoring_frequency: 'daily'
          }
        }
      }.to change(AiPlatformConfig, :count).by(1)
    end
  end
end
```

---

## Completion Checklist

### Week 3: Data Models & Base Services
- [ ] AI Platform model created with validations and scopes
- [ ] AI Platform Config model created with encryption
- [ ] Seed data for AI platforms (ChatGPT, Claude, Perplexity, Gemini)
- [ ] Mention model created with TimescaleDB hypertable
- [ ] Citation model created
- [ ] Brand variations model created
- [ ] All model tests passing
- [ ] Base Monitor service created
- [ ] Base Monitor service tests passing

### Week 4: Platform Monitors & Detection
- [ ] ChatGPT Monitor service implemented
- [ ] ChatGPT Monitor tests with VCR cassettes
- [ ] Claude Monitor service implemented
- [ ] Claude Monitor tests with VCR cassettes
- [ ] Mention Detector service implemented
- [ ] Mention Detector tests passing
- [ ] Fuzzy matching logic implemented
- [ ] Sentiment analysis placeholder implemented

### Week 5: Background Jobs
- [ ] Platform Monitoring Job created
- [ ] Batch Monitoring Job created
- [ ] Sidekiq queues configured
- [ ] Sidekiq-cron installed and configured
- [ ] Job scheduling configured
- [ ] Job tests passing
- [ ] Error handling and logging implemented

### Week 5-6: Monitoring Dashboard
- [ ] Monitoring Jobs controller created
- [ ] Mentions controller created
- [ ] Routes updated for monitoring
- [ ] Monitoring dashboard view created
- [ ] Brand status partial created
- [ ] Mention chart with Chartkick implemented
- [ ] Mentions index view created
- [ ] Real-time updates with Turbo Streams
- [ ] Stimulus controllers for interactivity

### Week 6: Brand Monitoring Setup
- [ ] Settings controller created
- [ ] Settings view created
- [ ] AI platform configuration forms
- [ ] Brand variations management
- [ ] Controller tests passing
- [ ] Integration tests for monitoring flow

### Testing & Quality
- [ ] All model tests passing (>90% coverage)
- [ ] All service tests passing (>90% coverage)
- [ ] All job tests passing (>90% coverage)
- [ ] All controller tests passing (>90% coverage)
- [ ] VCR cassettes recorded for API calls
- [ ] No N+1 queries (verified with Bullet)
- [ ] Code reviewed and refactored

### Documentation
- [ ] API keys documented in .env.example
- [ ] README updated with Phase 2 setup instructions
- [ ] Monitoring workflow documented
- [ ] Troubleshooting guide created

### Deployment Readiness
- [ ] Environment variables configured
- [ ] Database migrations tested
- [ ] Background jobs tested in staging
- [ ] Rate limiting verified
- [ ] Error monitoring configured (e.g., Sentry)
- [ ] Performance benchmarks established

---

## Next Steps

After completing Phase 2, you will have:
- ✅ Full AI platform monitoring infrastructure
- ✅ Real-time mention detection and tracking
- ✅ Background job processing with Sidekiq
- ✅ Interactive monitoring dashboard
- ✅ Brand configuration and management

**Phase 3 Preview:** Analytics & Reporting
- Visibility score calculations
- Competitor tracking
- Advanced analytics dashboard
- Report generation
- Email notifications
- API endpoints

---

## Troubleshooting

### Common Issues

**Issue: TimescaleDB extension not available**
```bash
# Install TimescaleDB
brew install timescaledb
timescaledb-tune --quiet --yes

# Restart PostgreSQL
brew services restart postgresql
```

**Issue: OpenAI API rate limits**
```ruby
# Adjust rate limiting in ai_platform seeds
AiPlatform.find_by(slug: 'chatgpt').update(rate_limit_per_minute: 20)
```

**Issue: Sidekiq jobs not processing**
```bash
# Check Redis connection
redis-cli ping

# Restart Sidekiq
bundle exec sidekiq -C config/sidekiq.yml
```

**Issue: VCR cassettes failing**
```ruby
# Re-record cassettes
VCR.configure do |config|
  config.default_cassette_options = { record: :new_episodes }
end
```

---

## Performance Optimization Tips

1. **Database Indexes**: Ensure all foreign keys and frequently queried columns have indexes
2. **Caching**: Use Rails.cache for expensive queries (visibility scores, mention counts)
3. **Background Jobs**: Use appropriate queue priorities for time-sensitive tasks
4. **Rate Limiting**: Respect API rate limits to avoid throttling
5. **Batch Processing**: Process multiple brands in parallel when possible
6. **TimescaleDB**: Leverage continuous aggregates for time-series queries

---

**End of Phase 2 Implementation Guide**

