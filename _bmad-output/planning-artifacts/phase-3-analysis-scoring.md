---
document_type: Implementation Guide - Phase 3
product_name: GEO Platform
phase: Analysis & Scoring (Weeks 7-10)
version: 1.0
date: 2026-01-23
author: David Geismar
tech_stack: Ruby on Rails 7.x, PostgreSQL, Redis, Sidekiq, Tailwind CSS
---

# Phase 3: Analysis & Scoring (Weeks 7-10)

## Overview

**Goal:** Build advanced analytics capabilities including sentiment analysis, visibility scoring, competitor tracking, and comprehensive analytics dashboards

**Duration:** 4 weeks

**Team:** 2-3 developers

**Deliverables:**
- Sentiment analysis service with OpenAI integration
- Citation extraction and tracking
- Visibility scoring system with TimescaleDB
- Competitor tracking and share of voice
- Historical trend analysis
- Comprehensive analytics dashboard
- Time-series data visualization

**Prerequisites:**
- Phase 1 (Foundation) completed
- Phase 2 (Monitoring Infrastructure) completed
- Mentions being collected and stored
- TimescaleDB extension installed

---

## Week 7: Sentiment Analysis & Citation Extraction

### Feature 3.1: Sentiment Analysis Service

**Estimated Time:** 8 hours

#### Step 1: Update Mention Model with Sentiment Fields

```bash
rails generate migration AddSentimentToMentions
```

```ruby
# db/migrate/XXXXXX_add_sentiment_to_mentions.rb
class AddSentimentToMentions < ActiveRecord::Migration[7.1]
  def change
    add_column :mentions, :sentiment_score, :decimal, precision: 3, scale: 2
    add_column :mentions, :sentiment_label, :string
    add_column :mentions, :sentiment_analyzed_at, :datetime
    add_column :mentions, :sentiment_analysis_error, :text
    
    add_index :mentions, :sentiment_label
    add_index :mentions, :sentiment_score
    add_index :mentions, :sentiment_analyzed_at
  end
end
```

```bash
rails db:migrate
```

#### Step 2: Create SentimentAnalyzer Service

```ruby
# app/services/sentiment_analyzer.rb
class SentimentAnalyzer
  class AnalysisError < StandardError; end
  
  SENTIMENT_THRESHOLDS = {
    positive: 0.3,
    negative: -0.3
  }.freeze
  
  def initialize(mention)
    @mention = mention
    @client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
  end
  
  def analyze
    return false if @mention.content.blank?
    
    response = call_openai_api
    parse_and_save_sentiment(response)
    
    true
  rescue StandardError => e
    handle_error(e)
    false
  end
  
  private
  
  def call_openai_api
    @client.chat(
      parameters: {
        model: "gpt-4-turbo-preview",
        messages: [
          {
            role: "system",
            content: system_prompt
          },
          {
            role: "user",
            content: user_prompt
          }
        ],
        temperature: 0.3,
        max_tokens: 150
      }
    )
  end
  
  def system_prompt
    <<~PROMPT
      You are a sentiment analysis expert. Analyze the sentiment of AI assistant responses 
      about brands. Return a JSON object with:
      - score: a number between -1.0 (very negative) and 1.0 (very positive)
      - reasoning: brief explanation of the sentiment
      
      Consider:
      - Tone and language used
      - Presence of positive or negative descriptors
      - Overall recommendation strength
      - Context and nuance
    PROMPT
  end
  
  def user_prompt
    <<~PROMPT
      Brand: #{@mention.brand.name}
      Platform: #{@mention.platform}
      Query: #{@mention.query&.text || 'N/A'}
      
      Response to analyze:
      #{@mention.content}
      
      Provide sentiment analysis as JSON.
    PROMPT
  end
  
  def parse_and_save_sentiment(response)
    content = response.dig("choices", 0, "message", "content")
    raise AnalysisError, "No content in response" if content.blank?
    
    # Extract JSON from response (handle markdown code blocks)
    json_content = content.match(/```json\n(.*?)\n```/m)&.captures&.first || content
    result = JSON.parse(json_content)
    
    score = result["score"].to_f.clamp(-1.0, 1.0)
    label = determine_label(score)
    
    @mention.update!(
      sentiment_score: score,
      sentiment_label: label,
      sentiment_analyzed_at: Time.current,
      sentiment_analysis_error: nil
    )
  end
  
  def determine_label(score)
    return 'positive' if score >= SENTIMENT_THRESHOLDS[:positive]
    return 'negative' if score <= SENTIMENT_THRESHOLDS[:negative]
    'neutral'
  end
  
  def handle_error(error)
    Rails.logger.error("Sentiment analysis failed for mention #{@mention.id}: #{error.message}")

    @mention.update(
      sentiment_analysis_error: error.message,
      sentiment_analyzed_at: Time.current
    )
  end
end
```

#### Step 3: Update Mention Model

```ruby
# app/models/mention.rb
class Mention < ApplicationRecord
  belongs_to :brand
  belongs_to :query, optional: true
  belongs_to :monitoring_run, optional: true

  # Existing code...

  # Sentiment scopes
  scope :analyzed, -> { where.not(sentiment_analyzed_at: nil) }
  scope :not_analyzed, -> { where(sentiment_analyzed_at: nil) }
  scope :positive, -> { where(sentiment_label: 'positive') }
  scope :negative, -> { where(sentiment_label: 'negative') }
  scope :neutral, -> { where(sentiment_label: 'neutral') }
  scope :with_errors, -> { where.not(sentiment_analysis_error: nil) }

  # Sentiment methods
  def sentiment_analyzed?
    sentiment_analyzed_at.present?
  end

  def sentiment_positive?
    sentiment_label == 'positive'
  end

  def sentiment_negative?
    sentiment_label == 'negative'
  end

  def sentiment_neutral?
    sentiment_label == 'neutral'
  end

  def sentiment_color
    case sentiment_label
    when 'positive' then 'green'
    when 'negative' then 'red'
    when 'neutral' then 'gray'
    else 'gray'
    end
  end
end
```

#### Step 4: Create Service Tests

```ruby
# spec/services/sentiment_analyzer_spec.rb
require 'rails_helper'

RSpec.describe SentimentAnalyzer, type: :service do
  let(:brand) { create(:brand) }
  let(:mention) { create(:mention, brand: brand, content: "This is a great product!") }
  let(:analyzer) { described_class.new(mention) }

  describe '#analyze', :vcr do
    context 'with positive content' do
      it 'assigns positive sentiment' do
        expect(analyzer.analyze).to be true

        mention.reload
        expect(mention.sentiment_score).to be > 0
        expect(mention.sentiment_label).to eq('positive')
        expect(mention.sentiment_analyzed_at).to be_present
      end
    end

    context 'with negative content' do
      let(:mention) { create(:mention, brand: brand, content: "This product is terrible and unreliable.") }

      it 'assigns negative sentiment' do
        expect(analyzer.analyze).to be true

        mention.reload
        expect(mention.sentiment_score).to be < 0
        expect(mention.sentiment_label).to eq('negative')
      end
    end

    context 'with neutral content' do
      let(:mention) { create(:mention, brand: brand, content: "The product exists.") }

      it 'assigns neutral sentiment' do
        expect(analyzer.analyze).to be true

        mention.reload
        expect(mention.sentiment_score).to be_between(-0.3, 0.3)
        expect(mention.sentiment_label).to eq('neutral')
      end
    end

    context 'with blank content' do
      let(:mention) { create(:mention, brand: brand, content: "") }

      it 'returns false without calling API' do
        expect(analyzer.analyze).to be false
        expect(mention.reload.sentiment_analyzed_at).to be_nil
      end
    end

    context 'when API call fails' do
      before do
        allow_any_instance_of(OpenAI::Client).to receive(:chat).and_raise(StandardError.new("API Error"))
      end

      it 'handles error gracefully' do
        expect(analyzer.analyze).to be false

        mention.reload
        expect(mention.sentiment_analysis_error).to include("API Error")
        expect(mention.sentiment_analyzed_at).to be_present
      end
    end
  end
end
```

---

### Feature 3.2: Sentiment Analysis Job

**Estimated Time:** 4 hours

#### Step 1: Create Sentiment Analysis Job

```ruby
# app/jobs/analysis/sentiment_analysis_job.rb
module Analysis
  class SentimentAnalysisJob < ApplicationJob
    queue_as :analysis

    # Retry with exponential backoff
    retry_on StandardError, wait: :exponentially_longer, attempts: 3

    def perform(mention_id)
      mention = Mention.find(mention_id)

      analyzer = SentimentAnalyzer.new(mention)
      analyzer.analyze

      Rails.logger.info("Sentiment analyzed for mention #{mention_id}")
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error("Mention not found: #{mention_id}")
    end
  end
end
```

#### Step 2: Create Batch Sentiment Analysis Job

```ruby
# app/jobs/analysis/batch_sentiment_analysis_job.rb
module Analysis
  class BatchSentimentAnalysisJob < ApplicationJob
    queue_as :analysis

    def perform(brand_id: nil, limit: 100)
      mentions = build_mention_scope(brand_id)
                  .not_analyzed
                  .where(sentiment_analysis_error: nil)
                  .limit(limit)

      Rails.logger.info("Starting batch sentiment analysis for #{mentions.count} mentions")

      mentions.find_each do |mention|
        SentimentAnalysisJob.perform_later(mention.id)
      end

      Rails.logger.info("Queued #{mentions.count} mentions for sentiment analysis")
    end

    private

    def build_mention_scope(brand_id)
      scope = Mention.all
      scope = scope.where(brand_id: brand_id) if brand_id.present?
      scope
    end
  end
end
```

#### Step 3: Integrate with Monitoring Jobs

```ruby
# app/jobs/monitoring/platform_monitoring_job.rb
module Monitoring
  class PlatformMonitoringJob < ApplicationJob
    # Existing code...

    def perform(brand_id, platform)
      # ... existing monitoring code ...

      # After mentions are created, queue sentiment analysis
      if mentions.any?
        mentions.each do |mention|
          Analysis::SentimentAnalysisJob.perform_later(mention.id)
        end
      end
    end
  end
end
```

#### Step 4: Create Job Tests

```ruby
# spec/jobs/analysis/sentiment_analysis_job_spec.rb
require 'rails_helper'

RSpec.describe Analysis::SentimentAnalysisJob, type: :job do
  let(:mention) { create(:mention) }

  describe '#perform' do
    it 'analyzes sentiment for the mention' do
      analyzer = instance_double(SentimentAnalyzer)
      allow(SentimentAnalyzer).to receive(:new).with(mention).and_return(analyzer)
      allow(analyzer).to receive(:analyze).and_return(true)

      described_class.new.perform(mention.id)

      expect(analyzer).to have_received(:analyze)
    end

    it 'handles missing mention gracefully' do
      expect {
        described_class.new.perform(999999)
      }.not_to raise_error
    end
  end
end
```

```ruby
# spec/jobs/analysis/batch_sentiment_analysis_job_spec.rb
require 'rails_helper'

RSpec.describe Analysis::BatchSentimentAnalysisJob, type: :job do
  let(:brand) { create(:brand) }
  let!(:mentions) { create_list(:mention, 5, brand: brand, sentiment_analyzed_at: nil) }

  describe '#perform' do
    it 'queues sentiment analysis jobs for unanalyzed mentions' do
      expect {
        described_class.new.perform(brand_id: brand.id, limit: 10)
      }.to have_enqueued_job(Analysis::SentimentAnalysisJob).exactly(5).times
    end

    it 'respects the limit parameter' do
      create_list(:mention, 10, brand: brand, sentiment_analyzed_at: nil)

      expect {
        described_class.new.perform(brand_id: brand.id, limit: 3)
      }.to have_enqueued_job(Analysis::SentimentAnalysisJob).exactly(3).times
    end

    it 'skips already analyzed mentions' do
      mentions.first.update(sentiment_analyzed_at: Time.current)

      expect {
        described_class.new.perform(brand_id: brand.id)
      }.to have_enqueued_job(Analysis::SentimentAnalysisJob).exactly(4).times
    end
  end
end
```

---

### Feature 3.3: Citation Extraction Service

**Estimated Time:** 6 hours

#### Step 1: Create Citations Table

```bash
rails generate model Citation \
  mention:references \
  url:string \
  domain:string \
  position:integer \
  title:string \
  snippet:text
```

```ruby
# db/migrate/XXXXXX_create_citations.rb
class CreateCitations < ActiveRecord::Migration[7.1]
  def change
    create_table :citations, id: :uuid do |t|
      t.references :mention, type: :uuid, null: false, foreign_key: true
      t.string :url, null: false
      t.string :domain
      t.integer :position
      t.string :title
      t.text :snippet
      t.timestamps

      t.index :domain
      t.index :position
      t.index [:mention_id, :position], unique: true
    end
  end
end
```

```bash
rails db:migrate
```

#### Step 2: Create Citation Model

```ruby
# app/models/citation.rb
class Citation < ApplicationRecord
  belongs_to :mention

  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  validates :position, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  before_validation :extract_domain, if: :url_changed?

  scope :ordered, -> { order(position: :asc) }
  scope :by_domain, ->(domain) { where(domain: domain) }
  scope :top_positions, ->(limit = 3) { where('position <= ?', limit) }

  def extract_domain
    return if url.blank?

    uri = URI.parse(url)
    self.domain = uri.host&.gsub(/^www\./, '')
  rescue URI::InvalidURIError
    self.domain = nil
  end

  def position_label
    return 'N/A' if position.blank?

    case position
    when 1 then '1st'
    when 2 then '2nd'
    when 3 then '3rd'
    else "#{position}th"
    end
  end
end
```

#### Step 3: Update Mention Model

```ruby
# app/models/mention.rb
class Mention < ApplicationRecord
  # Existing associations...
  has_many :citations, dependent: :destroy

  # Existing code...

  def citations_extracted?
    citations.any?
  end

  def top_citation
    citations.ordered.first
  end
end
```

#### Step 4: Create CitationExtractor Service

```ruby
# app/services/citation_extractor.rb
class CitationExtractor
  URL_REGEX = %r{https?://[^\s<>"{}|\\^`\[\]]+}i

  def initialize(mention)
    @mention = mention
  end

  def extract
    return [] if @mention.content.blank?

    urls = extract_urls_from_content
    citations = create_citations(urls)

    Rails.logger.info("Extracted #{citations.count} citations for mention #{@mention.id}")
    citations
  rescue StandardError => e
    Rails.logger.error("Citation extraction failed for mention #{@mention.id}: #{e.message}")
    []
  end

  private

  def extract_urls_from_content
    @mention.content.scan(URL_REGEX).uniq
  end

  def create_citations(urls)
    # Delete existing citations
    @mention.citations.destroy_all

    urls.each_with_index.map do |url, index|
      @mention.citations.create!(
        url: url,
        position: index + 1
      )
    end
  end
end
```

#### Step 5: Create Service Tests

```ruby
# spec/services/citation_extractor_spec.rb
require 'rails_helper'

RSpec.describe CitationExtractor, type: :service do
  let(:brand) { create(:brand) }
  let(:content_with_urls) do
    <<~CONTENT
      Here are some great resources:
      1. https://example.com/article1
      2. https://blog.example.org/post
      3. http://docs.example.net/guide
    CONTENT
  end
  let(:mention) { create(:mention, brand: brand, content: content_with_urls) }
  let(:extractor) { described_class.new(mention) }

  describe '#extract' do
    it 'extracts URLs from content' do
      citations = extractor.extract

      expect(citations.count).to eq(3)
      expect(citations.map(&:url)).to include('https://example.com/article1')
    end

    it 'assigns positions to citations' do
      citations = extractor.extract

      expect(citations.first.position).to eq(1)
      expect(citations.second.position).to eq(2)
      expect(citations.third.position).to eq(3)
    end

    it 'extracts domains from URLs' do
      citations = extractor.extract

      expect(citations.first.domain).to eq('example.com')
      expect(citations.second.domain).to eq('blog.example.org')
    end

    it 'handles content without URLs' do
      mention.update(content: "No URLs here")
      citations = extractor.extract

      expect(citations).to be_empty
    end

    it 'removes duplicate URLs' do
      mention.update(content: "https://example.com https://example.com")
      citations = extractor.extract

      expect(citations.count).to eq(1)
    end

    it 'replaces existing citations' do
      create(:citation, mention: mention, url: 'https://old.com')

      citations = extractor.extract

      expect(mention.citations.count).to eq(3)
      expect(mention.citations.pluck(:url)).not_to include('https://old.com')
    end
  end
end
```

```ruby
# spec/factories/citations.rb
FactoryBot.define do
  factory :citation do
    mention
    url { Faker::Internet.url }
    position { 1 }

    trait :with_domain do
      after(:build) do |citation|
        citation.extract_domain
      end
    end
  end
end
```

---

## Week 8: Visibility Scoring System

### Feature 3.4: Visibility Score Model

**Estimated Time:** 6 hours

#### Step 1: Install TimescaleDB Extension

```bash
# On your PostgreSQL server, install TimescaleDB
# For macOS with Homebrew:
brew install timescaledb

# Follow the setup instructions to enable the extension
```

```bash
rails generate migration EnableTimescaleDB
```

```ruby
# db/migrate/XXXXXX_enable_timescaledb.rb
class EnableTimescaleDB < ActiveRecord::Migration[7.1]
  def up
    execute "CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;"
  end

  def down
    execute "DROP EXTENSION IF EXISTS timescaledb CASCADE;"
  end
end
```

```bash
rails db:migrate
```

#### Step 2: Create VisibilityScore Model

```bash
rails generate model VisibilityScore \
  brand:references \
  platform:string \
  date:date \
  mention_count:integer \
  mention_frequency_score:decimal \
  position_score:decimal \
  sentiment_score:decimal \
  citation_quality_score:decimal \
  overall_score:decimal \
  trend:string
```

```ruby
# db/migrate/XXXXXX_create_visibility_scores.rb
class CreateVisibilityScores < ActiveRecord::Migration[7.1]
  def change
    create_table :visibility_scores, id: :uuid do |t|
      t.references :brand, type: :uuid, null: false, foreign_key: true
      t.string :platform, null: false
      t.date :date, null: false

      # Raw metrics
      t.integer :mention_count, default: 0
      t.integer :positive_mention_count, default: 0
      t.integer :negative_mention_count, default: 0
      t.integer :neutral_mention_count, default: 0
      t.integer :citation_count, default: 0
      t.integer :top_position_count, default: 0

      # Component scores (0-100)
      t.decimal :mention_frequency_score, precision: 5, scale: 2, default: 0
      t.decimal :position_score, precision: 5, scale: 2, default: 0
      t.decimal :sentiment_score, precision: 5, scale: 2, default: 0
      t.decimal :citation_quality_score, precision: 5, scale: 2, default: 0

      # Overall score (0-100)
      t.decimal :overall_score, precision: 5, scale: 2, default: 0

      # Trend indicator
      t.string :trend # 'up', 'down', 'stable'
      t.decimal :trend_percentage, precision: 5, scale: 2

      t.timestamps

      t.index [:brand_id, :platform, :date], unique: true, name: 'index_visibility_scores_unique'
      t.index :date
      t.index :overall_score
      t.index :trend
    end

    # Convert to TimescaleDB hypertable
    execute <<-SQL
      SELECT create_hypertable('visibility_scores', 'date',
        chunk_time_interval => INTERVAL '1 month',
        if_not_exists => TRUE
      );
    SQL

    # Create continuous aggregate for weekly rollups
    execute <<-SQL
      CREATE MATERIALIZED VIEW IF NOT EXISTS visibility_scores_weekly
      WITH (timescaledb.continuous) AS
      SELECT
        brand_id,
        platform,
        time_bucket('1 week', date) AS week,
        AVG(overall_score) as avg_score,
        MAX(overall_score) as max_score,
        MIN(overall_score) as min_score,
        SUM(mention_count) as total_mentions
      FROM visibility_scores
      GROUP BY brand_id, platform, time_bucket('1 week', date);
    SQL
  end

  def down
    execute "DROP MATERIALIZED VIEW IF EXISTS visibility_scores_weekly;"
    drop_table :visibility_scores
  end
end
```

```bash
rails db:migrate
```

#### Step 3: Create VisibilityScore Model

```ruby
# app/models/visibility_score.rb
class VisibilityScore < ApplicationRecord
  belongs_to :brand

  PLATFORMS = %w[chatgpt claude perplexity gemini].freeze
  TRENDS = %w[up down stable].freeze

  validates :platform, presence: true, inclusion: { in: PLATFORMS }
  validates :date, presence: true
  validates :trend, inclusion: { in: TRENDS }, allow_nil: true
  validates :overall_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  # Scopes
  scope :for_platform, ->(platform) { where(platform: platform) }
  scope :for_date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :recent, ->(days = 30) { where('date >= ?', days.days.ago.to_date) }
  scope :ordered, -> { order(date: :desc) }
  scope :trending_up, -> { where(trend: 'up') }
  scope :trending_down, -> { where(trend: 'down') }

  # Class methods
  def self.latest_for_brand(brand_id)
    where(brand_id: brand_id)
      .group(:platform)
      .select('DISTINCT ON (platform) *')
      .order(:platform, date: :desc)
  end

  def self.average_score_for_period(brand_id, start_date, end_date)
    where(brand_id: brand_id, date: start_date..end_date)
      .average(:overall_score)
      .to_f
      .round(2)
  end

  # Instance methods
  def score_grade
    case overall_score
    when 90..100 then 'A'
    when 80...90 then 'B'
    when 70...80 then 'C'
    when 60...70 then 'D'
    else 'F'
    end
  end

  def score_color
    case overall_score
    when 80..100 then 'green'
    when 60...80 then 'yellow'
    when 40...60 then 'orange'
    else 'red'
    end
  end

  def trend_icon
    case trend
    when 'up' then '↑'
    when 'down' then '↓'
    when 'stable' then '→'
    else '—'
    end
  end

  def trend_color
    case trend
    when 'up' then 'green'
    when 'down' then 'red'
    when 'stable' then 'gray'
    else 'gray'
    end
  end
end
```

#### Step 4: Update Brand Model

```ruby
# app/models/brand.rb
class Brand < ApplicationRecord
  # Existing associations...
  has_many :visibility_scores, dependent: :destroy

  # Existing code...

  def latest_visibility_scores
    visibility_scores.latest_for_brand(id)
  end

  def average_visibility_score(days: 30)
    start_date = days.days.ago.to_date
    end_date = Date.current

    visibility_scores.average_score_for_period(id, start_date, end_date)
  end
end
```

#### Step 5: Create Factory and Tests

```ruby
# spec/factories/visibility_scores.rb
FactoryBot.define do
  factory :visibility_score do
    brand
    platform { VisibilityScore::PLATFORMS.sample }
    date { Date.current }
    mention_count { rand(1..50) }
    positive_mention_count { rand(0..mention_count) }
    negative_mention_count { rand(0..(mention_count - positive_mention_count)) }
    neutral_mention_count { mention_count - positive_mention_count - negative_mention_count }
    citation_count { rand(0..mention_count) }
    top_position_count { rand(0..citation_count) }
    mention_frequency_score { rand(0.0..100.0).round(2) }
    position_score { rand(0.0..100.0).round(2) }
    sentiment_score { rand(0.0..100.0).round(2) }
    citation_quality_score { rand(0.0..100.0).round(2) }
    overall_score { rand(0.0..100.0).round(2) }
    trend { VisibilityScore::TRENDS.sample }
    trend_percentage { rand(-50.0..50.0).round(2) }

    trait :excellent do
      overall_score { rand(90.0..100.0).round(2) }
      trend { 'up' }
    end

    trait :poor do
      overall_score { rand(0.0..40.0).round(2) }
      trend { 'down' }
    end
  end
end
```

```ruby
# spec/models/visibility_score_spec.rb
require 'rails_helper'

RSpec.describe VisibilityScore, type: :model do
  describe 'associations' do
    it { should belong_to(:brand) }
  end

  describe 'validations' do
    it { should validate_presence_of(:platform) }
    it { should validate_presence_of(:date) }
    it { should validate_inclusion_of(:platform).in_array(VisibilityScore::PLATFORMS) }
  end

  describe 'scopes' do
    let(:brand) { create(:brand) }
    let!(:chatgpt_score) { create(:visibility_score, brand: brand, platform: 'chatgpt') }
    let!(:claude_score) { create(:visibility_score, brand: brand, platform: 'claude') }
    let!(:old_score) { create(:visibility_score, brand: brand, date: 60.days.ago) }

    it 'filters by platform' do
      expect(VisibilityScore.for_platform('chatgpt')).to include(chatgpt_score)
      expect(VisibilityScore.for_platform('chatgpt')).not_to include(claude_score)
    end

    it 'filters recent scores' do
      expect(VisibilityScore.recent(30)).to include(chatgpt_score)
      expect(VisibilityScore.recent(30)).not_to include(old_score)
    end
  end

  describe '#score_grade' do
    it 'returns correct grade for score' do
      score = build(:visibility_score, overall_score: 95)
      expect(score.score_grade).to eq('A')

      score.overall_score = 75
      expect(score.score_grade).to eq('C')
    end
  end

  describe '#trend_icon' do
    it 'returns correct icon for trend' do
      score = build(:visibility_score, trend: 'up')
      expect(score.trend_icon).to eq('↑')

      score.trend = 'down'
      expect(score.trend_icon).to eq('↓')
    end
  end
end
```

---

### Feature 3.5: Visibility Scoring Service

**Estimated Time:** 10 hours

#### Step 1: Create VisibilityScorer Service

```ruby
# app/services/visibility_scorer.rb
class VisibilityScorer
  # Weights for overall score calculation
  WEIGHTS = {
    mention_frequency: 0.30,
    position: 0.25,
    sentiment: 0.25,
    citation_quality: 0.20
  }.freeze

  # Thresholds for trend detection
  TREND_THRESHOLD = 5.0 # percentage

  def initialize(brand, platform, date = Date.current)
    @brand = brand
    @platform = platform
    @date = date
  end

  def calculate
    mentions = fetch_mentions

    return nil if mentions.empty?

    score_data = {
      brand: @brand,
      platform: @platform,
      date: @date,

      # Raw metrics
      mention_count: mentions.count,
      positive_mention_count: mentions.positive.count,
      negative_mention_count: mentions.negative.count,
      neutral_mention_count: mentions.neutral.count,
      citation_count: calculate_citation_count(mentions),
      top_position_count: calculate_top_position_count(mentions),

      # Component scores
      mention_frequency_score: calculate_mention_frequency_score(mentions),
      position_score: calculate_position_score(mentions),
      sentiment_score: calculate_sentiment_score(mentions),
      citation_quality_score: calculate_citation_quality_score(mentions)
    }

    # Calculate overall score
    score_data[:overall_score] = calculate_overall_score(score_data)

    # Calculate trend
    trend_data = calculate_trend(score_data[:overall_score])
    score_data.merge!(trend_data)

    # Create or update visibility score
    visibility_score = VisibilityScore.find_or_initialize_by(
      brand: @brand,
      platform: @platform,
      date: @date
    )

    visibility_score.update!(score_data)
    visibility_score
  end

  private

  def fetch_mentions
    @brand.mentions
      .where(platform: @platform)
      .where('DATE(created_at) = ?', @date)
      .includes(:citations)
  end

  def calculate_citation_count(mentions)
    mentions.sum { |m| m.citations.count }
  end

  def calculate_top_position_count(mentions)
    mentions.sum { |m| m.citations.top_positions(3).count }
  end

  # Mention Frequency Score (0-100)
  # Based on number of mentions compared to a baseline
  def calculate_mention_frequency_score(mentions)
    count = mentions.count

    # Scoring curve: 1-5 mentions = 20-60, 6-10 = 60-80, 11+ = 80-100
    score = case count
            when 0 then 0
            when 1..5 then 20 + (count * 8)
            when 6..10 then 60 + ((count - 5) * 4)
            else
              [80 + ((count - 10) * 2), 100].min
            end

    score.to_f.round(2)
  end

  # Position Score (0-100)
  # Based on citation positions (lower is better)
  def calculate_position_score(mentions)
    citations = mentions.flat_map(&:citations).compact

    return 0.0 if citations.empty?

    # Weight citations by position (1st = 100, 2nd = 80, 3rd = 60, etc.)
    total_weighted_score = citations.sum do |citation|
      next 0 unless citation.position

      case citation.position
      when 1 then 100
      when 2 then 80
      when 3 then 60
      when 4..5 then 40
      when 6..10 then 20
      else 10
      end
    end

    # Average the weighted scores
    (total_weighted_score.to_f / citations.count).round(2)
  end

  # Sentiment Score (0-100)
  # Based on sentiment distribution
  def calculate_sentiment_score(mentions)
    analyzed_mentions = mentions.select(&:sentiment_analyzed?)

    return 50.0 if analyzed_mentions.empty? # Neutral default

    positive_count = analyzed_mentions.count(&:sentiment_positive?)
    negative_count = analyzed_mentions.count(&:sentiment_negative?)
    total = analyzed_mentions.count

    # Calculate percentage of positive mentions
    positive_percentage = (positive_count.to_f / total * 100)
    negative_percentage = (negative_count.to_f / total * 100)

    # Score: 100% positive = 100, 100% negative = 0, 50/50 = 50
    score = positive_percentage - (negative_percentage / 2)

    score.clamp(0, 100).round(2)
  end

  # Citation Quality Score (0-100)
  # Based on presence and quality of citations
  def calculate_citation_quality_score(mentions)
    total_mentions = mentions.count
    mentions_with_citations = mentions.count(&:citations_extracted?)

    return 0.0 if total_mentions.zero?

    # Base score: percentage of mentions with citations
    base_score = (mentions_with_citations.to_f / total_mentions * 100)

    # Bonus for top positions
    top_position_count = calculate_top_position_count(mentions)
    bonus = [top_position_count * 5, 20].min # Up to 20 bonus points

    [base_score + bonus, 100].min.round(2)
  end

  # Overall Score (0-100)
  # Weighted average of component scores
  def calculate_overall_score(score_data)
    weighted_sum =
      score_data[:mention_frequency_score] * WEIGHTS[:mention_frequency] +
      score_data[:position_score] * WEIGHTS[:position] +
      score_data[:sentiment_score] * WEIGHTS[:sentiment] +
      score_data[:citation_quality_score] * WEIGHTS[:citation_quality]

    weighted_sum.round(2)
  end

  # Calculate trend compared to previous period
  def calculate_trend(current_score)
    previous_score = fetch_previous_score

    return { trend: nil, trend_percentage: nil } unless previous_score

    percentage_change = ((current_score - previous_score.overall_score) / previous_score.overall_score * 100).round(2)

    trend = if percentage_change >= TREND_THRESHOLD
              'up'
            elsif percentage_change <= -TREND_THRESHOLD
              'down'
            else
              'stable'
            end

    { trend: trend, trend_percentage: percentage_change }
  end

  def fetch_previous_score
    VisibilityScore.find_by(
      brand: @brand,
      platform: @platform,
      date: @date - 1.day
    )
  end
end
```

#### Step 2: Create Service Tests

```ruby
# spec/services/visibility_scorer_spec.rb
require 'rails_helper'

RSpec.describe VisibilityScorer, type: :service do
  let(:brand) { create(:brand) }
  let(:platform) { 'chatgpt' }
  let(:date) { Date.current }
  let(:scorer) { described_class.new(brand, platform, date) }

  describe '#calculate' do
    context 'with no mentions' do
      it 'returns nil' do
        expect(scorer.calculate).to be_nil
      end
    end

    context 'with mentions' do
      let!(:mentions) do
        create_list(:mention, 5,
          brand: brand,
          platform: platform,
          created_at: date,
          sentiment_score: 0.5,
          sentiment_label: 'positive',
          sentiment_analyzed_at: Time.current
        )
      end

      before do
        # Add citations to mentions
        mentions.each_with_index do |mention, index|
          create(:citation, mention: mention, position: index + 1)
        end
      end

      it 'creates a visibility score' do
        expect {
          scorer.calculate
        }.to change(VisibilityScore, :count).by(1)
      end

      it 'calculates all component scores' do
        score = scorer.calculate

        expect(score.mention_frequency_score).to be > 0
        expect(score.position_score).to be > 0
        expect(score.sentiment_score).to be > 0
        expect(score.citation_quality_score).to be > 0
        expect(score.overall_score).to be > 0
      end

      it 'sets raw metrics' do
        score = scorer.calculate

        expect(score.mention_count).to eq(5)
        expect(score.positive_mention_count).to eq(5)
        expect(score.citation_count).to eq(5)
      end
    end

    context 'with previous score for trend calculation' do
      let!(:mentions) { create_list(:mention, 5, brand: brand, platform: platform, created_at: date) }
      let!(:previous_score) do
        create(:visibility_score,
          brand: brand,
          platform: platform,
          date: date - 1.day,
          overall_score: 50.0
        )
      end

      it 'calculates trend' do
        score = scorer.calculate

        expect(score.trend).to be_in(['up', 'down', 'stable'])
        expect(score.trend_percentage).to be_present
      end
    end
  end
end
```

---

### Feature 3.6: Visibility Scoring Job

**Estimated Time:** 4 hours

#### Step 1: Create Visibility Scoring Job

```ruby
# app/jobs/analysis/visibility_scoring_job.rb
module Analysis
  class VisibilityScoringJob < ApplicationJob
    queue_as :analysis

    def perform(brand_id, platform, date = Date.current)
      brand = Brand.find(brand_id)

      scorer = VisibilityScorer.new(brand, platform, date)
      visibility_score = scorer.calculate

      if visibility_score
        Rails.logger.info("Visibility score calculated for #{brand.name} on #{platform}: #{visibility_score.overall_score}")
      else
        Rails.logger.info("No mentions found for #{brand.name} on #{platform} on #{date}")
      end
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error("Brand not found: #{brand_id}")
    end
  end
end
```

#### Step 2: Create Daily Scoring Job

```ruby
# app/jobs/analysis/daily_visibility_scoring_job.rb
module Analysis
  class DailyVisibilityScoringJob < ApplicationJob
    queue_as :analysis

    def perform(date = Date.current)
      Rails.logger.info("Starting daily visibility scoring for #{date}")

      brands = Brand.active
      platforms = VisibilityScore::PLATFORMS

      brands.find_each do |brand|
        platforms.each do |platform|
          VisibilityScoringJob.perform_later(brand.id, platform, date)
        end
      end

      Rails.logger.info("Queued visibility scoring for #{brands.count} brands across #{platforms.count} platforms")
    end
  end
end
```

#### Step 3: Schedule Daily Job

```ruby
# config/initializers/sidekiq_scheduler.rb
# If using sidekiq-scheduler gem

require 'sidekiq-scheduler'

Sidekiq.configure_server do |config|
  config.on(:startup) do
    Sidekiq.schedule = {
      'daily_visibility_scoring' => {
        'cron' => '0 2 * * *', # Run at 2 AM daily
        'class' => 'Analysis::DailyVisibilityScoringJob',
        'queue' => 'analysis'
      }
    }

    SidekiqScheduler::Scheduler.instance.reload_schedule!
  end
end
```

#### Step 4: Create Job Tests

```ruby
# spec/jobs/analysis/visibility_scoring_job_spec.rb
require 'rails_helper'

RSpec.describe Analysis::VisibilityScoringJob, type: :job do
  let(:brand) { create(:brand) }
  let(:platform) { 'chatgpt' }
  let(:date) { Date.current }

  describe '#perform' do
    it 'calculates visibility score' do
      scorer = instance_double(VisibilityScorer)
      allow(VisibilityScorer).to receive(:new).and_return(scorer)
      allow(scorer).to receive(:calculate).and_return(create(:visibility_score))

      described_class.new.perform(brand.id, platform, date)

      expect(scorer).to have_received(:calculate)
    end

    it 'handles missing brand gracefully' do
      expect {
        described_class.new.perform(999999, platform, date)
      }.not_to raise_error
    end
  end
end
```

```ruby
# spec/jobs/analysis/daily_visibility_scoring_job_spec.rb
require 'rails_helper'

RSpec.describe Analysis::DailyVisibilityScoringJob, type: :job do
  let!(:brands) { create_list(:brand, 3) }

  describe '#perform' do
    it 'queues scoring jobs for all brands and platforms' do
      platforms_count = VisibilityScore::PLATFORMS.count
      expected_jobs = brands.count * platforms_count

      expect {
        described_class.new.perform
      }.to have_enqueued_job(Analysis::VisibilityScoringJob).exactly(expected_jobs).times
    end
  end
end
```

---

## Week 9: Competitor Tracking & Historical Analysis

### Feature 3.7: Competitor Model & Tracking

**Estimated Time:** 8 hours

#### Step 1: Create Competitor Model

```bash
rails generate model Competitor \
  brand:references \
  name:string \
  domain:string \
  active:boolean
```

```ruby
# db/migrate/XXXXXX_create_competitors.rb
class CreateCompetitors < ActiveRecord::Migration[7.1]
  def change
    create_table :competitors, id: :uuid do |t|
      t.references :brand, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.string :domain
      t.boolean :active, default: true
      t.text :description
      t.timestamps

      t.index [:brand_id, :name], unique: true
    end
  end
end
```

```bash
rails db:migrate
```

#### Step 2: Create CompetitorMention Model

```bash
rails generate model CompetitorMention \
  competitor:references \
  platform:string \
  query:references \
  content:text \
  position:integer \
  mentioned_at:datetime
```

```ruby
# db/migrate/XXXXXX_create_competitor_mentions.rb
class CreateCompetitorMentions < ActiveRecord::Migration[7.1]
  def change
    create_table :competitor_mentions, id: :uuid do |t|
      t.references :competitor, type: :uuid, null: false, foreign_key: true
      t.string :platform, null: false
      t.references :query, type: :uuid, foreign_key: true
      t.text :content
      t.integer :position
      t.datetime :mentioned_at
      t.timestamps

      t.index :platform
      t.index :mentioned_at
      t.index [:competitor_id, :platform, :mentioned_at]
    end
  end
end
```

```bash
rails db:migrate
```

#### Step 3: Create Models

```ruby
# app/models/competitor.rb
class Competitor < ApplicationRecord
  belongs_to :brand
  has_many :competitor_mentions, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :brand_id }

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  def mention_count(platform: nil, start_date: nil, end_date: nil)
    scope = competitor_mentions
    scope = scope.where(platform: platform) if platform
    scope = scope.where('mentioned_at >= ?', start_date) if start_date
    scope = scope.where('mentioned_at <= ?', end_date) if end_date
    scope.count
  end

  def share_of_voice(platform: nil, start_date: 30.days.ago, end_date: Date.current)
    competitor_count = mention_count(platform: platform, start_date: start_date, end_date: end_date)
    brand_count = brand.mentions
      .then { |scope| platform ? scope.where(platform: platform) : scope }
      .where(created_at: start_date..end_date)
      .count

    total = competitor_count + brand_count
    return 0.0 if total.zero?

    (brand_count.to_f / total * 100).round(2)
  end
end
```

```ruby
# app/models/competitor_mention.rb
class CompetitorMention < ApplicationRecord
  belongs_to :competitor
  belongs_to :query, optional: true

  validates :platform, presence: true
  validates :content, presence: true

  scope :for_platform, ->(platform) { where(platform: platform) }
  scope :recent, ->(days = 30) { where('mentioned_at >= ?', days.days.ago) }
  scope :ordered, -> { order(mentioned_at: :desc) }
end
```

#### Step 4: Update Brand Model

```ruby
# app/models/brand.rb
class Brand < ApplicationRecord
  # Existing associations...
  has_many :competitors, dependent: :destroy

  # Existing code...

  def competitor_comparison(platform: nil, days: 30)
    start_date = days.days.ago
    end_date = Date.current

    competitors.active.map do |competitor|
      {
        name: competitor.name,
        mention_count: competitor.mention_count(platform: platform, start_date: start_date, end_date: end_date),
        share_of_voice: competitor.share_of_voice(platform: platform, start_date: start_date, end_date: end_date)
      }
    end
  end
end
```

#### Step 5: Create Factories

```ruby
# spec/factories/competitors.rb
FactoryBot.define do
  factory :competitor do
    brand
    name { Faker::Company.name }
    domain { Faker::Internet.domain_name }
    active { true }
    description { Faker::Company.catch_phrase }
  end
end
```

```ruby
# spec/factories/competitor_mentions.rb
FactoryBot.define do
  factory :competitor_mention do
    competitor
    platform { VisibilityScore::PLATFORMS.sample }
    content { Faker::Lorem.paragraph }
    position { rand(1..10) }
    mentioned_at { Time.current }
  end
end
```

#### Step 6: Create Model Tests

```ruby
# spec/models/competitor_spec.rb
require 'rails_helper'

RSpec.describe Competitor, type: :model do
  describe 'associations' do
    it { should belong_to(:brand) }
    it { should have_many(:competitor_mentions).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
  end

  describe '#share_of_voice' do
    let(:brand) { create(:brand) }
    let(:competitor) { create(:competitor, brand: brand) }

    before do
      create_list(:mention, 7, brand: brand, created_at: 15.days.ago)
      create_list(:competitor_mention, 3, competitor: competitor, mentioned_at: 15.days.ago)
    end

    it 'calculates share of voice percentage' do
      # 7 brand mentions out of 10 total = 70%
      expect(competitor.share_of_voice).to eq(70.0)
    end
  end
end
```

---

### Feature 3.8: Historical Tracking & Trends

**Estimated Time:** 8 hours

#### Step 1: Create Historical Analysis Service

```ruby
# app/services/historical_analyzer.rb
class HistoricalAnalyzer
  def initialize(brand, platform: nil)
    @brand = brand
    @platform = platform
  end

  # Get trend data for charts
  def score_trend(days: 30)
    end_date = Date.current
    start_date = end_date - days.days

    scores = fetch_scores(start_date, end_date)

    scores.map do |score|
      {
        date: score.date.to_s,
        overall_score: score.overall_score,
        mention_count: score.mention_count,
        sentiment_score: score.sentiment_score
      }
    end
  end

  # Week-over-week comparison
  def week_over_week_change
    this_week_start = Date.current.beginning_of_week
    last_week_start = this_week_start - 1.week

    this_week_avg = average_score(this_week_start, Date.current)
    last_week_avg = average_score(last_week_start, last_week_start.end_of_week)

    return nil if last_week_avg.zero?

    change = ((this_week_avg - last_week_avg) / last_week_avg * 100).round(2)

    {
      this_week: this_week_avg,
      last_week: last_week_avg,
      change_percentage: change,
      trend: determine_trend(change)
    }
  end

  # Month-over-month comparison
  def month_over_month_change
    this_month_start = Date.current.beginning_of_month
    last_month_start = this_month_start - 1.month

    this_month_avg = average_score(this_month_start, Date.current)
    last_month_avg = average_score(last_month_start, last_month_start.end_of_month)

    return nil if last_month_avg.zero?

    change = ((this_month_avg - last_month_avg) / last_month_avg * 100).round(2)

    {
      this_month: this_month_avg,
      last_month: last_month_avg,
      change_percentage: change,
      trend: determine_trend(change)
    }
  end

  # Get best and worst performing days
  def performance_summary(days: 30)
    end_date = Date.current
    start_date = end_date - days.days

    scores = fetch_scores(start_date, end_date)

    return nil if scores.empty?

    {
      best_day: scores.max_by(&:overall_score),
      worst_day: scores.min_by(&:overall_score),
      average_score: scores.average(:overall_score).to_f.round(2),
      total_mentions: scores.sum(:mention_count)
    }
  end

  # Platform comparison
  def platform_comparison(days: 30)
    end_date = Date.current
    start_date = end_date - days.days

    VisibilityScore::PLATFORMS.map do |platform|
      scores = @brand.visibility_scores
        .for_platform(platform)
        .for_date_range(start_date, end_date)

      {
        platform: platform,
        average_score: scores.average(:overall_score).to_f.round(2),
        mention_count: scores.sum(:mention_count),
        trend: calculate_platform_trend(platform, start_date, end_date)
      }
    end.sort_by { |p| -p[:average_score] }
  end

  private

  def fetch_scores(start_date, end_date)
    scope = @brand.visibility_scores.for_date_range(start_date, end_date)
    scope = scope.for_platform(@platform) if @platform
    scope.ordered
  end

  def average_score(start_date, end_date)
    scores = fetch_scores(start_date, end_date)
    return 0.0 if scores.empty?

    scores.average(:overall_score).to_f.round(2)
  end

  def determine_trend(change_percentage)
    return 'up' if change_percentage > 5
    return 'down' if change_percentage < -5
    'stable'
  end

  def calculate_platform_trend(platform, start_date, end_date)
    scores = @brand.visibility_scores
      .for_platform(platform)
      .for_date_range(start_date, end_date)
      .order(:date)

    return 'stable' if scores.count < 2

    first_half = scores.limit(scores.count / 2).average(:overall_score).to_f
    second_half = scores.offset(scores.count / 2).average(:overall_score).to_f

    return 'stable' if first_half.zero?

    change = ((second_half - first_half) / first_half * 100)
    determine_trend(change)
  end
end
```

#### Step 2: Create Service Tests

```ruby
# spec/services/historical_analyzer_spec.rb
require 'rails_helper'

RSpec.describe HistoricalAnalyzer, type: :service do
  let(:brand) { create(:brand) }
  let(:analyzer) { described_class.new(brand) }

  describe '#score_trend' do
    before do
      create_list(:visibility_score, 7, brand: brand, platform: 'chatgpt')
    end

    it 'returns trend data' do
      trend = analyzer.score_trend(days: 7)

      expect(trend).to be_an(Array)
      expect(trend.first).to have_key(:date)
      expect(trend.first).to have_key(:overall_score)
    end
  end

  describe '#week_over_week_change' do
    before do
      # This week
      create(:visibility_score,
        brand: brand,
        platform: 'chatgpt',
        date: Date.current.beginning_of_week,
        overall_score: 80
      )

      # Last week
      create(:visibility_score,
        brand: brand,
        platform: 'chatgpt',
        date: 1.week.ago.beginning_of_week,
        overall_score: 60
      )
    end

    it 'calculates week-over-week change' do
      result = analyzer.week_over_week_change

      expect(result[:this_week]).to be > result[:last_week]
      expect(result[:trend]).to eq('up')
    end
  end

  describe '#platform_comparison' do
    before do
      VisibilityScore::PLATFORMS.each do |platform|
        create(:visibility_score, brand: brand, platform: platform, overall_score: rand(50..100))
      end
    end

    it 'compares all platforms' do
      comparison = analyzer.platform_comparison(days: 30)

      expect(comparison.count).to eq(VisibilityScore::PLATFORMS.count)
      expect(comparison.first[:platform]).to be_present
      expect(comparison.first[:average_score]).to be >= 0
    end

    it 'sorts by average score descending' do
      comparison = analyzer.platform_comparison(days: 30)

      scores = comparison.map { |p| p[:average_score] }
      expect(scores).to eq(scores.sort.reverse)
    end
  end
end
```

---

## Week 10: Analytics Dashboard

### Feature 3.9: Analytics Dashboard

**Estimated Time:** 12 hours

#### Step 1: Install Chartkick for Charts

```ruby
# Gemfile
gem 'chartkick'
gem 'groupdate' # For time-series grouping
```

```bash
bundle install
```

```javascript
// app/javascript/application.js
import "chartkick"
import "Chart.bundle"
```

#### Step 2: Create Analytics Controller

```ruby
# app/controllers/analytics_controller.rb
class AnalyticsController < ApplicationController
  before_action :set_brand
  before_action :set_date_range

  def index
    @analyzer = HistoricalAnalyzer.new(@brand)

    # Overview metrics
    @latest_scores = @brand.latest_visibility_scores
    @average_score = @brand.average_visibility_score(days: @days)

    # Trend data
    @score_trend = @analyzer.score_trend(days: @days)
    @week_over_week = @analyzer.week_over_week_change
    @month_over_month = @analyzer.month_over_month_change

    # Performance summary
    @performance = @analyzer.performance_summary(days: @days)

    # Platform comparison
    @platform_comparison = @analyzer.platform_comparison(days: @days)

    # Sentiment breakdown
    @sentiment_breakdown = calculate_sentiment_breakdown

    # Recent mentions
    @recent_mentions = @brand.mentions
      .includes(:query, :citations)
      .order(created_at: :desc)
      .limit(10)

    # Top citations
    @top_citations = top_citations

    # Competitor comparison
    @competitor_data = @brand.competitor_comparison(days: @days)
  end

  def platform_detail
    @platform = params[:platform]
    @analyzer = HistoricalAnalyzer.new(@brand, platform: @platform)

    @score_trend = @analyzer.score_trend(days: @days)
    @performance = @analyzer.performance_summary(days: @days)

    @mentions = @brand.mentions
      .where(platform: @platform)
      .where('created_at >= ?', @days.days.ago)
      .includes(:query, :citations)
      .order(created_at: :desc)
      .page(params[:page])
  end

  private

  def set_brand
    @brand = current_workspace.brands.find(params[:brand_id])
  end

  def set_date_range
    @days = (params[:days] || 30).to_i
    @start_date = @days.days.ago.to_date
    @end_date = Date.current
  end

  def calculate_sentiment_breakdown
    mentions = @brand.mentions
      .where('created_at >= ?', @start_date)
      .analyzed

    {
      positive: mentions.positive.count,
      neutral: mentions.neutral.count,
      negative: mentions.negative.count
    }
  end

  def top_citations
    Citation.joins(mention: :brand)
      .where(brands: { id: @brand.id })
      .where('mentions.created_at >= ?', @start_date)
      .group(:domain)
      .select('domain, COUNT(*) as citation_count')
      .order('citation_count DESC')
      .limit(10)
  end
end
```

#### Step 3: Add Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Existing routes...

  resources :brands do
    resource :analytics, only: [:index] do
      get :platform_detail
    end
  end
end
```

#### Step 4: Create Analytics Dashboard View

```erb
<!-- app/views/analytics/index.html.erb -->
<div class="min-h-screen bg-gray-50">
  <!-- Header -->
  <div class="bg-white shadow">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
      <div class="md:flex md:items-center md:justify-between">
        <div class="flex-1 min-w-0">
          <h1 class="text-3xl font-bold text-gray-900">
            Analytics Dashboard
          </h1>
          <p class="mt-1 text-sm text-gray-500">
            <%= @brand.name %> • Last <%= @days %> days
          </p>
        </div>
        <div class="mt-4 flex md:mt-0 md:ml-4">
          <div class="inline-flex rounded-md shadow-sm">
            <%= link_to "7 days", analytics_path(brand_id: @brand.id, days: 7),
                class: "px-4 py-2 text-sm font-medium rounded-l-md #{@days == 7 ? 'bg-indigo-600 text-white' : 'bg-white text-gray-700 hover:bg-gray-50'}" %>
            <%= link_to "30 days", analytics_path(brand_id: @brand.id, days: 30),
                class: "px-4 py-2 text-sm font-medium #{@days == 30 ? 'bg-indigo-600 text-white' : 'bg-white text-gray-700 hover:bg-gray-50'}" %>
            <%= link_to "90 days", analytics_path(brand_id: @brand.id, days: 90),
                class: "px-4 py-2 text-sm font-medium rounded-r-md #{@days == 90 ? 'bg-indigo-600 text-white' : 'bg-white text-gray-700 hover:bg-gray-50'}" %>
          </div>
        </div>
      </div>
    </div>
  </div>

  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <!-- Key Metrics -->
    <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4 mb-8">
      <!-- Average Score -->
      <div class="bg-white overflow-hidden shadow rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">
                  Average Score
                </dt>
                <dd class="flex items-baseline">
                  <div class="text-2xl font-semibold text-gray-900">
                    <%= number_with_precision(@average_score, precision: 1) %>
                  </div>
                  <% if @week_over_week %>
                    <div class="ml-2 flex items-baseline text-sm font-semibold <%= @week_over_week[:trend] == 'up' ? 'text-green-600' : @week_over_week[:trend] == 'down' ? 'text-red-600' : 'text-gray-500' %>">
                      <%= @week_over_week[:trend] == 'up' ? '↑' : @week_over_week[:trend] == 'down' ? '↓' : '→' %>
                      <%= number_with_precision(@week_over_week[:change_percentage].abs, precision: 1) %>%
                    </div>
                  <% end %>
                </dd>
              </dl>
            </div>
          </div>
        </div>
      </div>

      <!-- Total Mentions -->
      <div class="bg-white overflow-hidden shadow rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z" />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">
                  Total Mentions
                </dt>
                <dd class="text-2xl font-semibold text-gray-900">
                  <%= @performance&.dig(:total_mentions) || 0 %>
                </dd>
              </dl>
            </div>
          </div>
        </div>
      </div>

      <!-- Best Day -->
      <div class="bg-white overflow-hidden shadow rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <svg class="h-6 w-6 text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">
                  Best Day
                </dt>
                <dd class="text-2xl font-semibold text-gray-900">
                  <%= @performance&.dig(:best_day)&.overall_score&.round(1) || 'N/A' %>
                </dd>
                <% if @performance&.dig(:best_day) %>
                  <dd class="text-xs text-gray-500">
                    <%= @performance[:best_day].date.strftime('%b %d') %>
                  </dd>
                <% end %>
              </dl>
            </div>
          </div>
        </div>
      </div>

      <!-- Worst Day -->
      <div class="bg-white overflow-hidden shadow rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <svg class="h-6 w-6 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 17h8m0 0V9m0 8l-8-8-4 4-6-6" />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">
                  Worst Day
                </dt>
                <dd class="text-2xl font-semibold text-gray-900">
                  <%= @performance&.dig(:worst_day)&.overall_score&.round(1) || 'N/A' %>
                </dd>
                <% if @performance&.dig(:worst_day) %>
                  <dd class="text-xs text-gray-500">
                    <%= @performance[:worst_day].date.strftime('%b %d') %>
                  </dd>
                <% end %>
              </dl>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Charts Row 1 -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
      <!-- Visibility Score Trend -->
      <div class="bg-white shadow rounded-lg p-6">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Visibility Score Trend</h3>
        <%= line_chart @score_trend.map { |d| [d[:date], d[:overall_score]] },
            colors: ["#4F46E5"],
            curve: false,
            library: {
              scales: {
                y: {
                  beginAtZero: true,
                  max: 100
                }
              }
            } %>
      </div>

      <!-- Platform Comparison -->
      <div class="bg-white shadow rounded-lg p-6">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Platform Comparison</h3>
        <%= column_chart @platform_comparison.map { |p| [p[:platform].titleize, p[:average_score]] },
            colors: ["#10B981"] %>
      </div>
    </div>

    <!-- Charts Row 2 -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
      <!-- Sentiment Breakdown -->
      <div class="bg-white shadow rounded-lg p-6">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Sentiment Breakdown</h3>
        <%= pie_chart [
              ["Positive", @sentiment_breakdown[:positive]],
              ["Neutral", @sentiment_breakdown[:neutral]],
              ["Negative", @sentiment_breakdown[:negative]]
            ],
            colors: ["#10B981", "#6B7280", "#EF4444"] %>
      </div>

      <!-- Mention Timeline -->
      <div class="bg-white shadow rounded-lg p-6">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Mention Timeline</h3>
        <%= area_chart @score_trend.map { |d| [d[:date], d[:mention_count]] },
            colors: ["#8B5CF6"] %>
      </div>
    </div>

    <!-- Platform Details -->
    <div class="bg-white shadow rounded-lg mb-6">
      <div class="px-6 py-4 border-b border-gray-200">
        <h3 class="text-lg font-medium text-gray-900">Platform Performance</h3>
      </div>
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Platform
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Avg Score
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Mentions
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Trend
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <% @platform_comparison.each do |platform_data| %>
              <tr>
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="text-sm font-medium text-gray-900">
                    <%= platform_data[:platform].titleize %>
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="text-sm text-gray-900">
                    <%= number_with_precision(platform_data[:average_score], precision: 1) %>
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="text-sm text-gray-900">
                    <%= platform_data[:mention_count] %>
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full
                    <%= platform_data[:trend] == 'up' ? 'bg-green-100 text-green-800' :
                        platform_data[:trend] == 'down' ? 'bg-red-100 text-red-800' :
                        'bg-gray-100 text-gray-800' %>">
                    <%= platform_data[:trend] == 'up' ? '↑' : platform_data[:trend] == 'down' ? '↓' : '→' %>
                    <%= platform_data[:trend].titleize %>
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                  <%= link_to "View Details", platform_detail_analytics_path(brand_id: @brand.id, platform: platform_data[:platform], days: @days),
                      class: "text-indigo-600 hover:text-indigo-900" %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Top Citations -->
    <div class="bg-white shadow rounded-lg mb-6">
      <div class="px-6 py-4 border-b border-gray-200">
        <h3 class="text-lg font-medium text-gray-900">Top Citation Sources</h3>
      </div>
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Domain
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Citations
              </th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <% @top_citations.each do |citation| %>
              <tr>
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="text-sm font-medium text-gray-900">
                    <%= citation.domain %>
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="text-sm text-gray-900">
                    <%= citation.citation_count %>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Recent Mentions -->
    <div class="bg-white shadow rounded-lg">
      <div class="px-6 py-4 border-b border-gray-200">
        <h3 class="text-lg font-medium text-gray-900">Recent Mentions</h3>
      </div>
      <div class="divide-y divide-gray-200">
        <% @recent_mentions.each do |mention| %>
          <div class="px-6 py-4">
            <div class="flex items-start justify-between">
              <div class="flex-1">
                <div class="flex items-center space-x-2 mb-2">
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-indigo-100 text-indigo-800">
                    <%= mention.platform.titleize %>
                  </span>
                  <% if mention.sentiment_label %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium
                      <%= mention.sentiment_label == 'positive' ? 'bg-green-100 text-green-800' :
                          mention.sentiment_label == 'negative' ? 'bg-red-100 text-red-800' :
                          'bg-gray-100 text-gray-800' %>">
                      <%= mention.sentiment_label.titleize %>
                    </span>
                  <% end %>
                  <span class="text-xs text-gray-500">
                    <%= time_ago_in_words(mention.created_at) %> ago
                  </span>
                </div>
                <% if mention.query %>
                  <p class="text-sm font-medium text-gray-900 mb-1">
                    Query: <%= mention.query.text %>
                  </p>
                <% end %>
                <p class="text-sm text-gray-600 line-clamp-2">
                  <%= truncate(mention.content, length: 200) %>
                </p>
                <% if mention.citations.any? %>
                  <div class="mt-2 flex items-center space-x-2">
                    <svg class="h-4 w-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
                    </svg>
                    <span class="text-xs text-gray-500">
                      <%= mention.citations.count %> citation(s)
                    </span>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
  </div>
</div>
```

#### Step 5: Create Platform Detail View

```erb
<!-- app/views/analytics/platform_detail.html.erb -->
<div class="min-h-screen bg-gray-50">
  <div class="bg-white shadow">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-bold text-gray-900">
            <%= @platform.titleize %> Analytics
          </h1>
          <p class="mt-1 text-sm text-gray-500">
            <%= @brand.name %> • Last <%= @days %> days
          </p>
        </div>
        <%= link_to "← Back to Dashboard", analytics_path(brand_id: @brand.id, days: @days),
            class: "inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50" %>
      </div>
    </div>
  </div>

  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <!-- Performance Summary -->
    <div class="grid grid-cols-1 gap-5 sm:grid-cols-3 mb-8">
      <div class="bg-white overflow-hidden shadow rounded-lg">
        <div class="p-5">
          <dt class="text-sm font-medium text-gray-500 truncate">Average Score</dt>
          <dd class="mt-1 text-3xl font-semibold text-gray-900">
            <%= number_with_precision(@performance&.dig(:average_score) || 0, precision: 1) %>
          </dd>
        </div>
      </div>
      <div class="bg-white overflow-hidden shadow rounded-lg">
        <div class="p-5">
          <dt class="text-sm font-medium text-gray-500 truncate">Total Mentions</dt>
          <dd class="mt-1 text-3xl font-semibold text-gray-900">
            <%= @performance&.dig(:total_mentions) || 0 %>
          </dd>
        </div>
      </div>
      <div class="bg-white overflow-hidden shadow rounded-lg">
        <div class="p-5">
          <dt class="text-sm font-medium text-gray-500 truncate">Peak Score</dt>
          <dd class="mt-1 text-3xl font-semibold text-gray-900">
            <%= number_with_precision(@performance&.dig(:best_day)&.overall_score || 0, precision: 1) %>
          </dd>
        </div>
      </div>
    </div>

    <!-- Score Trend Chart -->
    <div class="bg-white shadow rounded-lg p-6 mb-6">
      <h3 class="text-lg font-medium text-gray-900 mb-4">Score Trend</h3>
      <%= line_chart @score_trend.map { |d| [d[:date], d[:overall_score]] },
          colors: ["#4F46E5"],
          curve: false %>
    </div>

    <!-- Mentions List -->
    <div class="bg-white shadow rounded-lg">
      <div class="px-6 py-4 border-b border-gray-200">
        <h3 class="text-lg font-medium text-gray-900">All Mentions</h3>
      </div>
      <div class="divide-y divide-gray-200">
        <% @mentions.each do |mention| %>
          <div class="px-6 py-4">
            <!-- Similar to recent mentions in main dashboard -->
            <div class="flex items-start justify-between">
              <div class="flex-1">
                <div class="flex items-center space-x-2 mb-2">
                  <% if mention.sentiment_label %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium
                      <%= mention.sentiment_label == 'positive' ? 'bg-green-100 text-green-800' :
                          mention.sentiment_label == 'negative' ? 'bg-red-100 text-red-800' :
                          'bg-gray-100 text-gray-800' %>">
                      <%= mention.sentiment_label.titleize %>
                      (<%= number_with_precision(mention.sentiment_score, precision: 2) %>)
                    </span>
                  <% end %>
                  <span class="text-xs text-gray-500">
                    <%= mention.created_at.strftime('%b %d, %Y at %I:%M %p') %>
                  </span>
                </div>
                <% if mention.query %>
                  <p class="text-sm font-medium text-gray-900 mb-1">
                    Query: <%= mention.query.text %>
                  </p>
                <% end %>
                <p class="text-sm text-gray-600">
                  <%= mention.content %>
                </p>
                <% if mention.citations.any? %>
                  <div class="mt-3">
                    <p class="text-xs font-medium text-gray-700 mb-1">Citations:</p>
                    <ul class="space-y-1">
                      <% mention.citations.ordered.each do |citation| %>
                        <li class="text-xs text-gray-600">
                          <%= citation.position_label %>:
                          <%= link_to citation.domain, citation.url, target: '_blank', class: 'text-indigo-600 hover:text-indigo-800' %>
                        </li>
                      <% end %>
                    </ul>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Pagination -->
      <div class="px-6 py-4 border-t border-gray-200">
        <%== pagy_nav(@pagy) if @pagy %>
      </div>
    </div>
  </div>
</div>
```

#### Step 6: Create Controller Tests

```ruby
# spec/controllers/analytics_controller_spec.rb
require 'rails_helper'

RSpec.describe AnalyticsController, type: :controller do
  let(:workspace) { create(:workspace) }
  let(:user) { create(:user) }
  let(:brand) { create(:brand, workspace: workspace) }

  before do
    sign_in(user)
    allow(controller).to receive(:current_workspace).and_return(workspace)
  end

  describe 'GET #index' do
    before do
      create_list(:visibility_score, 5, brand: brand)
      create_list(:mention, 10, brand: brand)
    end

    it 'returns http success' do
      get :index, params: { brand_id: brand.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns necessary instance variables' do
      get :index, params: { brand_id: brand.id }

      expect(assigns(:brand)).to eq(brand)
      expect(assigns(:analyzer)).to be_a(HistoricalAnalyzer)
      expect(assigns(:score_trend)).to be_present
      expect(assigns(:platform_comparison)).to be_present
    end

    it 'respects date range parameter' do
      get :index, params: { brand_id: brand.id, days: 7 }

      expect(assigns(:days)).to eq(7)
    end
  end

  describe 'GET #platform_detail' do
    let(:platform) { 'chatgpt' }

    before do
      create_list(:mention, 5, brand: brand, platform: platform)
    end

    it 'returns http success' do
      get :platform_detail, params: { brand_id: brand.id, platform: platform }
      expect(response).to have_http_status(:success)
    end

    it 'filters mentions by platform' do
      get :platform_detail, params: { brand_id: brand.id, platform: platform }

      expect(assigns(:platform)).to eq(platform)
      expect(assigns(:mentions).pluck(:platform).uniq).to eq([platform])
    end
  end
end
```

---

## Testing & Quality Assurance

### Running Tests

```bash
# Run all Phase 3 tests
bundle exec rspec spec/services/sentiment_analyzer_spec.rb
bundle exec rspec spec/services/citation_extractor_spec.rb
bundle exec rspec spec/services/visibility_scorer_spec.rb
bundle exec rspec spec/services/historical_analyzer_spec.rb
bundle exec rspec spec/models/visibility_score_spec.rb
bundle exec rspec spec/models/competitor_spec.rb
bundle exec rspec spec/jobs/analysis/
bundle exec rspec spec/controllers/analytics_controller_spec.rb

# Run all tests with coverage
bundle exec rspec --format documentation
```

### VCR Configuration for API Tests

```ruby
# spec/support/vcr.rb
require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!

  # Filter sensitive data
  config.filter_sensitive_data('<OPENAI_API_KEY>') { ENV['OPENAI_API_KEY'] }

  # Allow localhost for test server
  config.ignore_localhost = true

  # Default cassette options
  config.default_cassette_options = {
    record: :once,
    match_requests_on: [:method, :uri, :body]
  }
end
```

### Performance Testing

```ruby
# spec/performance/visibility_scoring_performance_spec.rb
require 'rails_helper'
require 'benchmark'

RSpec.describe 'Visibility Scoring Performance', type: :performance do
  let(:brand) { create(:brand) }
  let(:platform) { 'chatgpt' }

  it 'scores 100 mentions in under 5 seconds' do
    create_list(:mention, 100, brand: brand, platform: platform, created_at: Date.current)

    time = Benchmark.realtime do
      scorer = VisibilityScorer.new(brand, platform)
      scorer.calculate
    end

    expect(time).to be < 5.0
  end
end
```

---

## Database Optimization

### Add Indexes for Performance

```ruby
# db/migrate/XXXXXX_add_performance_indexes.rb
class AddPerformanceIndexes < ActiveRecord::Migration[7.1]
  def change
    # Mentions indexes for analytics queries
    add_index :mentions, [:brand_id, :platform, :created_at]
    add_index :mentions, [:brand_id, :sentiment_label, :created_at]

    # Citations indexes
    add_index :citations, [:mention_id, :position]

    # Visibility scores indexes
    add_index :visibility_scores, [:brand_id, :date, :overall_score]

    # Competitor mentions indexes
    add_index :competitor_mentions, [:competitor_id, :platform, :mentioned_at]
  end
end
```

### TimescaleDB Continuous Aggregates

```sql
-- Create monthly rollup view
CREATE MATERIALIZED VIEW IF NOT EXISTS visibility_scores_monthly
WITH (timescaledb.continuous) AS
SELECT
  brand_id,
  platform,
  time_bucket('1 month', date) AS month,
  AVG(overall_score) as avg_score,
  MAX(overall_score) as max_score,
  MIN(overall_score) as min_score,
  SUM(mention_count) as total_mentions,
  AVG(sentiment_score) as avg_sentiment
FROM visibility_scores
GROUP BY brand_id, platform, time_bucket('1 month', date);

-- Add refresh policy
SELECT add_continuous_aggregate_policy('visibility_scores_monthly',
  start_offset => INTERVAL '3 months',
  end_offset => INTERVAL '1 day',
  schedule_interval => INTERVAL '1 day');
```

---

## Deployment Checklist

### Environment Variables

```bash
# .env.production
OPENAI_API_KEY=your_production_key
REDIS_URL=redis://your-redis-server:6379/0
DATABASE_URL=postgresql://user:pass@host:5432/geo_platform_production

# Sidekiq concurrency
SIDEKIQ_CONCURRENCY=10

# Analysis settings
SENTIMENT_ANALYSIS_BATCH_SIZE=100
VISIBILITY_SCORING_ENABLED=true
```

### Sidekiq Configuration

```yaml
# config/sidekiq.yml
production:
  :concurrency: 10
  :queues:
    - [critical, 10]
    - [default, 5]
    - [monitoring, 3]
    - [analysis, 2]
    - [low, 1]
```

### Cron Jobs Setup

```ruby
# config/initializers/sidekiq_scheduler.rb
Sidekiq.configure_server do |config|
  config.on(:startup) do
    Sidekiq.schedule = {
      'daily_visibility_scoring' => {
        'cron' => '0 2 * * *',
        'class' => 'Analysis::DailyVisibilityScoringJob',
        'queue' => 'analysis'
      },
      'batch_sentiment_analysis' => {
        'cron' => '0 */6 * * *', # Every 6 hours
        'class' => 'Analysis::BatchSentimentAnalysisJob',
        'queue' => 'analysis'
      }
    }

    SidekiqScheduler::Scheduler.instance.reload_schedule!
  end
end
```

---

## Phase 3 Completion Checklist

### Week 7: Sentiment Analysis & Citation Extraction
- [ ] Sentiment fields added to Mention model
- [ ] SentimentAnalyzer service created and tested
- [ ] OpenAI API integration working
- [ ] Sentiment analysis job created
- [ ] Batch sentiment analysis job created
- [ ] Citation model created
- [ ] CitationExtractor service created and tested
- [ ] Citation extraction integrated with mentions
- [ ] VCR cassettes recorded for API tests
- [ ] All tests passing (>80% coverage)

### Week 8: Visibility Scoring System
- [ ] TimescaleDB extension installed
- [ ] VisibilityScore model created with hypertable
- [ ] Continuous aggregates created (weekly, monthly)
- [ ] VisibilityScorer service created and tested
- [ ] All scoring components implemented:
  - [ ] Mention frequency score
  - [ ] Position score
  - [ ] Sentiment score
  - [ ] Citation quality score
  - [ ] Overall score calculation
  - [ ] Trend calculation
- [ ] Visibility scoring job created
- [ ] Daily scoring job created and scheduled
- [ ] Performance indexes added
- [ ] All tests passing

### Week 9: Competitor Tracking & Historical Analysis
- [ ] Competitor model created
- [ ] CompetitorMention model created
- [ ] Share of voice calculation implemented
- [ ] Competitor comparison working
- [ ] HistoricalAnalyzer service created
- [ ] Week-over-week comparison implemented
- [ ] Month-over-month comparison implemented
- [ ] Platform comparison implemented
- [ ] Performance summary implemented
- [ ] All tests passing

### Week 10: Analytics Dashboard
- [ ] Chartkick and Chart.js installed
- [ ] AnalyticsController created
- [ ] Analytics dashboard view created with:
  - [ ] Key metrics cards
  - [ ] Visibility score trend chart
  - [ ] Platform comparison chart
  - [ ] Sentiment breakdown pie chart
  - [ ] Mention timeline chart
  - [ ] Platform performance table
  - [ ] Top citations table
  - [ ] Recent mentions list
- [ ] Platform detail view created
- [ ] Date range filtering working
- [ ] Turbo Frames for dynamic updates
- [ ] Responsive design with Tailwind
- [ ] Controller tests passing
- [ ] UI/UX reviewed and polished

---

## Next Steps

After completing Phase 3, you should have:

✅ **Advanced Analytics System** with sentiment analysis and visibility scoring
✅ **Comprehensive Dashboard** with beautiful charts and visualizations
✅ **Competitor Tracking** with share of voice calculations
✅ **Historical Analysis** with trend detection and comparisons
✅ **Production-Ready Code** with extensive test coverage
✅ **Optimized Database** with TimescaleDB for time-series data

**Ready for Phase 4: Alerts & Notifications** 🚀

In Phase 4, you'll build:
- Real-time alert system for score changes
- Email and Slack notifications
- Custom alert rules and thresholds
- Alert management dashboard
- Notification preferences

---

## Additional Resources

### Useful Commands

```bash
# Backfill sentiment analysis for existing mentions
rails runner "Analysis::BatchSentimentAnalysisJob.perform_now(limit: 1000)"

# Recalculate visibility scores for a date range
rails runner "
  Brand.find_each do |brand|
    (30.days.ago.to_date..Date.current).each do |date|
      VisibilityScore::PLATFORMS.each do |platform|
        Analysis::VisibilityScoringJob.perform_now(brand.id, platform, date)
      end
    end
  end
"

# Refresh TimescaleDB continuous aggregates
rails runner "
  ActiveRecord::Base.connection.execute('CALL refresh_continuous_aggregate(\"visibility_scores_weekly\", NULL, NULL);')
  ActiveRecord::Base.connection.execute('CALL refresh_continuous_aggregate(\"visibility_scores_monthly\", NULL, NULL);')
"
```

### Monitoring Queries

```sql
-- Check sentiment analysis coverage
SELECT
  COUNT(*) as total_mentions,
  COUNT(sentiment_analyzed_at) as analyzed,
  COUNT(sentiment_analysis_error) as errors,
  ROUND(COUNT(sentiment_analyzed_at)::numeric / COUNT(*) * 100, 2) as coverage_percentage
FROM mentions;

-- Check visibility score trends
SELECT
  date,
  platform,
  overall_score,
  trend
FROM visibility_scores
WHERE brand_id = 'your-brand-id'
  AND date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY date DESC, platform;

-- Top performing platforms
SELECT
  platform,
  AVG(overall_score) as avg_score,
  COUNT(*) as score_count
FROM visibility_scores
WHERE date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY platform
ORDER BY avg_score DESC;
```

---

**END OF PHASE 3 DOCUMENT**

