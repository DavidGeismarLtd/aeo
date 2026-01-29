# frozen_string_literal: true

# Custom Devise sessions controller
# Handles user sign in and sign out with custom flash messages
class Users::SessionsController < Devise::SessionsController
  # Override to add custom behavior
  def create
    super do |resource|
      flash[:notice] = "Welcome back, #{resource.first_name}!"
    end
  end

  def destroy
    super do
      flash[:notice] = "You have been signed out successfully."
    end
  end
end

