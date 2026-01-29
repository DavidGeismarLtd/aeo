# frozen_string_literal: true

# Brand model representing a brand/company being monitored within a workspace
# Tracks brand information, metadata, and activity status
class Brand < ApplicationRecord
  # Multi-tenancy - automatically scopes all queries to current workspace
  # This prevents cross-tenant data leaks and automatically assigns workspace_id
  acts_as_tenant :workspace

  # Associations
  belongs_to :workspace

  # Validations
  validates :workspace, presence: true
  validates :name, presence: true, length: { minimum: 1, maximum: 100 }
  validates :name, uniqueness: { scope: :workspace_id, message: "already exists in this workspace" }
  validates :domain, format: {
    with: /\A(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9][a-z0-9-]{0,61}[a-z0-9]\z/i,
    message: "must be a valid domain name"
  }, allow_blank: true
  validates :description, length: { maximum: 1000 }, allow_blank: true

  # Callbacks
  before_validation :normalize_domain
  after_create :set_default_metadata

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_name, -> { order(:name) }
  scope :by_workspace, ->(workspace) { where(workspace: workspace) }
  scope :with_domain, -> { where.not(domain: nil) }

  # Instance Methods

  # Activate brand
  def activate!
    update!(active: true)
  end

  # Deactivate brand
  def deactivate!
    update!(active: false)
  end

  # Toggle active status
  def toggle_active!
    update!(active: !active)
  end

  # Get metadata value
  def get_metadata(key)
    metadata[key.to_s]
  end

  # Set metadata value
  def set_metadata(key, value)
    self.metadata = metadata.merge(key.to_s => value)
    save
  end

  # Common metadata helpers
  def industry
    get_metadata("industry")
  end

  def industry=(value)
    set_metadata("industry", value)
  end

  def keywords
    get_metadata("keywords") || []
  end

  def keywords=(value)
    set_metadata("keywords", Array(value))
  end

  private

  # Normalize domain to lowercase and remove protocol
  def normalize_domain
    return if domain.blank?

    self.domain = domain.downcase
                       .gsub(/^https?:\/\//, "")  # Remove protocol
                       .gsub(/^www\./, "")        # Remove www
                       .gsub(/\/$/, "")           # Remove trailing slash
  end

  # Set default metadata on creation
  def set_default_metadata
    self.metadata ||= {}
    self.metadata["created_by"] ||= "system"
    self.metadata["keywords"] ||= []
    save if metadata_changed?
  end
end
