# frozen_string_literal: true

# Helper methods for dashboard views
module DashboardHelper
  # Returns Tailwind color class based on score
  # @param score [Numeric] The visibility score (0-100)
  # @return [String] Tailwind text color class
  def score_color_class(score)
    case score
    when 80..100
      "text-green-600"
    when 60..79
      "text-yellow-600"
    when 40..59
      "text-orange-600"
    else
      "text-red-600"
    end
  end

  # Returns Tailwind badge class based on score
  # @param score [Numeric] The visibility score (0-100)
  # @return [String] Tailwind badge classes
  def score_badge_class(score)
    case score
    when 80..100
      "bg-green-100 text-green-800"
    when 60..79
      "bg-yellow-100 text-yellow-800"
    when 40..59
      "bg-orange-100 text-orange-800"
    else
      "bg-red-100 text-red-800"
    end
  end

  # Returns human-readable label for score
  # @param score [Numeric] The visibility score (0-100)
  # @return [String] Label (Excellent, Good, Fair, Poor)
  def score_label(score)
    case score
    when 80..100
      "Excellent"
    when 60..79
      "Good"
    when 40..59
      "Fair"
    else
      "Poor"
    end
  end

  # Returns formatted number with delimiter
  # @param number [Numeric] The number to format
  # @return [String] Formatted number
  def format_stat(number)
    number_with_delimiter(number)
  end

  # Returns trend icon based on trend direction
  # @param trend [String] The trend direction (up, down, stable)
  # @return [String] SVG icon HTML
  def trend_icon(trend)
    case trend
    when "up"
      '<svg class="h-5 w-5 text-green-500" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M5.293 9.707a1 1 0 010-1.414l4-4a1 1 0 011.414 0l4 4a1 1 0 01-1.414 1.414L11 7.414V15a1 1 0 11-2 0V7.414L6.707 9.707a1 1 0 01-1.414 0z" clip-rule="evenodd"/></svg>'.html_safe
    when "down"
      '<svg class="h-5 w-5 text-red-500" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M14.707 10.293a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 111.414-1.414L9 12.586V5a1 1 0 012 0v7.586l2.293-2.293a1 1 0 011.414 0z" clip-rule="evenodd"/></svg>'.html_safe
    else
      '<svg class="h-5 w-5 text-gray-500" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M5 10a1 1 0 011-1h8a1 1 0 110 2H6a1 1 0 01-1-1z" clip-rule="evenodd"/></svg>'.html_safe
    end
  end
end

