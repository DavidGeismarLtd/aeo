# frozen_string_literal: true

# Custom Devise confirmations controller
# Handles email confirmation functionality
class Users::ConfirmationsController < Devise::ConfirmationsController
  # Override to add custom behavior if needed

  protected

  def after_confirmation_path_for(resource_name, resource)
    flash[:notice] = "Your email has been confirmed. Welcome to AEO!"
    new_user_session_path
  end
end

