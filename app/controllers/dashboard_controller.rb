# frozen_string_literal: true

# Dashboard controller for authenticated users
class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
  end
end

