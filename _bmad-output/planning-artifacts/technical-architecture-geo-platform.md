---
document_type: Technical Architecture Design
product_name: GEO Platform (Working Title)
version: 1.0
date: 2026-01-23
author: David Geismar
status: Draft
tech_stack: Ruby on Rails, PostgreSQL, Redis, Sidekiq, Tailwind CSS
---

# Technical Architecture Design: GEO Platform

## Executive Summary

This document provides a comprehensive technical architecture for the GEO (Generative Engine Optimization) platform built on **Ruby on Rails** with **PostgreSQL**, **Redis**, **Sidekiq**, and **Tailwind CSS**.

### Technology Stack Overview

**Backend Framework:** Ruby on Rails 7.x
**Database:** PostgreSQL 15+ (with extensions)
**Cache & Job Queue:** Redis 7+
**Background Jobs:** Sidekiq
**Frontend:** Rails Views with Hotwire (Turbo + Stimulus) + Tailwind CSS
**API:** Rails API mode for external integrations
**Hosting:** Heroku, Render, or AWS (recommendations provided)

---

## System Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  Web Browser │  │  Mobile Web  │  │  API Clients │          │
│  │  (Turbo)     │  │  (Responsive)│  │  (REST/JSON) │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    APPLICATION LAYER (Rails)                     │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Rails Application Server (Puma)                         │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐        │   │
│  │  │Controllers │  │   Models   │  │   Views    │        │   │
│  │  │  (MVC)     │  │(ActiveRec.)│  │(Turbo+Tail)│        │   │
│  │  └────────────┘  └────────────┘  └────────────┘        │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐        │   │
│  │  │  Services  │  │   Jobs     │  │    API     │        │   │
│  │  │  (Business)│  │  (Sidekiq) │  │ (REST/JSON)│        │   │
│  │  └────────────┘  └────────────┘  └────────────┘        │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    BACKGROUND PROCESSING                         │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Sidekiq Workers (Redis-backed)                          │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐        │   │
│  │  │AI Platform │  │  Mention   │  │  Scoring   │        │   │
│  │  │  Monitor   │  │  Detection │  │  Engine    │        │   │
│  │  └────────────┘  └────────────┘  └────────────┘        │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐        │   │
│  │  │ Sentiment  │  │  Citation  │  │   Alerts   │        │   │
│  │  │  Analysis  │  │  Tracking  │  │  & Emails  │        │   │
│  │  └────────────┘  └────────────┘  └────────────┘        │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    EXTERNAL SERVICES LAYER                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ AI Platform  │  │   NLP/ML     │  │  Email/SMS   │          │
│  │    APIs      │  │   Services   │  │   Services   │          │
│  │(OpenAI, etc.)│  │(OpenAI, etc.)│  │(SendGrid)    │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                      DATA STORAGE LAYER                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  PostgreSQL  │  │     Redis    │  │  Object      │          │
│  │  (Primary)   │  │(Cache + Jobs)│  │  Storage     │          │
│  │  + TimescaleDB│  │              │  │  (S3/R2)     │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

---

## Technology Stack Deep Dive

### Backend: Ruby on Rails 7.x

**Why Rails?**
- Mature, battle-tested framework
- Convention over configuration (rapid development)
- Excellent for MVPs and scaling to production
- Strong ecosystem of gems
- Built-in security features
- ActiveRecord ORM for database interactions

**Rails Features We'll Use:**
- **ActiveRecord:** Database models and associations
- **ActiveJob:** Background job interface (Sidekiq adapter)
- **ActionCable:** WebSockets for real-time updates (optional)
- **ActiveStorage:** File uploads (for reports, exports)
- **ActionMailer:** Email notifications
- **Hotwire (Turbo + Stimulus):** Modern frontend without heavy JavaScript
- **Rails API mode:** For external API endpoints

**Rails Version:** 7.1+ (latest stable)
**Ruby Version:** 3.2+ (performance improvements)

---

### Database: PostgreSQL 15+

**Why PostgreSQL?**
- Most powerful open-source relational database
- Excellent JSON support (JSONB columns)
- Full-text search capabilities
- Advanced indexing (GIN, GiST, BRIN)
- Time-series data support (with TimescaleDB extension)
- Mature Rails integration via ActiveRecord

**PostgreSQL Extensions We'll Use:**

1. **pg_trgm** - Trigram matching for fuzzy search
2. **TimescaleDB** - Time-series data optimization (for metrics, trends)
3. **pgvector** - Vector similarity search (for semantic search, optional)
4. **hstore** - Key-value storage (for flexible metadata)
5. **uuid-ossp** - UUID generation for primary keys

**Database Configuration:**
```ruby
# config/database.yml
production:
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000
  extensions:
    - pg_trgm
    - timescaledb
    - hstore
    - uuid-ossp
```

---

### Cache & Background Jobs: Redis + Sidekiq

**Redis Use Cases:**
1. **Cache:** Fragment caching, query caching, session storage
2. **Job Queue:** Sidekiq job queue and processing
3. **Rate Limiting:** API rate limiting, crawler throttling
4. **Real-time Data:** Pub/Sub for real-time updates (optional)
5. **Temporary Data:** Store API responses, processing state

**Sidekiq Configuration:**
- **Queues:** Separate queues by priority and job type
- **Concurrency:** Tune based on server resources
- **Retry Logic:** Exponential backoff for failed jobs
- **Monitoring:** Sidekiq Web UI for job monitoring

**Sidekiq Queues Strategy:**
```ruby
# config/sidekiq.yml
:queues:
  - [critical, 10]    # Alerts, urgent processing
  - [default, 5]      # Standard jobs
  - [monitoring, 3]   # AI platform monitoring
  - [analysis, 2]     # Sentiment, scoring
  - [low, 1]          # Reports, exports, cleanup
```

---

### Frontend: Hotwire (Turbo + Stimulus) + Tailwind CSS

**Why Hotwire?**
- Modern, reactive UI without heavy JavaScript frameworks
- Server-rendered HTML (SEO-friendly, fast initial load)
- Turbo Drive: SPA-like navigation
- Turbo Frames: Partial page updates
- Turbo Streams: Real-time updates over WebSockets
- Stimulus: Lightweight JavaScript for interactivity

**Why Tailwind CSS?**
- Utility-first CSS framework
- Rapid UI development
- Consistent design system
- Small production bundle (with PurgeCSS)
- Excellent Rails integration

**Frontend Stack:**
- **Tailwind CSS 3.x:** Styling
- **Tailwind UI / DaisyUI / Flowbite:** Component libraries (optional)
- **Stimulus:** JavaScript controllers
- **Turbo:** SPA-like experience
- **ViewComponent:** Reusable view components (optional but recommended)
- **Chartkick + Chart.js:** Charts and graphs

---

## Database Schema Design

### Core Tables

#### 1. Users & Authentication

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_secure_password
  has_many :workspaces, through: :workspace_memberships
  has_many :workspace_memberships
  has_many :owned_workspaces, class_name: 'Workspace', foreign_key: 'owner_id'
end

# Schema
create_table :users do |t|
  t.string :email, null: false, index: { unique: true }
  t.string :password_digest, null: false
  t.string :name
  t.string :role, default: 'user' # user, admin
  t.datetime :confirmed_at
  t.string :confirmation_token
  t.datetime :last_sign_in_at
  t.timestamps
end
```

#### 2. Workspaces (Multi-tenancy)

```ruby
# app/models/workspace.rb
class Workspace < ApplicationRecord
  belongs_to :owner, class_name: 'User'
  has_many :workspace_memberships
  has_many :users, through: :workspace_memberships
  has_many :brands
  has_many :ai_platform_configs
end

# Schema
create_table :workspaces do |t|
  t.string :name, null: false
  t.string :slug, null: false, index: { unique: true }
  t.references :owner, null: false, foreign_key: { to_table: :users }
  t.string :plan, default: 'free' # free, starter, professional, enterprise
  t.jsonb :settings, default: {}
  t.datetime :trial_ends_at
  t.timestamps
end

create_table :workspace_memberships do |t|
  t.references :workspace, null: false, foreign_key: true
  t.references :user, null: false, foreign_key: true
  t.string :role, default: 'viewer' # admin, editor, viewer
  t.timestamps

  t.index [:workspace_id, :user_id], unique: true
end
```

#### 3. Brands (What we're monitoring)

```ruby
# app/models/brand.rb
class Brand < ApplicationRecord
  belongs_to :workspace
  has_many :brand_variations
  has_many :mentions
  has_many :visibility_scores
  has_many :competitors
end

# Schema
create_table :brands do |t|
  t.references :workspace, null: false, foreign_key: true
  t.string :name, null: false
  t.string :domain # company website
  t.text :description
  t.jsonb :metadata, default: {} # industry, products, etc.
  t.boolean :active, default: true
  t.timestamps

  t.index [:workspace_id, :name]
end

create_table :brand_variations do |t|
  t.references :brand, null: false, foreign_key: true
  t.string :variation, null: false # "IBM", "International Business Machines"
  t.string :variation_type # abbreviation, misspelling, product_name
  t.timestamps

  t.index [:brand_id, :variation]
end
```

#### 4. AI Platforms

```ruby
# app/models/ai_platform.rb
class AiPlatform < ApplicationRecord
  has_many :ai_platform_configs
  has_many :mentions
  has_many :monitoring_jobs
end

# Schema
create_table :ai_platforms do |t|
  t.string :name, null: false # "ChatGPT", "Claude", "Perplexity"
  t.string :slug, null: false, index: { unique: true }
  t.string :provider # "OpenAI", "Anthropic", "Perplexity"
  t.string :api_type # "api", "web_scraping", "browser_automation"
  t.string :api_endpoint
  t.jsonb :config, default: {} # API keys, rate limits, etc.
  t.boolean :active, default: true
  t.timestamps
end

create_table :ai_platform_configs do |t|
  t.references :workspace, null: false, foreign_key: true
  t.references :ai_platform, null: false, foreign_key: true
  t.boolean :enabled, default: true
  t.jsonb :settings, default: {} # workspace-specific settings
  t.timestamps

  t.index [:workspace_id, :ai_platform_id], unique: true
end
```

#### 5. Mentions (Core data - brand mentions in AI responses)

```ruby
# app/models/mention.rb
class Mention < ApplicationRecord
  belongs_to :brand
  belongs_to :ai_platform
  belongs_to :monitoring_job, optional: true
  has_many :citations
end

# Schema - Using TimescaleDB hypertable for time-series optimization
create_table :mentions do |t|
  t.references :brand, null: false, foreign_key: true
  t.references :ai_platform, null: false, foreign_key: true
  t.references :monitoring_job, foreign_key: true

  # Query & Response
  t.text :query, null: false # The prompt/question asked
  t.text :response, null: false # Full AI response
  t.text :context # Extracted context around mention

  # Mention Details
  t.string :mention_type # direct, indirect, comparison, negative
  t.integer :position # Position in response (1=first, 2=second, etc.)
  t.string :position_category # beginning, middle, end
  t.integer :total_mentions_in_response, default: 1

  # Analysis
  t.float :sentiment_score # -1.0 to 1.0
  t.string :sentiment_label # positive, neutral, negative
  t.jsonb :entities, default: [] # Extracted entities (people, products, etc.)
  t.jsonb :topics, default: [] # Topic tags

  # Metadata
  t.datetime :detected_at, null: false
  t.jsonb :raw_data, default: {} # Store full API response
  t.timestamps

  t.index [:brand_id, :detected_at]
  t.index [:ai_platform_id, :detected_at]
  t.index :detected_at # For time-series queries
  t.index :sentiment_score
end

# Convert to TimescaleDB hypertable
# execute "SELECT create_hypertable('mentions', 'detected_at');"
```

#### 6. Citations (Sources cited in AI responses)

```ruby
# app/models/citation.rb
class Citation < ApplicationRecord
  belongs_to :mention
  belongs_to :brand, optional: true
end

# Schema
create_table :citations do |t|
  t.references :mention, null: false, foreign_key: true
  t.references :brand, foreign_key: true # If it's our own content

  t.string :url, null: false
  t.string :domain
  t.string :title
  t.text :snippet # Excerpt from the source
  t.string :source_type # owned, third_party, news, review, social
  t.integer :position # Position in citation list

  # Quality Metrics
  t.float :authority_score # Domain authority (0-100)
  t.float :relevance_score # How relevant to the query
  t.datetime :published_at # When the source was published

  t.jsonb :metadata, default: {}
  t.timestamps

  t.index :url
  t.index :domain
  t.index [:mention_id, :position]
end
```

#### 7. Visibility Scores (Time-series metrics)

```ruby
# app/models/visibility_score.rb
class VisibilityScore < ApplicationRecord
  belongs_to :brand
  belongs_to :ai_platform, optional: true # Null = overall score
end

# Schema - TimescaleDB hypertable
create_table :visibility_scores do |t|
  t.references :brand, null: false, foreign_key: true
  t.references :ai_platform, foreign_key: true # Null = overall score

  t.date :date, null: false
  t.string :period_type, default: 'daily' # daily, weekly, monthly

  # Score Components
  t.float :overall_score, null: false # 0-100
  t.float :mention_frequency_score
  t.float :position_score
  t.float :sentiment_score
  t.float :citation_quality_score

  # Raw Metrics
  t.integer :total_mentions, default: 0
  t.integer :positive_mentions, default: 0
  t.integer :neutral_mentions, default: 0
  t.integer :negative_mentions, default: 0
  t.integer :cited_mentions, default: 0
  t.float :avg_position

  # Trends
  t.float :score_change # Change from previous period
  t.string :trend # up, down, stable

  t.jsonb :metadata, default: {}
  t.timestamps

  t.index [:brand_id, :date, :ai_platform_id], unique: true
  t.index [:brand_id, :date]
  t.index :date
end

# Convert to TimescaleDB hypertable
# execute "SELECT create_hypertable('visibility_scores', 'date');"
```

#### 8. Competitors

```ruby
# app/models/competitor.rb
class Competitor < ApplicationRecord
  belongs_to :brand # The brand doing the tracking
  belongs_to :competitor_brand, class_name: 'Brand' # The competitor
end

# Schema
create_table :competitors do |t|
  t.references :brand, null: false, foreign_key: true
  t.references :competitor_brand, null: false, foreign_key: { to_table: :brands }
  t.boolean :active, default: true
  t.timestamps

  t.index [:brand_id, :competitor_brand_id], unique: true
end
```

#### 9. Monitoring Jobs (Track monitoring runs)

```ruby
# app/models/monitoring_job.rb
class MonitoringJob < ApplicationRecord
  belongs_to :brand
  belongs_to :ai_platform
  has_many :mentions
end

# Schema
create_table :monitoring_jobs do |t|
  t.references :brand, null: false, foreign_key: true
  t.references :ai_platform, null: false, foreign_key: true

  t.string :status # pending, running, completed, failed
  t.datetime :started_at
  t.datetime :completed_at
  t.integer :mentions_found, default: 0
  t.integer :queries_executed, default: 0

  t.text :error_message
  t.jsonb :job_metadata, default: {}
  t.timestamps

  t.index [:brand_id, :ai_platform_id, :created_at]
  t.index :status
end
```

#### 10. Prompts & Prompt Volume Data

```ruby
# app/models/prompt.rb
class Prompt < ApplicationRecord
  has_many :prompt_volumes
  has_many :prompt_topics
end

# Schema
create_table :prompts do |t|
  t.text :prompt_text, null: false
  t.string :prompt_hash, null: false, index: { unique: true } # SHA256 hash
  t.string :intent # informational, commercial, transactional, navigational
  t.string :question_type # what, how, why, when, where, who
  t.jsonb :topics, default: []
  t.jsonb :entities, default: []
  t.timestamps

  t.index :prompt_text, using: :gin, opclass: :gin_trgm_ops # Fuzzy search
end

create_table :prompt_volumes do |t|
  t.references :prompt, null: false, foreign_key: true
  t.references :ai_platform, foreign_key: true

  t.date :date, null: false
  t.integer :estimated_volume
  t.float :confidence_score # How confident we are in the estimate
  t.string :trend # rising, falling, stable

  t.timestamps

  t.index [:prompt_id, :date, :ai_platform_id], unique: true
end
```

---

## Application Architecture

### Directory Structure (Rails Conventions)

```
app/
├── controllers/
│   ├── api/
│   │   └── v1/
│   │       ├── brands_controller.rb
│   │       ├── mentions_controller.rb
│   │       └── visibility_scores_controller.rb
│   ├── dashboard_controller.rb
│   ├── brands_controller.rb
│   ├── mentions_controller.rb
│   └── reports_controller.rb
├── models/
│   ├── user.rb
│   ├── workspace.rb
│   ├── brand.rb
│   ├── mention.rb
│   ├── citation.rb
│   ├── visibility_score.rb
│   └── ai_platform.rb
├── services/
│   ├── ai_platforms/
│   │   ├── base_monitor.rb
│   │   ├── chatgpt_monitor.rb
│   │   ├── claude_monitor.rb
│   │   └── perplexity_monitor.rb
│   ├── mention_detector.rb
│   ├── sentiment_analyzer.rb
│   ├── visibility_scorer.rb
│   └── citation_extractor.rb
├── jobs/
│   ├── monitoring/
│   │   ├── platform_monitoring_job.rb
│   │   └── batch_monitoring_job.rb
│   ├── analysis/
│   │   ├── sentiment_analysis_job.rb
│   │   ├── citation_extraction_job.rb
│   │   └── visibility_scoring_job.rb
│   └── alerts/
│       ├── sentiment_alert_job.rb
│       └── mention_alert_job.rb
├── views/
│   ├── layouts/
│   │   └── application.html.erb
│   ├── dashboard/
│   │   └── index.html.erb
│   ├── brands/
│   │   ├── index.html.erb
│   │   ├── show.html.erb
│   │   └── _brand_card.html.erb
│   └── mentions/
│       ├── index.html.erb
│       └── _mention_row.html.erb
└── javascript/
    ├── controllers/
    │   ├── dashboard_controller.js
    │   ├── chart_controller.js
    │   └── mention_controller.js
    └── application.js
```

---

## Service Layer Architecture

### AI Platform Monitoring Services

```ruby
# app/services/ai_platforms/base_monitor.rb
module AiPlatforms
  class BaseMonitor
    attr_reader :brand, :ai_platform, :monitoring_job

    def initialize(brand:, ai_platform:)
      @brand = brand
      @ai_platform = ai_platform
      @monitoring_job = create_monitoring_job
    end

    def monitor
      monitoring_job.update!(status: 'running', started_at: Time.current)

      queries = generate_queries
      mentions_found = 0

      queries.each do |query|
        response = execute_query(query)
        mentions = detect_mentions(query, response)
        mentions_found += mentions.count

        # Rate limiting
        sleep(rate_limit_delay)
      end

      monitoring_job.update!(
        status: 'completed',
        completed_at: Time.current,
        mentions_found: mentions_found,
        queries_executed: queries.count
      )

      # Trigger downstream analysis
      trigger_analysis_jobs

    rescue => e
      monitoring_job.update!(
        status: 'failed',
        error_message: e.message,
        completed_at: Time.current
      )
      raise
    end

    private

    def generate_queries
      # Generate queries based on brand, industry, topics
      # Override in subclasses
      raise NotImplementedError
    end

    def execute_query(query)
      # Execute query against AI platform
      # Override in subclasses
      raise NotImplementedError
    end

    def detect_mentions(query, response)
      MentionDetector.new(
        brand: brand,
        ai_platform: ai_platform,
        query: query,
        response: response,
        monitoring_job: monitoring_job
      ).detect
    end

    def rate_limit_delay
      # Platform-specific rate limiting
      ai_platform.config.dig('rate_limit_delay') || 1.0
    end

    def trigger_analysis_jobs
      SentimentAnalysisJob.perform_later(monitoring_job.id)
      CitationExtractionJob.perform_later(monitoring_job.id)
      VisibilityScoringJob.perform_later(brand.id)
    end

    def create_monitoring_job
      MonitoringJob.create!(
        brand: brand,
        ai_platform: ai_platform,
        status: 'pending'
      )
    end
  end
end

# app/services/ai_platforms/chatgpt_monitor.rb
module AiPlatforms
  class ChatgptMonitor < BaseMonitor
    def execute_query(query)
      client = OpenAI::Client.new(access_token: api_key)

      response = client.chat(
        parameters: {
          model: "gpt-4",
          messages: [{ role: "user", content: query }],
          temperature: 0.7
        }
      )

      response.dig("choices", 0, "message", "content")
    end

    private

    def generate_queries
      [
        "What are the top companies in #{brand.metadata['industry']}?",
        "Tell me about #{brand.name}",
        "Compare #{brand.name} to its competitors",
        "What are the best #{brand.metadata['product_category']} solutions?",
        # Add more query templates
      ]
    end

    def api_key
      Rails.application.credentials.dig(:openai, :api_key)
    end
  end
end

# app/services/ai_platforms/claude_monitor.rb
module AiPlatforms
  class ClaudeMonitor < BaseMonitor
    def execute_query(query)
      client = Anthropic::Client.new(access_token: api_key)

      response = client.messages(
        parameters: {
          model: "claude-3-5-sonnet-20241022",
          max_tokens: 1024,
          messages: [{ role: "user", content: query }]
        }
      )

      response.dig("content", 0, "text")
    end

    private

    def generate_queries
      # Similar to ChatGPT but may vary based on platform
      [
        "What are the leading #{brand.metadata['industry']} companies?",
        "Provide information about #{brand.name}",
        # Add more query templates
      ]
    end

    def api_key
      Rails.application.credentials.dig(:anthropic, :api_key)
    end
  end
end

# app/services/ai_platforms/perplexity_monitor.rb
module AiPlatforms
  class PerplexityMonitor < BaseMonitor
    # Perplexity may require web scraping or browser automation
    # if no API is available

    def execute_query(query)
      # Option 1: Use Perplexity API if available
      # Option 2: Use Selenium/Puppeteer for browser automation
      # Option 3: Use HTTP requests with proper headers

      # Placeholder implementation
      response = HTTParty.post(
        'https://www.perplexity.ai/api/search',
        body: { query: query }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

      response.parsed_response['answer']
    end

    private

    def generate_queries
      # Perplexity-specific query templates
      [
        "#{brand.name} overview",
        "Best #{brand.metadata['product_category']} tools",
        # Add more
      ]
    end
  end
end
```

### Mention Detection Service

```ruby
# app/services/mention_detector.rb
class MentionDetector
  attr_reader :brand, :ai_platform, :query, :response, :monitoring_job

  def initialize(brand:, ai_platform:, query:, response:, monitoring_job: nil)
    @brand = brand
    @ai_platform = ai_platform
    @query = query
    @response = response
    @monitoring_job = monitoring_job
  end

  def detect
    mentions = []

    # Check for exact brand name
    if response.include?(brand.name)
      mentions << create_mention(brand.name, 'direct')
    end

    # Check for brand variations
    brand.brand_variations.each do |variation|
      if response.include?(variation.variation)
        mentions << create_mention(variation.variation, 'indirect')
      end
    end

    # Use NLP for more sophisticated detection
    entities = extract_entities(response)
    entities.each do |entity|
      if entity_matches_brand?(entity)
        mentions << create_mention(entity, 'entity_recognition')
      end
    end

    mentions
  end

  private

  def create_mention(matched_text, mention_type)
    position = calculate_position(matched_text)
    context = extract_context(matched_text)

    Mention.create!(
      brand: brand,
      ai_platform: ai_platform,
      monitoring_job: monitoring_job,
      query: query,
      response: response,
      context: context,
      mention_type: mention_type,
      position: position,
      position_category: categorize_position(position),
      detected_at: Time.current,
      raw_data: { matched_text: matched_text }
    )
  end

  def calculate_position(text)
    # Find position of mention in response
    index = response.index(text)
    return 1 if index.nil?

    # Count sentences before this mention
    response[0..index].scan(/[.!?]+/).count + 1
  end

  def categorize_position(position)
    total_sentences = response.scan(/[.!?]+/).count

    case position
    when 1..2
      'beginning'
    when (total_sentences - 1)..total_sentences
      'end'
    else
      'middle'
    end
  end

  def extract_context(text)
    # Extract surrounding sentences
    index = response.index(text)
    return response if index.nil?

    # Get 100 characters before and after
    start_pos = [index - 100, 0].max
    end_pos = [index + text.length + 100, response.length].min

    response[start_pos..end_pos]
  end

  def extract_entities(text)
    # Use OpenAI or other NLP service for entity extraction
    # Placeholder implementation
    []
  end

  def entity_matches_brand?(entity)
    # Check if entity matches brand or variations
    entity.downcase == brand.name.downcase ||
      brand.brand_variations.any? { |v| v.variation.downcase == entity.downcase }
  end
end
```

### Sentiment Analysis Service

```ruby
# app/services/sentiment_analyzer.rb
class SentimentAnalyzer
  attr_reader :mention

  def initialize(mention)
    @mention = mention
  end

  def analyze
    # Option 1: Use OpenAI for sentiment analysis
    sentiment = analyze_with_openai

    # Option 2: Use a dedicated sentiment analysis service
    # sentiment = analyze_with_huggingface

    mention.update!(
      sentiment_score: sentiment[:score],
      sentiment_label: sentiment[:label]
    )

    sentiment
  end

  private

  def analyze_with_openai
    client = OpenAI::Client.new(access_token: api_key)

    prompt = <<~PROMPT
      Analyze the sentiment of the following text about #{mention.brand.name}.
      Respond with a JSON object containing:
      - score: a number between -1.0 (very negative) and 1.0 (very positive)
      - label: one of "positive", "neutral", or "negative"

      Text: #{mention.context}
    PROMPT

    response = client.chat(
      parameters: {
        model: "gpt-4",
        messages: [{ role: "user", content: prompt }],
        temperature: 0.3,
        response_format: { type: "json_object" }
      }
    )

    result = JSON.parse(response.dig("choices", 0, "message", "content"))

    {
      score: result["score"].to_f,
      label: result["label"]
    }
  rescue => e
    Rails.logger.error("Sentiment analysis failed: #{e.message}")
    { score: 0.0, label: 'neutral' }
  end

  def api_key
    Rails.application.credentials.dig(:openai, :api_key)
  end
end
```

### Visibility Scoring Service

```ruby
# app/services/visibility_scorer.rb
class VisibilityScorer
  attr_reader :brand, :date, :ai_platform

  def initialize(brand:, date: Date.current, ai_platform: nil)
    @brand = brand
    @date = date
    @ai_platform = ai_platform
  end

  def calculate
    mentions = fetch_mentions

    return nil if mentions.empty?

    # Calculate component scores
    mention_freq_score = calculate_mention_frequency_score(mentions)
    position_score = calculate_position_score(mentions)
    sentiment_score = calculate_sentiment_score(mentions)
    citation_score = calculate_citation_quality_score(mentions)

    # Calculate overall score (weighted average)
    overall_score = (
      (mention_freq_score * 0.4) +
      (position_score * 0.2) +
      (sentiment_score * 0.2) +
      (citation_score * 0.2)
    ) * 100

    # Create or update visibility score record
    visibility_score = VisibilityScore.find_or_initialize_by(
      brand: brand,
      ai_platform: ai_platform,
      date: date,
      period_type: 'daily'
    )

    visibility_score.update!(
      overall_score: overall_score,
      mention_frequency_score: mention_freq_score,
      position_score: position_score,
      sentiment_score: sentiment_score,
      citation_quality_score: citation_score,
      total_mentions: mentions.count,
      positive_mentions: mentions.where(sentiment_label: 'positive').count,
      neutral_mentions: mentions.where(sentiment_label: 'neutral').count,
      negative_mentions: mentions.where(sentiment_label: 'negative').count,
      cited_mentions: mentions.joins(:citations).distinct.count,
      avg_position: mentions.average(:position)
    )

    # Calculate trend
    calculate_trend(visibility_score)

    visibility_score
  end

  private

  def fetch_mentions
    scope = brand.mentions.where(detected_at: date.beginning_of_day..date.end_of_day)
    scope = scope.where(ai_platform: ai_platform) if ai_platform
    scope
  end

  def calculate_mention_frequency_score(mentions)
    # Normalize against maximum mentions in category
    max_mentions = 100 # This should be dynamic based on industry/category
    [mentions.count.to_f / max_mentions, 1.0].min
  end

  def calculate_position_score(mentions)
    # Weight positions: first=1.0, middle=0.5, end=0.3
    weights = { 'beginning' => 1.0, 'middle' => 0.5, 'end' => 0.3 }

    total_weight = mentions.sum { |m| weights[m.position_category] || 0.5 }
    total_weight / mentions.count
  end

  def calculate_sentiment_score(mentions)
    # Average sentiment, normalized to 0-1
    avg_sentiment = mentions.average(:sentiment_score) || 0.0
    (avg_sentiment + 1.0) / 2.0 # Convert from [-1, 1] to [0, 1]
  end

  def calculate_citation_quality_score(mentions)
    # Percentage of mentions that have citations
    cited_count = mentions.joins(:citations).distinct.count
    cited_count.to_f / mentions.count
  end

  def calculate_trend(visibility_score)
    previous_score = VisibilityScore.where(
      brand: brand,
      ai_platform: ai_platform,
      date: date - 1.day,
      period_type: 'daily'
    ).first

    if previous_score
      change = visibility_score.overall_score - previous_score.overall_score
      visibility_score.score_change = change

      visibility_score.trend = if change > 5
        'up'
      elsif change < -5
        'down'
      else
        'stable'
      end
    end

    visibility_score.save!
  end
end
```

---

## Background Jobs (Sidekiq)

### Monitoring Jobs

```ruby
# app/jobs/monitoring/platform_monitoring_job.rb
module Monitoring
  class PlatformMonitoringJob < ApplicationJob
    queue_as :monitoring

    def perform(brand_id, ai_platform_id)
      brand = Brand.find(brand_id)
      ai_platform = AiPlatform.find(ai_platform_id)

      # Select appropriate monitor based on platform
      monitor_class = "AiPlatforms::#{ai_platform.slug.camelize}Monitor".constantize
      monitor = monitor_class.new(brand: brand, ai_platform: ai_platform)

      monitor.monitor
    end
  end
end

# app/jobs/monitoring/batch_monitoring_job.rb
module Monitoring
  class BatchMonitoringJob < ApplicationJob
    queue_as :monitoring

    # Run monitoring for all active brands across all platforms
    def perform
      Brand.active.find_each do |brand|
        brand.workspace.ai_platform_configs.enabled.each do |config|
          PlatformMonitoringJob.perform_later(brand.id, config.ai_platform_id)
        end
      end
    end
  end
end

# Schedule with whenever gem or Sidekiq-cron
# config/schedule.rb (if using whenever)
# every 1.day, at: '2:00 am' do
#   runner "Monitoring::BatchMonitoringJob.perform_later"
# end
```

### Analysis Jobs

```ruby
# app/jobs/analysis/sentiment_analysis_job.rb
module Analysis
  class SentimentAnalysisJob < ApplicationJob
    queue_as :analysis

    def perform(monitoring_job_id)
      monitoring_job = MonitoringJob.find(monitoring_job_id)

      # Analyze sentiment for all mentions from this monitoring job
      monitoring_job.mentions.where(sentiment_score: nil).find_each do |mention|
        SentimentAnalyzer.new(mention).analyze
      end
    end
  end
end

# app/jobs/analysis/citation_extraction_job.rb
module Analysis
  class CitationExtractionJob < ApplicationJob
    queue_as :analysis

    def perform(monitoring_job_id)
      monitoring_job = MonitoringJob.find(monitoring_job_id)

      monitoring_job.mentions.find_each do |mention|
        CitationExtractor.new(mention).extract
      end
    end
  end
end

# app/jobs/analysis/visibility_scoring_job.rb
module Analysis
  class VisibilityScoringJob < ApplicationJob
    queue_as :analysis

    def perform(brand_id, date = Date.current)
      brand = Brand.find(brand_id)

      # Calculate overall score
      VisibilityScorer.new(brand: brand, date: date).calculate

      # Calculate per-platform scores
      AiPlatform.active.each do |platform|
        VisibilityScorer.new(
          brand: brand,
          date: date,
          ai_platform: platform
        ).calculate
      end
    end
  end
end
```

### Alert Jobs

```ruby
# app/jobs/alerts/sentiment_alert_job.rb
module Alerts
  class SentimentAlertJob < ApplicationJob
    queue_as :critical

    def perform(mention_id)
      mention = Mention.find(mention_id)

      # Alert if sentiment is negative
      if mention.sentiment_label == 'negative'
        # Send email alert
        AlertMailer.negative_sentiment_alert(mention).deliver_later

        # Send Slack notification if configured
        send_slack_notification(mention) if slack_configured?
      end
    end

    private

    def send_slack_notification(mention)
      SlackNotifier.new(mention.brand.workspace).notify(
        channel: '#geo-alerts',
        text: "⚠️ Negative mention detected for #{mention.brand.name}",
        attachments: [
          {
            title: "AI Platform: #{mention.ai_platform.name}",
            text: mention.context,
            color: 'danger'
          }
        ]
      )
    end

    def slack_configured?
      # Check if workspace has Slack integration
      Rails.application.credentials.dig(:slack, :webhook_url).present?
    end
  end
end

# app/jobs/alerts/mention_alert_job.rb
module Alerts
  class MentionAlertJob < ApplicationJob
    queue_as :critical

    def perform(brand_id)
      brand = Brand.find(brand_id)

      # Check for significant changes in mention volume
      today_mentions = brand.mentions.where(detected_at: Date.current.all_day).count
      yesterday_mentions = brand.mentions.where(detected_at: 1.day.ago.all_day).count

      change_percent = ((today_mentions - yesterday_mentions).to_f / yesterday_mentions * 100).round(1)

      if change_percent.abs > 50 # 50% change threshold
        AlertMailer.mention_volume_alert(brand, change_percent).deliver_later
      end
    end
  end
end
```

---

## API Layer

### API Controllers

```ruby
# app/controllers/api/v1/base_controller.rb
module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate_api_request
      before_action :set_current_workspace

      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity

      private

      def authenticate_api_request
        authenticate_or_request_with_http_token do |token, options|
          @current_api_key = ApiKey.find_by(token: token, active: true)
          @current_api_key.present?
        end
      end

      def set_current_workspace
        @current_workspace = @current_api_key.workspace
      end

      def not_found(exception)
        render json: { error: 'Resource not found' }, status: :not_found
      end

      def unprocessable_entity(exception)
        render json: { error: exception.message }, status: :unprocessable_entity
      end
    end
  end
end

# app/controllers/api/v1/brands_controller.rb
module Api
  module V1
    class BrandsController < BaseController
      def index
        brands = @current_workspace.brands.includes(:visibility_scores)

        render json: brands, each_serializer: BrandSerializer
      end

      def show
        brand = @current_workspace.brands.find(params[:id])

        render json: brand, serializer: BrandSerializer, include: ['visibility_scores']
      end

      def create
        brand = @current_workspace.brands.create!(brand_params)

        render json: brand, serializer: BrandSerializer, status: :created
      end

      private

      def brand_params
        params.require(:brand).permit(:name, :domain, :description, metadata: {})
      end
    end
  end
end

# app/controllers/api/v1/mentions_controller.rb
module Api
  module V1
    class MentionsController < BaseController
      def index
        brand = @current_workspace.brands.find(params[:brand_id])
        mentions = brand.mentions
          .includes(:ai_platform, :citations)
          .order(detected_at: :desc)
          .page(params[:page])
          .per(params[:per_page] || 50)

        render json: {
          mentions: mentions.map { |m| MentionSerializer.new(m).as_json },
          meta: pagination_meta(mentions)
        }
      end

      private

      def pagination_meta(collection)
        {
          current_page: collection.current_page,
          total_pages: collection.total_pages,
          total_count: collection.total_count,
          per_page: collection.limit_value
        }
      end
    end
  end
end

# app/controllers/api/v1/visibility_scores_controller.rb
module Api
  module V1
    class VisibilityScoresController < BaseController
      def index
        brand = @current_workspace.brands.find(params[:brand_id])

        scores = brand.visibility_scores
          .where(date: date_range)
          .order(date: :desc)

        # Filter by platform if specified
        scores = scores.where(ai_platform_id: params[:platform_id]) if params[:platform_id]

        render json: scores, each_serializer: VisibilityScoreSerializer
      end

      private

      def date_range
        start_date = params[:start_date]&.to_date || 30.days.ago.to_date
        end_date = params[:end_date]&.to_date || Date.current
        start_date..end_date
      end
    end
  end
end
```

### API Serializers

```ruby
# app/serializers/brand_serializer.rb
class BrandSerializer < ActiveModel::Serializer
  attributes :id, :name, :domain, :description, :metadata, :created_at

  has_many :visibility_scores, if: -> { instance_options[:include]&.include?('visibility_scores') }

  def metadata
    object.metadata || {}
  end
end

# app/serializers/mention_serializer.rb
class MentionSerializer < ActiveModel::Serializer
  attributes :id, :query, :response, :context, :mention_type, :position,
             :position_category, :sentiment_score, :sentiment_label,
             :detected_at, :ai_platform_name

  has_many :citations

  def ai_platform_name
    object.ai_platform.name
  end
end

# app/serializers/visibility_score_serializer.rb
class VisibilityScoreSerializer < ActiveModel::Serializer
  attributes :id, :date, :overall_score, :mention_frequency_score,
             :position_score, :sentiment_score, :citation_quality_score,
             :total_mentions, :positive_mentions, :neutral_mentions,
             :negative_mentions, :trend, :score_change, :ai_platform_name

  def ai_platform_name
    object.ai_platform&.name || 'Overall'
  end
end
```

---

## Caching Strategy

### Redis Caching

```ruby
# config/environments/production.rb
config.cache_store = :redis_cache_store, {
  url: ENV['REDIS_URL'],
  namespace: 'geo_platform',
  expires_in: 1.hour,
  race_condition_ttl: 10.seconds
}

# app/models/brand.rb
class Brand < ApplicationRecord
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

# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  def index
    @brands = current_workspace.brands.includes(:visibility_scores)

    # Cache dashboard data
    @dashboard_data = Rails.cache.fetch(
      "workspace:#{current_workspace.id}:dashboard:#{Date.current}",
      expires_in: 15.minutes
    ) do
      {
        total_mentions: calculate_total_mentions,
        avg_visibility_score: calculate_avg_visibility_score,
        sentiment_breakdown: calculate_sentiment_breakdown,
        platform_breakdown: calculate_platform_breakdown
      }
    end
  end
end
```

### Fragment Caching in Views

```erb
<!-- app/views/dashboard/index.html.erb -->
<div class="dashboard">
  <% @brands.each do |brand| %>
    <%= cache(brand) do %>
      <%= render 'brands/brand_card', brand: brand %>
    <% end %>
  <% end %>
</div>

<!-- app/views/brands/_brand_card.html.erb -->
<div class="brand-card">
  <h3><%= brand.name %></h3>

  <%= cache(['brand_score', brand, Date.current]) do %>
    <div class="visibility-score">
      <%= brand.current_visibility_score %>
    </div>
  <% end %>

  <%= cache(['brand_mentions', brand, Date.current]) do %>
    <div class="mention-count">
      <%= brand.mention_count_last_30_days %> mentions
    </div>
  <% end %>
</div>
```

---

## Performance Optimization

### Database Indexing Strategy

```ruby
# db/migrate/XXXXXX_add_performance_indexes.rb
class AddPerformanceIndexes < ActiveRecord::Migration[7.1]
  def change
    # Mentions table - most queried
    add_index :mentions, [:brand_id, :detected_at, :sentiment_label]
    add_index :mentions, [:ai_platform_id, :detected_at]
    add_index :mentions, :detected_at, order: { detected_at: :desc }

    # Visibility scores - time-series queries
    add_index :visibility_scores, [:brand_id, :date, :period_type]
    add_index :visibility_scores, [:date, :ai_platform_id]

    # Citations - lookup by domain
    add_index :citations, :domain
    add_index :citations, [:mention_id, :position]

    # Workspaces - slug lookup
    add_index :workspaces, :slug, unique: true

    # Users - email lookup
    add_index :users, :email, unique: true

    # Composite indexes for common queries
    add_index :mentions, [:brand_id, :ai_platform_id, :detected_at],
              name: 'index_mentions_on_brand_platform_date'
  end
end
```

### Query Optimization

```ruby
# app/models/brand.rb
class Brand < ApplicationRecord
  # Use includes to avoid N+1 queries
  scope :with_latest_scores, -> {
    includes(:visibility_scores)
      .where(visibility_scores: { date: Date.current })
  }

  # Use select to limit columns
  scope :for_listing, -> {
    select(:id, :name, :domain, :created_at)
  }

  # Use counter cache for mentions
  has_many :mentions, counter_cache: true
end

# Add counter cache column
# add_column :brands, :mentions_count, :integer, default: 0

# app/controllers/brands_controller.rb
class BrandsController < ApplicationController
  def index
    # Optimized query with eager loading
    @brands = current_workspace.brands
      .includes(:visibility_scores, :workspace)
      .with_latest_scores
      .order(created_at: :desc)
      .page(params[:page])
  end

  def show
    # Use find_by! to avoid exception overhead in common case
    @brand = current_workspace.brands
      .includes(
        mentions: [:ai_platform, :citations],
        visibility_scores: :ai_platform
      )
      .find(params[:id])
  end
end
```

### Background Job Optimization

```ruby
# app/jobs/monitoring/batch_monitoring_job.rb
module Monitoring
  class BatchMonitoringJob < ApplicationJob
    queue_as :monitoring

    def perform
      # Process in batches to avoid memory issues
      Brand.active.find_in_batches(batch_size: 100) do |brands_batch|
        brands_batch.each do |brand|
          brand.workspace.ai_platform_configs.enabled.each do |config|
            PlatformMonitoringJob.perform_later(brand.id, config.ai_platform_id)
          end
        end
      end
    end
  end
end

# Use bulk insert for better performance
# app/services/mention_detector.rb
class MentionDetector
  def detect
    mentions_data = []

    # Collect all mention data first
    # ... detection logic ...

    # Bulk insert instead of individual creates
    Mention.insert_all(mentions_data) if mentions_data.any?
  end
end
```

---

## Deployment Architecture

### Hosting Options

#### Option 1: Heroku (Recommended for MVP)

**Pros:**
- Fastest time to deployment
- Managed PostgreSQL, Redis
- Easy scaling
- Built-in monitoring
- Automatic SSL

**Cons:**
- More expensive at scale
- Less control over infrastructure

**Setup:**
```bash
# Procfile
web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq -C config/sidekiq.yml
release: bundle exec rails db:migrate

# Add-ons needed
heroku addons:create heroku-postgresql:standard-0
heroku addons:create heroku-redis:premium-0
heroku addons:create sendgrid:starter
heroku addons:create papertrail:choklad

# Environment variables
heroku config:set RAILS_ENV=production
heroku config:set RAILS_MASTER_KEY=<your_master_key>
heroku config:set OPENAI_API_KEY=<your_key>
heroku config:set ANTHROPIC_API_KEY=<your_key>
```

#### Option 2: Render (Good Alternative)

**Pros:**
- Similar to Heroku but cheaper
- Native support for background workers
- Free SSL
- Good developer experience

**Cons:**
- Smaller ecosystem than Heroku
- Fewer add-ons

#### Option 3: AWS (For Scale)

**Pros:**
- Maximum control and flexibility
- Cost-effective at scale
- Wide range of services

**Cons:**
- More complex setup
- Requires DevOps expertise

**Architecture:**
- **Compute:** ECS/Fargate or EC2
- **Database:** RDS PostgreSQL with TimescaleDB
- **Cache:** ElastiCache Redis
- **Storage:** S3 for file storage
- **Load Balancer:** ALB
- **CDN:** CloudFront

---

### Environment Configuration

```ruby
# config/environments/production.rb
Rails.application.configure do
  config.cache_classes = true
  config.eager_load = true
  config.consider_all_requests_local = false
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?

  # Asset compilation
  config.assets.compile = false
  config.assets.css_compressor = :sass
  config.assets.js_compressor = :terser

  # Logging
  config.log_level = :info
  config.log_tags = [:request_id]

  # Caching
  config.cache_store = :redis_cache_store, {
    url: ENV['REDIS_URL'],
    namespace: 'geo_platform',
    expires_in: 1.hour
  }

  # Active Job
  config.active_job.queue_adapter = :sidekiq

  # Action Mailer
  config.action_mailer.perform_caching = false
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: ENV['SMTP_ADDRESS'],
    port: ENV['SMTP_PORT'],
    user_name: ENV['SMTP_USERNAME'],
    password: ENV['SMTP_PASSWORD'],
    authentication: :plain,
    enable_starttls_auto: true
  }

  # SSL
  config.force_ssl = true
  config.ssl_options = { redirect: { exclude: -> request { request.path =~ /health/ } } }

  # Security
  config.action_dispatch.default_headers = {
    'X-Frame-Options' => 'SAMEORIGIN',
    'X-XSS-Protection' => '1; mode=block',
    'X-Content-Type-Options' => 'nosniff',
    'Referrer-Policy' => 'strict-origin-when-cross-origin'
  }
end
```

### Database Configuration

```yaml
# config/database.yml
production:
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  url: <%= ENV['DATABASE_URL'] %>
  prepared_statements: false
  advisory_locks: false

  # Connection pooling
  checkout_timeout: 5
  reaping_frequency: 10

  # Performance
  statement_timeout: 30000 # 30 seconds
  connect_timeout: 2

  # Extensions
  schema_search_path: "public,timescaledb"
```

---

## Security Implementation

### Authentication & Authorization

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Authentication
  include Authorization

  before_action :require_authentication
  before_action :set_current_workspace

  private

  def set_current_workspace
    @current_workspace = current_user.workspaces.find_by(slug: params[:workspace_slug])
    redirect_to root_path, alert: 'Workspace not found' unless @current_workspace
  end
end

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
      redirect_to login_path, alert: 'Please sign in to continue'
    end
  end
end

# app/controllers/concerns/authorization.rb
module Authorization
  extend ActiveSupport::Concern

  def authorize_workspace_admin!
    unless current_workspace_membership&.admin?
      redirect_to root_path, alert: 'You are not authorized to perform this action'
    end
  end

  def authorize_workspace_editor!
    unless current_workspace_membership&.admin? || current_workspace_membership&.editor?
      redirect_to root_path, alert: 'You are not authorized to perform this action'
    end
  end

  private

  def current_workspace_membership
    @current_workspace_membership ||= @current_workspace.workspace_memberships
      .find_by(user: current_user)
  end
end
```

### API Authentication

```ruby
# app/models/api_key.rb
class ApiKey < ApplicationRecord
  belongs_to :workspace

  before_create :generate_token

  encrypts :token # Rails 7 encryption

  scope :active, -> { where(active: true) }

  def self.authenticate(token)
    active.find_by(token: token)
  end

  private

  def generate_token
    self.token = SecureRandom.hex(32)
  end
end

# Schema
create_table :api_keys do |t|
  t.references :workspace, null: false, foreign_key: true
  t.string :name
  t.string :token, null: false
  t.boolean :active, default: true
  t.datetime :last_used_at
  t.datetime :expires_at
  t.timestamps

  t.index :token, unique: true
end
```

### Rate Limiting

```ruby
# app/middleware/rate_limiter.rb
class RateLimiter
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)

    if api_request?(request)
      api_key = extract_api_key(request)

      if rate_limit_exceeded?(api_key)
        return [429, { 'Content-Type' => 'application/json' },
                [{ error: 'Rate limit exceeded' }.to_json]]
      end

      increment_rate_limit(api_key)
    end

    @app.call(env)
  end

  private

  def api_request?(request)
    request.path.start_with?('/api/')
  end

  def extract_api_key(request)
    request.env['HTTP_AUTHORIZATION']&.split(' ')&.last
  end

  def rate_limit_exceeded?(api_key)
    count = Redis.current.get("rate_limit:#{api_key}").to_i
    count >= 1000 # 1000 requests per hour
  end

  def increment_rate_limit(api_key)
    key = "rate_limit:#{api_key}"
    Redis.current.multi do |r|
      r.incr(key)
      r.expire(key, 3600) # 1 hour
    end
  end
end

# config/application.rb
config.middleware.use RateLimiter
```

### Data Encryption

```ruby
# config/credentials.yml.enc (encrypted)
# Use: rails credentials:edit

production:
  secret_key_base: <generated_secret>
  database_url: <database_url>
  redis_url: <redis_url>

  openai:
    api_key: <openai_key>

  anthropic:
    api_key: <anthropic_key>

  sendgrid:
    api_key: <sendgrid_key>

  aws:
    access_key_id: <aws_key>
    secret_access_key: <aws_secret>
    region: us-east-1
    bucket: geo-platform-production

# app/models/workspace.rb
class Workspace < ApplicationRecord
  # Encrypt sensitive settings
  encrypts :settings, deterministic: false
end
```

---

## Testing Strategy

### Test Setup

```ruby
# Gemfile (test group)
group :test do
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'shoulda-matchers'
  gem 'vcr' # Record HTTP interactions
  gem 'webmock' # Stub HTTP requests
  gem 'simplecov', require: false # Code coverage
end

# spec/rails_helper.rb
require 'spec_helper'
require 'rspec/rails'
require 'factory_bot_rails'
require 'faker'
require 'vcr'
require 'webmock/rspec'

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end

# VCR configuration for recording API calls
VCR.configure do |config|
  config.cassette_library_dir = 'spec/vcr_cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.filter_sensitive_data('<OPENAI_API_KEY>') { ENV['OPENAI_API_KEY'] }
  config.filter_sensitive_data('<ANTHROPIC_API_KEY>') { ENV['ANTHROPIC_API_KEY'] }
end
```

### Model Tests

```ruby
# spec/models/brand_spec.rb
require 'rails_helper'

RSpec.describe Brand, type: :model do
  describe 'associations' do
    it { should belong_to(:workspace) }
    it { should have_many(:mentions) }
    it { should have_many(:visibility_scores) }
    it { should have_many(:brand_variations) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
  end

  describe '#current_visibility_score' do
    let(:brand) { create(:brand) }
    let!(:score) { create(:visibility_score, brand: brand, date: Date.current, overall_score: 75.5) }

    it 'returns the current visibility score' do
      expect(brand.current_visibility_score).to eq(75.5)
    end

    it 'caches the result' do
      expect(Rails.cache).to receive(:fetch).and_call_original
      brand.current_visibility_score
    end
  end
end

# spec/models/mention_spec.rb
require 'rails_helper'

RSpec.describe Mention, type: :model do
  describe 'associations' do
    it { should belong_to(:brand) }
    it { should belong_to(:ai_platform) }
    it { should have_many(:citations) }
  end

  describe 'scopes' do
    let(:brand) { create(:brand) }
    let!(:positive_mention) { create(:mention, brand: brand, sentiment_label: 'positive') }
    let!(:negative_mention) { create(:mention, brand: brand, sentiment_label: 'negative') }

    it 'filters by sentiment' do
      expect(brand.mentions.where(sentiment_label: 'positive')).to include(positive_mention)
      expect(brand.mentions.where(sentiment_label: 'positive')).not_to include(negative_mention)
    end
  end
end
```

### Service Tests

```ruby
# spec/services/mention_detector_spec.rb
require 'rails_helper'

RSpec.describe MentionDetector do
  let(:brand) { create(:brand, name: 'Acme Corp') }
  let(:ai_platform) { create(:ai_platform, name: 'ChatGPT') }
  let(:query) { 'What are the best CRM solutions?' }
  let(:response) { 'Acme Corp is a leading CRM provider. They offer great features.' }

  subject { described_class.new(brand: brand, ai_platform: ai_platform, query: query, response: response) }

  describe '#detect' do
    it 'detects brand mentions in response' do
      mentions = subject.detect

      expect(mentions.count).to eq(1)
      expect(mentions.first.mention_type).to eq('direct')
      expect(mentions.first.query).to eq(query)
      expect(mentions.first.response).to eq(response)
    end

    it 'extracts context around mention' do
      mentions = subject.detect

      expect(mentions.first.context).to include('Acme Corp')
    end

    it 'calculates position correctly' do
      mentions = subject.detect

      expect(mentions.first.position).to eq(1)
      expect(mentions.first.position_category).to eq('beginning')
    end
  end
end

# spec/services/visibility_scorer_spec.rb
require 'rails_helper'

RSpec.describe VisibilityScorer do
  let(:brand) { create(:brand) }
  let(:ai_platform) { create(:ai_platform) }
  let(:date) { Date.current }

  subject { described_class.new(brand: brand, date: date, ai_platform: ai_platform) }

  describe '#calculate' do
    context 'with mentions' do
      let!(:mentions) do
        create_list(:mention, 5,
          brand: brand,
          ai_platform: ai_platform,
          detected_at: date,
          sentiment_score: 0.5,
          position_category: 'beginning'
        )
      end

      it 'creates a visibility score' do
        expect { subject.calculate }.to change(VisibilityScore, :count).by(1)
      end

      it 'calculates overall score correctly' do
        score = subject.calculate

        expect(score.overall_score).to be > 0
        expect(score.overall_score).to be <= 100
      end

      it 'calculates component scores' do
        score = subject.calculate

        expect(score.mention_frequency_score).to be_present
        expect(score.position_score).to be_present
        expect(score.sentiment_score).to be_present
      end
    end

    context 'without mentions' do
      it 'returns nil' do
        expect(subject.calculate).to be_nil
      end
    end
  end
end
```

### Job Tests

```ruby
# spec/jobs/monitoring/platform_monitoring_job_spec.rb
require 'rails_helper'

RSpec.describe Monitoring::PlatformMonitoringJob, type: :job do
  let(:brand) { create(:brand) }
  let(:ai_platform) { create(:ai_platform, slug: 'chatgpt') }

  describe '#perform', vcr: { cassette_name: 'chatgpt_monitoring' } do
    it 'creates a monitoring job' do
      expect {
        described_class.perform_now(brand.id, ai_platform.id)
      }.to change(MonitoringJob, :count).by(1)
    end

    it 'detects mentions' do
      expect {
        described_class.perform_now(brand.id, ai_platform.id)
      }.to change(Mention, :count)
    end

    it 'triggers analysis jobs' do
      expect(Analysis::SentimentAnalysisJob).to receive(:perform_later)
      expect(Analysis::CitationExtractionJob).to receive(:perform_later)

      described_class.perform_now(brand.id, ai_platform.id)
    end
  end
end
```

### Integration Tests

```ruby
# spec/requests/api/v1/brands_spec.rb
require 'rails_helper'

RSpec.describe 'API V1 Brands', type: :request do
  let(:workspace) { create(:workspace) }
  let(:api_key) { create(:api_key, workspace: workspace) }
  let(:headers) { { 'Authorization' => "Bearer #{api_key.token}" } }

  describe 'GET /api/v1/brands' do
    let!(:brands) { create_list(:brand, 3, workspace: workspace) }

    it 'returns all brands' do
      get '/api/v1/brands', headers: headers

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body).count).to eq(3)
    end
  end

  describe 'POST /api/v1/brands' do
    let(:brand_params) do
      {
        brand: {
          name: 'Test Brand',
          domain: 'testbrand.com',
          description: 'A test brand'
        }
      }
    end

    it 'creates a new brand' do
      expect {
        post '/api/v1/brands', params: brand_params, headers: headers
      }.to change(Brand, :count).by(1)

      expect(response).to have_http_status(:created)
    end
  end
end
```

### Factory Definitions

```ruby
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

# spec/factories/mentions.rb
FactoryBot.define do
  factory :mention do
    brand
    ai_platform
    query { Faker::Lorem.question }
    response { Faker::Lorem.paragraph }
    context { Faker::Lorem.sentence }
    mention_type { 'direct' }
    position { 1 }
    position_category { 'beginning' }
    sentiment_score { rand(-1.0..1.0) }
    sentiment_label { ['positive', 'neutral', 'negative'].sample }
    detected_at { Time.current }
  end
end

# spec/factories/visibility_scores.rb
FactoryBot.define do
  factory :visibility_score do
    brand
    ai_platform { nil } # Overall score
    date { Date.current }
    period_type { 'daily' }
    overall_score { rand(0.0..100.0) }
    total_mentions { rand(1..100) }
  end
end
```

---

## Monitoring & Observability

### Application Monitoring

```ruby
# Gemfile
gem 'newrelic_rpm' # or 'skylight' or 'scout_apm'
gem 'sentry-ruby'
gem 'sentry-rails'
gem 'sentry-sidekiq'

# config/initializers/sentry.rb
Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.traces_sample_rate = 0.1
  config.environment = Rails.env
  config.enabled_environments = %w[production staging]
end

# config/initializers/new_relic.rb
# New Relic will auto-configure from newrelic.yml
```

### Health Check Endpoint

```ruby
# config/routes.rb
get '/health', to: 'health#index'

# app/controllers/health_controller.rb
class HealthController < ApplicationController
  skip_before_action :require_authentication

  def index
    health_status = {
      status: 'ok',
      timestamp: Time.current.iso8601,
      services: {
        database: check_database,
        redis: check_redis,
        sidekiq: check_sidekiq
      }
    }

    status_code = health_status[:services].values.all? { |v| v == 'ok' } ? :ok : :service_unavailable

    render json: health_status, status: status_code
  end

  private

  def check_database
    ActiveRecord::Base.connection.execute('SELECT 1')
    'ok'
  rescue => e
    'error'
  end

  def check_redis
    Redis.current.ping == 'PONG' ? 'ok' : 'error'
  rescue => e
    'error'
  end

  def check_sidekiq
    Sidekiq::ProcessSet.new.size > 0 ? 'ok' : 'warning'
  rescue => e
    'error'
  end
end
```

---

## Next Steps & Implementation Plan

### Phase 1: Foundation (Weeks 1-2)

1. **Project Setup**
   - Initialize Rails 7 application
   - Configure PostgreSQL with TimescaleDB
   - Set up Redis and Sidekiq
   - Configure Tailwind CSS
   - Set up testing framework (RSpec)

2. **Core Models**
   - Create User, Workspace, Brand models
   - Implement authentication
   - Set up multi-tenancy

3. **Database Schema**
   - Create all core tables
   - Add indexes
   - Set up TimescaleDB hypertables

### Phase 2: Monitoring Infrastructure (Weeks 3-6)

1. **AI Platform Integration**
   - Implement base monitor service
   - Create ChatGPT, Claude, Perplexity monitors
   - Set up API clients

2. **Mention Detection**
   - Build mention detector service
   - Implement NLP integration
   - Create background jobs

3. **Basic Dashboard**
   - Build dashboard controller and views
   - Implement Turbo for real-time updates
   - Add basic charts with Chartkick

### Phase 3: Analysis & Scoring (Weeks 7-10)

1. **Sentiment Analysis**
   - Integrate sentiment analysis service
   - Create analysis jobs
   - Build sentiment dashboard

2. **Visibility Scoring**
   - Implement scoring algorithm
   - Create scoring jobs
   - Build score visualization

3. **Citation Tracking**
   - Build citation extractor
   - Track source performance
   - Create citation reports

### Phase 4: Polish & Launch (Weeks 11-12)

1. **API Development**
   - Build REST API
   - Create API documentation
   - Implement rate limiting

2. **Testing & QA**
   - Write comprehensive tests
   - Performance testing
   - Security audit

3. **Deployment**
   - Set up production environment
   - Configure monitoring
   - Launch beta

---

**END OF TECHNICAL ARCHITECTURE DOCUMENT**


