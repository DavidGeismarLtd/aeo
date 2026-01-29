# frozen_string_literal: true

# Custom Devise registrations controller
# Handles user sign up and account updates with custom parameters
class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_sign_up_params, only: [ :create ]
  before_action :configure_account_update_params, only: [ :update ]

  protected

  # Permit additional parameters for sign up
  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :first_name, :last_name ])
  end

  # Permit additional parameters for account update
  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update, keys: [ :first_name, :last_name ])
  end

  # Redirect after sign up
  def after_sign_up_path_for(resource)
    flash[:notice] = "Welcome! Please check your email to confirm your account."
    root_path
  end

  # Redirect after inactive sign up (email confirmation required)
  def after_inactive_sign_up_path_for(resource)
    flash[:notice] = "Please check your email to confirm your account."
    root_path
  end
end

