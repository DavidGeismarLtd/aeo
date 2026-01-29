# frozen_string_literal: true

# Workspace model representing a tenant/organization in the multi-tenant architecture
# Each workspace contains brands and has users with role-based access through memberships
class Workspace < ApplicationRecord
  # Associations
  has_many :workspace_memberships, dependent: :destroy
  has_many :users, through: :workspace_memberships
  has_many :brands, dependent: :destroy

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :slug, presence: true, uniqueness: { case_sensitive: false }
  validates :slug, format: {
    with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/,
    message: "only allows lowercase letters, numbers, and hyphens (no leading/trailing hyphens)"
  }, if: -> { slug.present? }

  # Callbacks
  before_validation :normalize_slug
  before_validation :generate_slug, on: :create, if: -> { slug.blank? }

  # Scopes
  scope :active, -> { joins(:brands).where(brands: { active: true }).distinct }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_name, -> { order(:name) }

  # Instance Methods

  # Get the owner of this workspace
  def owner
    workspace_memberships.find_by(role: "owner")&.user
  end

  # Get all admins (including owner)
  def admins
    users.joins(:workspace_memberships)
         .where(workspace_memberships: { workspace_id: id, role: [ "owner", "admin" ] })
  end

  # Check if user is a member
  def member?(user)
    return false unless user
    workspace_memberships.exists?(user_id: user.id)
  end

  # Get user's role in this workspace
  def role_for(user)
    return nil unless user
    workspace_memberships.find_by(user_id: user.id)&.role
  end

  # Check if user has specific permission level
  def user_can_edit?(user)
    role = role_for(user)
    %w[owner admin editor].include?(role)
  end

  def user_can_admin?(user)
    role = role_for(user)
    %w[owner admin].include?(role)
  end

  private

  # Generate slug from name
  def generate_slug
    return if name.blank?

    base_slug = name.parameterize
    candidate_slug = base_slug
    counter = 1

    # Ensure uniqueness
    while Workspace.exists?(slug: candidate_slug)
      candidate_slug = "#{base_slug}-#{counter}"
      counter += 1
    end

    self.slug = candidate_slug
  end

  # Normalize slug to lowercase
  def normalize_slug
    self.slug = slug.downcase if slug.present?
  end
end
