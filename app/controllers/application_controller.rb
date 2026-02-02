class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Include authorization concern for workspace-based access control
  include Authorization

  # Set current tenant before any action (for workspace-scoped resources)
  before_action :set_current_tenant, if: :user_signed_in?

  # Make current_workspace available in views
  helper_method :current_workspace

  private

  # Set the current tenant for acts_as_tenant from URL params
  def set_current_tenant
    workspace_slug = params[:workspace_slug]

    if workspace_slug
      # Find workspace and verify user has access
      workspace = current_user.workspaces.find_by!(slug: workspace_slug)

      # Set the current tenant for acts_as_tenant
      # This automatically scopes all queries to this workspace
      ActsAsTenant.current_tenant = workspace

      # Also store in session for non-scoped pages
      session[:current_workspace_id] = workspace.id

    elsif session[:current_workspace_id]
      # Restore from session if no slug in URL
      workspace = current_user.workspaces.find_by(id: session[:current_workspace_id])
      ActsAsTenant.current_tenant = workspace if workspace
    else
      # If no workspace is set, use the user's first workspace as default
      # This ensures the workspace switcher is visible on first login
      workspace = current_user.workspaces.first
      if workspace
        ActsAsTenant.current_tenant = workspace
        session[:current_workspace_id] = workspace.id
      end
    end

  rescue ActiveRecord::RecordNotFound
    handle_workspace_not_found
  end

  # Handle workspace not found or no access
  def handle_workspace_not_found
    ActsAsTenant.current_tenant = nil
    session.delete(:current_workspace_id)
    redirect_to root_path, alert: "Workspace not found or you don't have access"
  end
end
