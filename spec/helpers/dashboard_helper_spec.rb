# frozen_string_literal: true

require "rails_helper"

RSpec.describe DashboardHelper, type: :helper do
  describe "#score_color_class" do
    it "returns green for excellent scores (80-100)" do
      expect(helper.score_color_class(100)).to eq("text-green-600")
      expect(helper.score_color_class(85)).to eq("text-green-600")
      expect(helper.score_color_class(80)).to eq("text-green-600")
    end

    it "returns yellow for good scores (60-79)" do
      expect(helper.score_color_class(79)).to eq("text-yellow-600")
      expect(helper.score_color_class(65)).to eq("text-yellow-600")
      expect(helper.score_color_class(60)).to eq("text-yellow-600")
    end

    it "returns orange for fair scores (40-59)" do
      expect(helper.score_color_class(59)).to eq("text-orange-600")
      expect(helper.score_color_class(45)).to eq("text-orange-600")
      expect(helper.score_color_class(40)).to eq("text-orange-600")
    end

    it "returns red for poor scores (0-39)" do
      expect(helper.score_color_class(39)).to eq("text-red-600")
      expect(helper.score_color_class(25)).to eq("text-red-600")
      expect(helper.score_color_class(0)).to eq("text-red-600")
    end
  end

  describe "#score_badge_class" do
    it "returns green badge for excellent scores" do
      expect(helper.score_badge_class(85)).to eq("bg-green-100 text-green-800")
    end

    it "returns yellow badge for good scores" do
      expect(helper.score_badge_class(65)).to eq("bg-yellow-100 text-yellow-800")
    end

    it "returns orange badge for fair scores" do
      expect(helper.score_badge_class(45)).to eq("bg-orange-100 text-orange-800")
    end

    it "returns red badge for poor scores" do
      expect(helper.score_badge_class(25)).to eq("bg-red-100 text-red-800")
    end
  end

  describe "#score_label" do
    it "returns correct labels for score ranges" do
      expect(helper.score_label(85)).to eq("Excellent")
      expect(helper.score_label(65)).to eq("Good")
      expect(helper.score_label(45)).to eq("Fair")
      expect(helper.score_label(25)).to eq("Poor")
    end

    it "handles edge cases" do
      expect(helper.score_label(100)).to eq("Excellent")
      expect(helper.score_label(80)).to eq("Excellent")
      expect(helper.score_label(79)).to eq("Good")
      expect(helper.score_label(60)).to eq("Good")
      expect(helper.score_label(59)).to eq("Fair")
      expect(helper.score_label(40)).to eq("Fair")
      expect(helper.score_label(39)).to eq("Poor")
      expect(helper.score_label(0)).to eq("Poor")
    end
  end

  describe "#format_stat" do
    it "formats numbers with delimiters" do
      expect(helper.format_stat(1000)).to eq("1,000")
      expect(helper.format_stat(1000000)).to eq("1,000,000")
      expect(helper.format_stat(100)).to eq("100")
    end
  end

  describe "#trend_icon" do
    it "returns up arrow for upward trend" do
      result = helper.trend_icon("up")
      expect(result).to include("text-green-500")
      expect(result).to be_html_safe
    end

    it "returns down arrow for downward trend" do
      result = helper.trend_icon("down")
      expect(result).to include("text-red-500")
      expect(result).to be_html_safe
    end

    it "returns horizontal line for stable trend" do
      result = helper.trend_icon("stable")
      expect(result).to include("text-gray-500")
      expect(result).to be_html_safe
    end

    it "returns horizontal line for unknown trend" do
      result = helper.trend_icon("unknown")
      expect(result).to include("text-gray-500")
      expect(result).to be_html_safe
    end
  end
end

