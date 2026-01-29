# frozen_string_literal: true

# WorkspaceMembership join table managing user access to workspaces with role-based permissions
# Roles: owner (1 per workspace), admin, editor, viewer
class WorkspaceMembership < ApplicationRecord
  # Constants
  ROLES = %w[owner admin editor viewer].freeze

  # Associations
  belongs_to :workspace
  belongs_to :user

  # Validations
  validates :workspace, presence: true
  validates :user, presence: true
  validates :role, presence: true, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :workspace_id, message: "is already a member of this workspace" }
  validate :only_one_owner_per_workspace, if: -> { role == "owner" }

  # Callbacks
  after_create :send_membership_notification
  after_destroy :cleanup_workspace_if_empty

  # Scopes
  scope :owners, -> { where(role: "owner") }
  scope :admins, -> { where(role: "admin") }
  scope :editors, -> { where(role: "editor") }
  scope :viewers, -> { where(role: "viewer") }
  scope :by_role, ->(role) { ROLES.include?(role.to_s) ? where(role: role) : none }
  scope :recent, -> { order(created_at: :desc) }

  # Instance Methods

  # Role checks
  def owner?
    role == "owner"
  end

  def admin?
    %w[owner admin].include?(role)
  end

  def can_edit?
    %w[owner admin editor].include?(role)
  end

  def can_view?
    true # All members can view
  end

  # Promote/demote role
  def promote!
    case role
    when "viewer" then update!(role: "editor")
    when "editor" then update!(role: "admin")
    when "admin" then update!(role: "owner")
    else
      false
    end
  end

  def demote!
    case role
    when "owner" then update!(role: "admin")
    when "admin" then update!(role: "editor")
    when "editor" then update!(role: "viewer")
    else
      false
    end
  end

  private

  # Ensure only one owner per workspace
  def only_one_owner_per_workspace
    if workspace && workspace.workspace_memberships.owners.where.not(id: id).exists?
      errors.add(:role, "workspace can only have one owner")
    end
  end

  # Send notification when user is added to workspace
  def send_membership_notification
    # TODO: Implement notification system in later phase
    # WorkspaceMembershipMailer.added_to_workspace(self).deliver_later
  end

  # Delete workspace if last member leaves
  def cleanup_workspace_if_empty
    ActsAsTenant.without_tenant do
      workspace.destroy if workspace.workspace_memberships.empty?
    end
  end
end
