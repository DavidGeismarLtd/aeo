# frozen_string_literal: true

# Authorization concern for role-based access control in workspaces
# Handles workspace membership verification and role hierarchy
module Authorization
  extend ActiveSupport::Concern

  included do
    # Only add rescue_from if this is a controller
    if respond_to?(:rescue_from)
      rescue_from NotAuthorizedError, with: :handle_not_authorized
    end
  end

  # Custom error for authorization failures
  class NotAuthorizedError < StandardError; end

  # Check if current user has required role in current workspace
  # Role hierarchy: viewer < editor < admin < owner
  def authorize_workspace_access!(required_role = :viewer)
    unless has_workspace_role?(required_role)
      raise NotAuthorizedError, "You don't have permission to perform this action"
    end
  end

  # Check if user has at least the specified role
  def has_workspace_role?(required_role)
    return false unless current_tenant && current_user

    membership = current_user.workspace_memberships
                             .find_by(workspace: current_tenant)

    return false unless membership

    # Role hierarchy: viewer < editor < admin < owner
    role_hierarchy = { viewer: 0, editor: 1, admin: 2, owner: 3 }
    user_level = role_hierarchy[membership.role.to_sym] || 0
    required_level = role_hierarchy[required_role.to_sym] || 0

    user_level >= required_level
  end

  # Convenience methods for role checking
  def workspace_owner?
    has_workspace_role?(:owner)
  end

  def workspace_admin?
    has_workspace_role?(:admin)
  end

  def workspace_editor?
    has_workspace_role?(:editor)
  end

  def workspace_viewer?
    has_workspace_role?(:viewer)
  end

  # Helper to get current tenant (workspace)
  def current_tenant
    ActsAsTenant.current_tenant
  end

  # Helper to get current workspace (alias for current_tenant)
  def current_workspace
    current_tenant
  end

  # Require workspace to be set
  def require_workspace
    unless current_workspace
      redirect_to root_path, alert: "Please select a workspace"
    end
  end

  private

  # Handle authorization errors
  def handle_not_authorized
    respond_to do |format|
      format.html { redirect_to root_path, alert: "You are not authorized to perform this action" }
      format.json { render json: { error: "Not authorized" }, status: :forbidden }
    end
  end
end
