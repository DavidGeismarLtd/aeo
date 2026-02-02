# frozen_string_literal: true

# Dashboard controller for authenticated users
class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    # Load brands with efficient queries (no N+1)
    @brands = current_workspace.brands
                               .active
                               .recent
                               .limit(10)

    # Calculate and cache dashboard statistics
    @stats = fetch_dashboard_stats
  end

  private

  def fetch_dashboard_stats
    # Cache for 15 minutes to improve performance
    Rails.cache.fetch(dashboard_cache_key, expires_in: 15.minutes) do
      calculate_dashboard_stats
    end
  end

  def dashboard_cache_key
    # Cache key includes workspace ID and current date
    # This ensures fresh data each day and per workspace
    "workspace:#{current_workspace.id}:dashboard:#{Date.current}"
  end

  def calculate_dashboard_stats
    {
      total_brands: calculate_total_brands,
      total_mentions: calculate_total_mentions,
      avg_visibility_score: calculate_avg_visibility_score,
      mentions_this_week: calculate_mentions_this_week,
      top_brand: find_top_brand,
      recent_activity: calculate_recent_activity
    }
  end

  def calculate_total_brands
    current_workspace.brands.active.count
  end

  def calculate_total_mentions
    # Placeholder: Will be implemented when Mention model is created in Phase 2
    # For now, return 0
    0
  end

  def calculate_avg_visibility_score
    # Placeholder: Will be implemented when VisibilityScore model is created in Phase 3
    # For now, return 0
    0.0
  end

  def calculate_mentions_this_week
    # Placeholder: Will be implemented when Mention model is created in Phase 2
    # For now, return 0
    0
  end

  def find_top_brand
    # Placeholder: Will be implemented when VisibilityScore model is created in Phase 3
    # For now, return the first active brand
    current_workspace.brands.active.first
  end

  def calculate_recent_activity
    # Placeholder: Will be implemented when Mention model is created in Phase 2
    # For now, return 0
    0
  end
end
